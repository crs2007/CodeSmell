-- =============================================
-- Author:		Sharon
-- Create date: 16/06/2013
--				13/07/2015 @CheckID INT = NULL
-- Description:	Check last known successful Log backup.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_LastLogBackup]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname = NULL,
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
			''Database '' + ( d.Name COLLATE database_default ) + '' is in '' + d.recovery_model_desc + '' recovery mode but has not had a log backup in the last week.'' ObjectName,
			''Backup''Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    master.sys.databases d
			LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name
				AND b.type = ''L''
				AND b.backup_finish_date >= DATEADD(dd, ' + dbo.Setup_GetGlobalParm (5) + N', GETDATE()) 
	WHERE   d.recovery_model IN ( 1, 2 )
			AND d.database_id NOT IN ( 2, 3 )
			AND d.source_database_id IS NULL
			AND d.state != 1 /* Not currently restoring, like log shipping databases */
			AND d.is_in_standby = 0 /* Not a log shipping target database */
			AND d.source_database_id IS NULL /* Excludes database snapshots */
			AND b.backup_set_id IS NULL
			AND d.name = @DatabaseName;';
	
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Massege NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@CheckID INT',
				@DatabaseName = @DatabaseName,
				@Massege = @Massege,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@CheckID = @CheckID;
	END TRY
	BEGIN CATCH
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		RETURN -1;
	END CATCH
END