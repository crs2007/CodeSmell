-- =============================================
-- Author:		Sharon
-- Create date: 22/12/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Invalid PK Name
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_InvalidPKName]
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
	SELECT	DISTINCT @RunningID,
			@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + OBJECT_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) ObjectName,
			''DesignStandard'' Type,
			''PK_'' + OBJECT_NAME(C.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + '' - Required PK Name'' ColumnName,
			c.name + '' - Current PK Name'' ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
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