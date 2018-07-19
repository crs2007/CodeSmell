-- =============================================
-- Author:		Sharon
-- Create date: 24/02/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Column Lower Letter
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_ColumnLowerLetter]
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
	SELECT	@DatabaseName DatabaseName,
			s.name + ''.'' + t.name ObjectName,
			''DesignStandard'' Type,
			c.NAME ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
			--''EXEC sys.sp_rename  @objname = N'''''' + s.name +  ''.'' + t.name +  ''.'' + c.name + '''''', @newname = N'''''' + UPPER(LEFT(c.name, 1))+ SUBSTRING(c.NAME, 2, LEN(c.NAME)) + '''''' , @objtype = ''''Column'''''' [Script]
	FROM	' + @DBName + N'SYS.tables t
			INNER JOIN ' + @DBName + N'SYS.columns c ON c.object_id = t.object_id
			INNER JOIN ' + @DBName + N'sys.schemas s ON t.schema_id = s.schema_id
	WHERE   ASCII(LEFT(c.name, 1)) NOT BETWEEN ASCII(''A'') AND ASCII(''Z'')
            AND t.name NOT IN (''sysdiagrams'',
								''MSpeer_conflictdetectionconfigrequest'',
								''MSpeer_conflictdetectionconfigresponse'',
								''MSpeer_lsns'',
								''MSpeer_originatorid_history'',
								''MSpeer_request'',
								''MSpeer_response'',
								''MSpeer_topologyrequest'',
								''MSpeer_topologyresponse'',
								''MSpub_identity_range'',
								''sysarticlecolumns'',
								''sysarticles'',
								''sysarticleupdates'',
								''syspublications'',
								''sysreplservers'',
								''sysschemaarticles'',
								''systranschemas'',
								''syssubscriptions'');
			';
	
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
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL
			INSERT #Mng_ApplicationErrorLog
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		ELSE
		BEGIN
			PRINT @sqlCmd;
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		END
			
		RETURN -1;
	END CATCH
END