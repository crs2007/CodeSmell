-- =============================================
-- Author:		Sharon
-- Create date: 22/12/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Invalid PK Name
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_InvalidPKName]
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
			OBJECT_SCHEMA_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + OBJECT_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) ObjectName,
			''DesignStandard'' Type,
			''PK_'' + OBJECT_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + '' - Required PK Name'' ColumnName,
			c.name + '' - Current PK Name'' ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
			--''EXEC sys.sp_rename  @objname = N'''''' + OBJECT_SCHEMA_NAME(parent_object_id) + ''.'' + name + '''''', @newname = N''''PK_'' + OBJECT_NAME(parent_object_id) + '''''', @objtype = ''''OBJECT'''''' Script
	FROM	' + @DBName + N'sys.key_constraints C
	WHERE   C.name <> ''PK_'' + OBJECT_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + '''))
			AND C.type_desc = ''PRIMARY_KEY_CONSTRAINT''
			AND OBJECT_SCHEMA_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) NOT IN ( ''sys'',''cdc'',''Actimize'' )
			AND OBJECT_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) NOT IN ( ''MSpeer_conflictdetectionconfigresponse'',
                            ''MSpeer_originatorid_history'', ''MSpeer_request'',
                            ''MSpeer_response'', ''MSpeer_topologyrequest'',
                            ''MSpeer_topologyresponse'', ''MSpub_identity_range'',
                            ''sysarticlecolumns'', ''sysarticles'',
                            ''sysarticleupdates'', ''syspublications'',
                            ''sysschemaarticles'', ''syssubscriptions'',
							''MSpeer_conflictdetectionconfigrequest'',''MSpeer_lsns'',''sysreplservers'',''systranschemas'',''sysdiagrams''
							);
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