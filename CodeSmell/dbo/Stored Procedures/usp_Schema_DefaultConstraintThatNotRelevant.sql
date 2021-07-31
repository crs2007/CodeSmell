-- =============================================
-- Author:		Sharon
-- Create date: 18/02/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Finding Default - Constraint That Not Relevant.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_DefaultConstraintThatNotRelevant]
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
	DECLARE @sqlCmd NVARCHAR(max) ;

	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(o.object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + o.name ObjectName,
			''Default Constraint'' Type,
			C.NAME ColumnName,
			df.name  AS ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM	' + @DBName + N'sys.default_constraints df
			INNER JOIN ' + @DBName + N'sys.objects o ON df.parent_object_id = o.object_id
			INNER JOIN ' + @DBName + N'sys.columns c ON df.parent_column_id = c.column_id
				AND c.object_id = o.object_id
	WHERE	c.is_nullable = 1
		AND o.name NOT IN (''MSpeer_lsns''
							,''MSpeer_topologyrequest''
							,''MSpeer_request''
							,''sysarticlecolumns''
							,''syspublications''
							,''syspublications''
							,''MSpeer_conflictdetectionconfigresponse''
							)
	ORDER BY OBJECT_SCHEMA_NAME(o.object_id);';

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