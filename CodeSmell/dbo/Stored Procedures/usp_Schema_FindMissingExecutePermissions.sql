-- =============================================
-- Author:		sharonr
-- Create date: 03/07/2021
-- Update date: 25/07/2021 fix function bug
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Find Missing EXECUTE Permissions.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_FindMissingExecutePermissions]
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
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			S.name + ''.'' + O.name ObjectName,
			''Design Standards'' Type,
			NULL ColumnName,
			N''EXECUTE'' ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    ' + @DBName + N'sys.objects O 
			INNER JOIN ' + @DBName + N'sys.schemas S ON S.schema_id = O.schema_id
	WHERE	O.object_id = @ObjectID 
			AND S.name NOT IN (SELECT [Value] COLLATE ' + dbo.Setup_GetGlobalParm (1) + ' FROM [' + DB_NAME() + '].dbo.App_IgnoreList WHERE [ValueType] = ''Schema'')
			AND NOT EXISTS (SELECT TOP(1) 1 FROM ' + @DBName + N'sys.database_permissions p
                        INNER JOIN ' + @DBName + N'sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
						LEFT JOIN ' + @DBName + N'sys.all_objects iob ON p.major_id = iob.OBJECT_ID
							AND iob.is_ms_shipped = 0 
						LEFT JOIN ' + @DBName + N'sys.schemas sc ON p.major_id = sc.schema_id
							AND p.class_desc = N''SCHEMA''
							AND sc.name = S.name
				WHERE	p.permission_name = N''EXECUTE'' 
						AND p.state_desc = N''GRANT''
						AND (iob.object_id = O.object_id OR sc.schema_id IS NOT NULL));';

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