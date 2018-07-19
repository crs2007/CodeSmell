/* ------------------------------------------------------------------
-- Title:	FindMissingIndexes
-- Author:	Brent Ozar
-- Date:	2009-04-01 
-- Modified By: Clayton Kramer <ckramer.kramer @ gmail.com>
--				13/07/2015 @CheckID INT = NULL
-- Description: This query returns indexes that SQL Server 2005 
-- (and higher) thinks are missing since the last restart. The 
-- "Impact" column is relative to the time of last restart and how 
-- bad SQL Server needs the index. 10 million+ is high.
-- Changes: Updated to expose full table name. This makes it easier
-- to identify which database needs an index. Modified the 
-- CreateIndexStatement to use the full table path and include the
-- equality/inequality columns for easier identifcation.
-- Update date: 24/08/2014 @ObjectID INT
 */
CREATE PROCEDURE [dbo].[usp_Index_FindMissingIndex]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;
	DECLARE @DBName NVARCHAR(129);

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.'
	FROM    sys.databases 
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL  
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),'You must enter valid local database name insted - ' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,HOST_NAME(),USER_NAME();  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(max) ,
			@prefix NVARCHAR(1000) = N'';

	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL SET @prefix = N'
	INSERT	#Exeption';

	SELECT	@sqlCmd = @prefix + N'
	SELECT	@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(o.object_id,DB_ID(''' + @DBName + N''')) + ''.'' + o.name ObjectName,
			''Index'' Type,
			ISNULL(''Equality: '' + mid.equality_columns,'''') + ISNULL(''Inequality: '' + mid.inequality_columns,'''') + ISNULL('' included: '' + mid.included_columns,'''') ColumnName,
			''/* Impact: '' + CONVERT(VARCHAR,( avg_total_user_cost * avg_user_impact ) * ( user_seeks + user_scans )) + '' */ CREATE NONCLUSTERED INDEX IX_'' 
			+ REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns,'') + ISNULL(mid.inequality_columns,''), ''['',''''), '']'',''''), '', '',''_'')
			+ '' ON ''
			+ REPLACE([statement],QUOTENAME(DB_NAME(DB_ID())) + ''.'','''')
			+ '' ( '' + IsNull(mid.equality_columns,'''') 
			+ CASE WHEN mid.inequality_columns IS NULL THEN '''' ELSE 
				CASE WHEN mid.equality_columns IS NULL THEN '''' ELSE '','' END 
			+ mid.inequality_columns END + '' ) '' 
			+ CASE WHEN mid.included_columns IS NULL THEN '''' ELSE ''INCLUDE ('' + mid.included_columns + '')'' END 
			+ '';'' ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'sys.dm_db_missing_index_group_stats AS migs
			INNER JOIN ' + @DBName + N'sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
			INNER JOIN ' + @DBName + N'sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
			INNER JOIN ' + @DBName + N'sys.objects o WITH (NOLOCK) ON mid.OBJECT_ID = o.OBJECT_ID
	WHERE   ( migs.group_handle IN (
			  SELECT TOP ( 500 )
						group_handle
			  FROM      ' + @DBName + N'sys.dm_db_missing_index_group_stats WITH ( NOLOCK )
			  ORDER BY  ( avg_total_user_cost * avg_user_impact ) * ( user_seeks
																  + user_scans ) DESC ) )
			AND OBJECTPROPERTY(o.OBJECT_ID, ''isusertable'') = 1
	ORDER BY ( avg_total_user_cost * avg_user_impact ) * ( user_seeks + user_scans ) DESC;';
	
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Massege NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT', 
				@DatabaseName = @DatabaseName,
				@Massege = @Massege,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@ObjectID = @ObjectID,
				@CheckID = @CheckID;
	END TRY
	BEGIN CATCH
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		RETURN -1;
	END CATCH
END