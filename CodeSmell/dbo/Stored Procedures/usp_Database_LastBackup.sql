-- =============================================
-- Author:		Sharon
-- Create date: 16/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				28/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Check last known successful backup.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_LastBackup]
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
			CASE WHEN MAX(b.backup_finish_date) IS NULL THEN ''Database '' + d.Name + N'' never backedUP!'' ELSE 
			''Database '' + d.Name + N'' last backed up: ''
			+ CAST(ISNULL(MAX(b.backup_finish_date), ''19000101'') AS VARCHAR(200)) END ObjectName,
			''Backup''Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    master.sys.databases d
			LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name
													AND b.type = ''D'' -- Database
													AND b.is_copy_only = 0
													AND b.server_name = SERVERPROPERTY(''ServerName'') /*Backupset ran on current server */
	WHERE   d.database_id != 2  --Not TempDB
			AND d.state != 1 /* Not currently restoring, like log shipping databases */
			AND d.is_in_standby = 0 /* Not a log shipping target database */
			AND d.source_database_id IS NULL /* Excludes database snapshots */
			AND d.name = @DatabaseName
	GROUP BY d.name 
	HAVING  ISNULL(MAX(b.backup_finish_date),''19000101'') <= DATEADD(dd,(SELECT CONVERT(INT,' + dbo.Setup_GetGlobalParm (4) + N')),GETDATE());';

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