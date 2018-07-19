-- =============================================
-- Author:		Sharon
-- Create date: 10/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding a UNIQUEIDENTIFIER column as the CLUSTERED PRIMARY KEY of a table.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_ClustredUniqueidentifier]
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
			OBJECT_SCHEMA_NAME(t.object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + t.name ObjectName,
			''Index'' Type,
			c.name + '' - Uniqueidentifier'' ColumnName,
			i.name + '' - '' + i.type_desc COLLATE ' + dbo.Setup_GetGlobalParm (1) + ' AS ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + ' Severity
	FROM	' + @DBName + N'sys.indexes i
			INNER JOIN ' + @DBName + N'sys.index_columns ic ON i.object_id = ic.object_id
				AND i.index_id = ic.index_id
			INNER JOIN ' + @DBName + N'sys.columns c ON ic.column_id = c.column_id
				AND ic.object_id = c.object_id
			INNER JOIN ' + @DBName + N'sys.tables t ON c.object_id = t.object_id
	WHERE	i.index_id = 1			  -- CLUSTERED
			AND c.system_type_id = 36 -- Uniqueidentifier;';
	
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