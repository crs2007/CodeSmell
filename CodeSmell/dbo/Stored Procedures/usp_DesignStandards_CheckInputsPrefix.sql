-- =============================================
-- Author:		Sharon
-- Create date: 2021-11-29
-- Update date: 
-- Description:	Clean old versions of that stored procedure to be with orginized database.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandards_CheckInputsPrefix]
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
			CONCAT(s.name, ''.'', o.name) ObjectName,
			''Design Standards'' Type,
			p.name ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    ' + @DBName + N'sys.procedures o
			INNER JOIN ' + @DBName + N'sys.schemas s ON s.schema_id = o.schema_id
			INNER JOIN ' + @DBName + N'sys.parameters p ON p.object_id = o.object_id
			CROSS APPLY (SELECT TOP (1) SUBSTRING(p.name,0,CHARINDEX(''_'',p.name))COLLATE Latin1_General_CS_AI)CA([InputPrefix])
	WHERE	o.object_id = @ObjectID
			AND [InputPrefix] NOT IN (''@O'',''@I'',''@IO'',''@OI'');';
	
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