﻿-- =============================================
-- Author:		Sharon
-- Create date: 10/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				28/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Finding a nullable timestamp|rowversion column.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_TimeStampRowversionNullable]
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
			OBJECT_SCHEMA_NAME(t.object_id,DB_ID(''' + @DatabaseName + N''')) + ''.'' + t.name ObjectName,
			''Column'' Type,
			c.name + '' - Nullable'' ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM	' + @DBName + N'sys.columns c
			INNER JOIN ' + @DBName + N'sys.tables t ON c.object_id = t.object_id
	WHERE	C.system_type_id = 189 -- timestamp/rowversion
			AND C.is_nullable = 1
			' + CASE WHEN @ObjectID IS NOT NULL THEN 'AND @ObjectID = t.object_id;' ELSE + '' END;

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