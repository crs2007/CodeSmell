-- =============================================
-- Author:		Sharon
-- Create date: 05/07/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Finding Select * from Dependencies.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_SelectAll]
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
	DECLARE @sqlCmd NVARCHAR(max) ;

	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			SCH.name + ''.'' + OBJ.name ObjectName,
			''General Code Smells - SELECT *'' [Type],
			NULL ColumnName,
			NULL ConstraintName,
			REPLACE(@Message,''$ObjectName$'',refSCH.name + ''.'' + refOBJ.name) Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    ' + @DBName + N'sys.sql_dependencies D
			INNER JOIN ' + @DBName + N'sys.objects AS OBJ ON D.object_id = OBJ.object_id
			INNER JOIN ' + @DBName + N'sys.schemas AS SCH ON OBJ.schema_id = SCH.schema_id
			INNER JOIN ' + @DBName + N'sys.objects AS refOBJ ON D.referenced_major_id = refOBJ.object_id
			INNER JOIN ' + @DBName + N'sys.schemas AS refSCH ON refOBJ.schema_id = refSCH.schema_id
	WHERE	D.is_select_all = 1
			AND D.referenced_minor_id = 1
			AND SCH.name NOT IN (SELECT [Value] COLLATE ' + dbo.Setup_GetGlobalParm (1) + ' FROM [' + DB_NAME() + '].dbo.App_IgnoreList WHERE [ValueType] = ''Schema'')
			' + CASE WHEN @ObjectID IS NOT NULL THEN 'AND D.object_id = @ObjectID' ELSE '' END 
				
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