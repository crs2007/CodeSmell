-- =============================================
-- Author:		Sharon
-- Create date: 24/02/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Column Lower Letter
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_ColumnLowerLetter]
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
			s.name + ''.'' + t.name ObjectName,
			''DesignStandard'' Type,
			c.NAME ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
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