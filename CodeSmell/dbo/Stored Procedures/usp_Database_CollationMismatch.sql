-- =============================================
-- Author:		Sharon
-- Create date: 3/3/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding a difarencs with collation_name on the db.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_CollationMismatch]
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
			OBJECT_SCHEMA_NAME(o.object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + o.name ObjectName,
			''Collation'' Type,
			c.name + '' ('' + C.collation_name + '')'' ColumnName,
			NULL AS ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName Severity' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + ' 
	FROM	sys.databases db
			CROSS JOIN ' + @DBName + N'sys.columns c
			INNER JOIN ' + @DBName + N'SYS.objects O ON C.object_id = O.object_id
	WHERE	db.name = @DatabaseName
			AND DB.collation_name != C.collation_name
			AND C.object_id > 99
			AND O.type NOT IN  (''S'',''IT''); -- SYSTEM_TABLE/INTERNAL_TABLE';
	
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
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL
			INSERT #Mng_ApplicationErrorLog
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		ELSE
		BEGIN
			PRINT @sqlCmd;
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		END
		RETURN -1;
	END CATCH
END