-- =============================================
-- Author:		Sharon
-- Create date: 25/08/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Find Indexes Not In Use.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Index_FindIndexesNotInUse]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL
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
			c.name + ''.'' + o.name ObjectName,
			''Index'' Type,
			i.name ColumnName,
			''DROP INDEX '' + QUOTENAME(i.name) + '' ON '' + QUOTENAME(c.name) + ''.'' + QUOTENAME(o.name) + '';'' ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'sys.dm_db_index_usage_stats s
			INNER JOIN ' + @DBName + N'sys.indexes i ON i.index_id = s.index_id
										AND s.object_id = i.object_id
			INNER JOIN ' + @DBName + N'sys.objects o ON s.object_id = o.object_id
			INNER JOIN ' + @DBName + N'sys.schemas c ON o.schema_id = c.schema_id
	WHERE   OBJECTPROPERTY(s.object_id, ''IsUserTable'') = 1
			AND s.database_id = DB_ID(@DatabaseName)
			AND i.type_desc = ''nonclustered''
			AND i.is_primary_key = 0
			AND i.is_unique_constraint = 0
			AND ( SELECT    SUM(p.rows)
				  FROM      ' + @DBName + N'sys.partitions p
				  WHERE     p.index_id = s.index_id
							AND s.object_id = p.object_id
				) > 10000
			AND user_seeks + user_scans + user_lookups < 55 /*todo: move to globle param*/
	ORDER BY user_seeks + user_scans + user_lookups;';
	
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