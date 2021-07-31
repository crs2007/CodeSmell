-- =============================================
-- Author:		Sharon
-- Create date: 13/08/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding Identity Column that going to run out.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_IdentCurrentLeft]
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
	DECLARE @sqlCmd NVARCHAR(max);

	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(t.object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + t.name ObjectName,
			TY.NAME Type,
			C.NAME ColumnName,
			''Percent Full: '' + 
			CAST((
			CASE (C.system_type_id)
			WHEN 48
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 255)  
			WHEN 52
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 32767)  
			WHEN 56
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 2147483647)  
			WHEN 127
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 9223372036854775807)  
			WHEN 106
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / ((C.precision * 10) - 1))  
			END * 100) AS VARCHAR(512))  
			+ '' Remaining: '' +
			REPLACE(CONVERT(VARCHAR(19), CAST(
			CASE (C.system_type_id)
			WHEN 48
			THEN (255 - IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME))  
			WHEN 52
			THEN (32767 - IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME))  
			WHEN 56
			THEN (2147483647 - IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME))  
			WHEN 127
			THEN (9223372036854775807 - IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME))  
			WHEN 106
			THEN (((C.precision * 10) - 1) - IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME))  
			END
			AS MONEY) , 1), ''.00'', '''')  AS ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM	' + @DBName + N'sys.identity_columns C
			INNER JOIN ' + @DBName + N'SYS.TABLES T ON T.object_id = C.object_id
			INNER JOIN ' + @DBName + N'SYS.TYPES TY ON C.system_type_id = TY.system_type_id
	WHERE	CAST((
				CASE (C.system_type_id)
				WHEN 48
				THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 255)  
				WHEN 52
				THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 32767)  
				WHEN 56
				THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 2147483647)  
				WHEN 127
				THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 9223372036854775807)  
				WHEN 106
				THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / ((C.precision * 10) - 1))  
				END * 100) AS INT) >= CONVERT(TINYINT,' + dbo.Setup_GetGlobalParm (8) + N')
	ORDER BY CASE (C.system_type_id)
			WHEN 48
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 255)  
			WHEN 52
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 32767)  
			WHEN 56
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 2147483647)  
			WHEN 127
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / 9223372036854775807)  
			WHEN 106
			THEN (IDENT_CURRENT(SCHEMA_NAME(T.schema_id) + ''.'' + T.NAME) / ((C.precision * 10) - 1))  
			END;';

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