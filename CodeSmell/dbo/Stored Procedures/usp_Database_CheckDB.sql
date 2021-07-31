-- =============================================
-- Author:		Sharon
-- Create date: 16/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				19/07/2015 @CheckID INT = NULL
--				28/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Check last known successful run of checkdb.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_CheckDB]
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
	
	IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL DROP TABLE #DBInfo;
    CREATE TABLE #DBInfo
    (
		ParentObject VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Object VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Field VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Value VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
    );
	
	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			CASE DBI.Value WHEN  ''1900-01-01 00:00:00.000'' 
							THEN ''DBCC CHECKDB has never been used on - '' + @DatabaseName 
							ELSE ''DBCC CHECKDB last successful good run was - '' + DBI.Value 
						   END ObjectName,
			''DBCC CHECKDB'' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM	#DBInfo DBI
	WHERE	DBI.Field = ''dbi_dbccLastKnownGood''
			AND DBI.Value < DATEADD(DAY,CONVERT(INT,' + dbo.Setup_GetGlobalParm (3) + N'),GETDATE());';

	BEGIN TRY
		INSERT #DBInfo
		EXEC ('DBCC DBInfo(' + @DatabaseName + ') With TableResults, NO_INFOMSGS');

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