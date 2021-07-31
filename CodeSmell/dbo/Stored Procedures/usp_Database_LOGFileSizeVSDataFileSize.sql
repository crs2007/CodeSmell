-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				28/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Finding if the LOG file is over the SUM of all data files (mdf,ndf).
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_LOGFileSizeVSDataFileSize]
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

	SELECT	@sqlCmd = N'
	;WITH DataFile AS (
			SELECT  CONVERT(NUMERIC(12,4),(SUM(MF.size) * 8)/1024.0) SizeMB,--1048576.0
					DB_NAME(MF.database_id) AS DatabaseName
			FROM    sys.master_files MF
			WHERE	MF.type = 0 -- Only DataFile
			GROUP BY MF.database_id)
	, LogFile AS (
			SELECT  CONVERT(NUMERIC(12,4),(SUM(MF.size) * 8)/1024.0) SizeMB,
					DB_NAME(MF.database_id) AS DatabaseName
			FROM    sys.master_files MF
			WHERE	MF.type = 1 -- Only DataFile
			GROUP BY MF.database_id)
	INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			DF.DatabaseName AS DatabaseName,
			''Log File size('' + CONVERT(VARCHAR(30),LF.SizeMB) + '' MB) is biger than all data files('' + CONVERT(VARCHAR(30),DF.SizeMB) + '' MB).'',
			''File''Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM	DataFile DF
			INNER JOIN LogFile LF ON DF.DatabaseName = LF.DatabaseName
	WHERE	LF.SizeMB > DF.SizeMB
			AND DF.DatabaseName = @DatabaseName;';

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