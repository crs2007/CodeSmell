-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding if the LOG file is over the limit of globle param.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_msdbDataFileSize]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sqlCmd NVARCHAR(max) ,
			@prefix NVARCHAR(1000) = N'';

	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL SET @prefix = N'
	INSERT	#Exeption';

	SELECT	@sqlCmd = @prefix + N'
	SELECT	TOP 1
			DB_NAME(MF.database_id) AS DatabaseName,
			''msdb data File size is '' + CONVERT(NVARCHAR(100),(SUM(MF.size) * 8)/1048576.0) + '' (GB) and over the limit in Global Parameter : ' + dbo.Setup_GetGlobalParm (7) + N''' ObjectName,
			''File'' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    sys.master_files MF
	WHERE	MF.type = 0 -- Only DataFile
			AND MF.database_id = 3 -- msdb
	GROUP BY MF.database_id
	HAVING CONVERT(real,(SUM(MF.size) * 8)/1048576.0) > CONVERT(REAL,' + dbo.Setup_GetGlobalParm (7) + N');';
	
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