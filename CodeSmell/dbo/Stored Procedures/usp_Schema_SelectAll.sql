-- =============================================
-- Author:		Sharon
-- Create date: 05/07/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding Select * from Dependencies.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_SelectAll]
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
			SCH.name + ''.'' + OBJ.name ObjectName,
			''General Code Smells - SELECT *'' [Type],
			NULL ColumnName,
			NULL ConstraintName,
			''Select * On object - '' + refSCH.name + ''.'' + refOBJ.name + '' '' +  @Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'sys.sql_dependencies D
			INNER JOIN ' + @DBName + N'sys.objects AS OBJ ON D.object_id = OBJ.object_id
			INNER JOIN ' + @DBName + N'sys.schemas AS SCH ON OBJ.schema_id = SCH.schema_id
			INNER JOIN ' + @DBName + N'sys.objects AS refOBJ ON D.referenced_major_id = refOBJ.object_id
			INNER JOIN ' + @DBName + N'sys.schemas AS refSCH ON refOBJ.schema_id = refSCH.schema_id
	WHERE	D.is_select_all = 1
			AND D.referenced_minor_id = 1
			' + CASE WHEN @ObjectID IS NOT NULL THEN 'AND refOBJ.object_id = @ObjectID' ELSE '' END 
				
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