-- =============================================
-- Author:		Sharon
-- Create date: 16/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Check last known successful backup.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_LastBackup]
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
	SELECT  d.[name] AS DatabaseName ,
			CASE WHEN MAX(b.backup_finish_date) IS NULL THEN ''Database '' + d.Name + N'' never backedUP!'' ELSE 
			''Database '' + d.Name + N'' last backed up: ''
			+ CAST(ISNULL(MAX(b.backup_finish_date), ''19000101'') AS VARCHAR(200)) END ObjectName,
			''Backup''Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
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