-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding if the LOG file is over the SUM of all data files (mdf,ndf).
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_LOGFileSizeVSDataFileSize]
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
	' + @prefix + N'
	SELECT  DF.DatabaseName AS DatabaseName ,
			''Log File size('' + CONVERT(VARCHAR(30),LF.SizeMB) + '' MB) is biger than all data files('' + CONVERT(VARCHAR(30),DF.SizeMB) + '' MB).'',
			''File''Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM	DataFile DF
			INNER JOIN LogFile LF ON DF.DatabaseName = LF.DatabaseName
	WHERE	LF.SizeMB > DF.SizeMB
			AND DF.DatabaseName = @DatabaseName;';
	
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