-- =============================================
-- Author:		Sharon
-- Create date: 17/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding if the LOG file is over the limit of globle param.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_LOGFileSize]
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
	--
	IF OBJECT_ID('tempdb..#LOGSPACE') IS NOT NULL DROP TABLE #LOGSPACE;
	CREATE TABLE #LOGSPACE (
			[Database Name] sysname,
			[Log Size (MB)]	REAL,
			[Log Space Used (%)] REAL,
			[Status] INT
		);
		
	INSERT INTO #LOGSPACE
	EXECUTE('DBCC SQLPERF(LOGSPACE)'); 


	SELECT	@sqlCmd = @prefix + N'
	SELECT	@DatabaseName DatabaseName,
			''LOG File size is '' + CONVERT(NVARCHAR(100),[Log Size (MB)] / 1024) + '' (GB) with '' + CONVERT(NVARCHAR(100),100 - [Log Space Used (%)]) + ''% free space.'' ObjectName,
			''File'' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM	#LOGSPACE
	WHERE	[Log Size (MB)] / 1024 > CONVERT(REAL,' + dbo.Setup_GetGlobalParm (6) + N')
			AND [Database Name] = @DatabaseName;';
	
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