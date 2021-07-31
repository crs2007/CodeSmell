/* ------------------------------------------------------------------
-- Title:	FindMissingIndexes
-- Author:	Brent Ozar
-- Date:	2009-04-01 
-- Description: This query returns indexes that SQL Server 2005 (and higher) thinks are missing since the last restart. The 
--		"Impact" column is relative to the time of last restart and how bad SQL Server needs the index. 10 million+ is high.
--		Changes: Updated to expose full table name. This makes it easier to identify which database needs an index. Modified the 
--		CreateIndexStatement to use the full table path and include the equality/inequality columns for easier identifcation.
-- Update date: 13/07/2015 Clayton Kramer <ckramer.kramer @ gmail.com> @CheckID INT = NULL
--				24/08/2014 @ObjectID INT
--				09/11/2020, sharonr change OBJECTPROPERTY(o.OBJECT_ID, 'isusertable') = 1 <TO>  AND o.type_desc = ''USER_TABLE''
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
------------------------------------------------------------------
 */
CREATE PROCEDURE [dbo].[usp_Index_FindMissingIndex]
	@DatabaseName sysname,
	@Message NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL,
	@LoginName sysname = NULL,
	@RunningID INT = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @DBName NVARCHAR(129);

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.'
	FROM    sys.databases 
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),'You must enter valid local database name insted - ' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,HOST_NAME(),@LoginName,GETDATE(),@RunningID;  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(MAX) ;

	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	DISTINCT @RunningID,
			@DatabaseName DatabaseName,
			ISNULL(OBJECT_SCHEMA_NAME(o.object_id,DB_ID(''' + @DBName + N''')),''dbo'') + ''.'' + o.name ObjectName,
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
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    ' + @DBName + N'sys.dm_db_missing_index_group_stats AS migs
			INNER JOIN ' + @DBName + N'sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
			INNER JOIN ' + @DBName + N'sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
			INNER JOIN ' + @DBName + N'sys.objects o WITH (NOLOCK) ON mid.OBJECT_ID = o.OBJECT_ID
	WHERE   ( migs.group_handle IN (
			  SELECT TOP ( 500 ) group_handle
			  FROM      ' + @DBName + N'sys.dm_db_missing_index_group_stats WITH ( NOLOCK )
			  ORDER BY  ( avg_total_user_cost * avg_user_impact ) * ( user_seeks + user_scans ) DESC ) )
			AND o.type_desc = ''USER_TABLE''
	--ORDER BY ( avg_total_user_cost * avg_user_impact ) * ( user_seeks + user_scans ) DESC;';

	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Message NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT,
				@RunningID INT', 
				@DatabaseName = @DatabaseName,
				@Message = @Message,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@ObjectID = @ObjectID,
				@CheckID = @CheckID,
				@RunningID = @RunningID;
	END TRY
	BEGIN CATCH
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),@LoginName,GETDATE(),@RunningID; 
		RETURN -1;
	END CATCH
END