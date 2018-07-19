-- =============================================
-- Author:		Sharon
-- Create date: 16/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				19/07/2015 @CheckID INT = NULL
-- Description:	Check backup location where data file.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_BackupLocation]
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
	SELECT  TOP 1
			@DatabaseName DatabaseName ,
			@DatabaseName ObjectName,
			''Backup''Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM	sys.master_files AS mf
	WHERE	name = @DatabaseName
			AND UPPER(LEFT(mf.physical_name COLLATE database_default, 3)) = (
					SELECT	TOP 1 UPPER(LEFT(bmf.physical_device_name COLLATE database_default, 3))
					FROM	msdb.dbo.backupmediafamily AS bmf
							INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
														AND bs.backup_start_date >= ( DATEADD(dd,
														-7, GETDATE()) )
					WHERE   database_name = @DatabaseName
					ORDER BY bmf.media_set_id DESC);';
	
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