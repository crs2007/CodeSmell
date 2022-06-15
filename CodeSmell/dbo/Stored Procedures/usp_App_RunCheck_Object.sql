-- =============================================
-- Author:		Sharon
-- Create date: 26/05/2019
-- Update date: 26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
--				On: 09/05/2022 ; By: sharonr
--					ALTER:Support dbo.GetParsedPERSIName 
-- Description:	General SP that run all check by Version Number to a physical object only
-- =============================================
CREATE PROCEDURE [dbo].[usp_App_RunCheck_Object]
	@I_DataBaseName				sysname,
	@I_StartDate				DATE,
	@I_EndDate					DATE,
	@I_ObjectName				sysname = NULL,
	@I_Debug					BIT = 0
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	IF SESSION_CONTEXT(N'IgnoreCodeSmell') = N'1'
	BEGIN
		RETURN -1;
	END
    DECLARE @DBName					NVARCHAR(129),
			@CompatibilityLevel		INT,
			@RunningID				INT,
			@ExecutionDate			DATETIME = GETDATE(),
			@Print					NVARCHAR(2048),
			@DataBaseName			sysname,
			@LoginName				sysname = SUSER_NAME();
	

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.',
			@CompatibilityLevel = compatibility_level,
			@DataBaseName = name
	FROM    sys.databases 
	WHERE	name = @I_DataBaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT 'You must enter valid local database name' + ISNULL(N' insted - ' + QUOTENAME(@I_DataBaseName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),USER_NAME(),@ExecutionDate,NULL;  
		RAISERROR ('You must enter valid local database name',16,1);
		RETURN - 1;
	END

	SELECT TOP (1) @RunningID = MR.ID FROM  History.App_MainRun mr WHERE MR.DatabaseName = @DBName AND MR.StartDate = @I_StartDate AND MR.EndDate = @I_EndDate
	IF @@ROWCOUNT > 0
	BEGIN
		SELECT	DISTINCT 
				MR.DatabaseName,
				DR.ObjectName ,
                DR.Type ,
                DR.ColumnName ,
                DR.ConstraintName ,
                DR.[Message] ,
                DR.URL ,
                DR.Severity
		FROM	History.App_MainRun MR
				INNER JOIN History.App_DetailRun DR ON DR.MainRunID = MR.ID
		WHERE	MR.ID = @RunningID;
		RETURN 1;
	END
	INSERT History.App_MainRun VALUES(@ExecutionDate,@DataBaseName,@@SERVERNAME,@I_StartDate,@I_EndDate,IIF(@I_ObjectName IS NULL,0,1),IIF(APP_NAME() = 'SQLCMD',dbo.GetParsedPERSIName(SUSER_NAME()),SUSER_NAME()),@I_ObjectName);
	SELECT @RunningID = SCOPE_IDENTITY();

	DECLARE @sqlCmd NVARCHAR(max) = N'' ,
			@prefix NVARCHAR(1000) = N'',
			@ObjectID INT; 
			 
	BEGIN --Declare
		DECLARE @RunnableChecks TABLE (
		ID INT NOT NULL,
		ExecuteScript NVARCHAR(4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		Name NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		TestOrder INT NOT NULL
	);

	DECLARE @Error TABLE (
		ID INT,
		[Type] VARCHAR(305) COLLATE SQL_Latin1_General_CP1_CI_AS,
		[Message] VARCHAR(512) COLLATE SQL_Latin1_General_CP1_CI_AS,
		URL_Reference VARCHAR(512) COLLATE SQL_Latin1_General_CP1_CI_AS,
		IsCheckOnProcName BIT,
		Regex NVARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS,
		SearchRegexMethodID INT,
		SeverityID INT,
		NotIn_RegexPettern NVARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS,
		CodeTypeID TINYINT NULL
	);

	DECLARE @OutTmp TABLE (ID INT, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CI_AS);
	END

	IF @I_ObjectName IS NOT NULL 
	BEGIN
		SELECT @ObjectID = OBJECT_ID(CONCAT(@DBName,@I_ObjectName));
		IF @ObjectID IS NULL
		BEGIN
			INSERT dbo.Mng_ApplicationErrorLog
			SELECT 'You must enter valid object name that related to database name ' + ISNULL(N' insted - ' + QUOTENAME(@I_ObjectName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),USER_NAME(),@ExecutionDate,NULL;  
			RAISERROR ('You must enter valid object name that related to database name',16,1);
			RETURN - 1;
		END
	END
	
	INSERT	@RunnableChecks(ID, ExecuteScript, Name,TestOrder)
	SELECT	GC.ID, N'USE ' + QUOTENAME(@I_DataBaseName) + ';
DECLARE @ObjectID INT' + IIF(@I_ObjectName IS NOT NULL,' = OBJECT_ID(@I_ObjectName)','') + ';
BEGIN TRY
	EXECUTE [' + DB_NAME() + N'].' + GC.Name + N' @DatabaseName = ''' + @DataBaseName + N''', @Message = ' + ISNULL(N'N''' + REPLACE(GC.[Message],'''','''''') + N'''',N'NULL') + N', @URL_Reference = ' + ISNULL('''' + GC.URL_Reference + '''',N'NULL')+ N', @SeverityName = ' + ISNULL('''' + S.Name + '''',N'NULL') + N', @ObjectID = @ObjectID, @CheckID = ' + CONVERT(NVARCHAR(50),GC.ID) +  N', @LoginName = @I_LoginName, @RunningID = @RunningID;
END TRY
BEGIN CATCH
	IF XACT_STATE() = -1 ROLLBACK TRAN;
	INSERT	[' + DB_NAME() + N'].dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
	VALUES(''' + GC.Name + N''',ERROR_MESSAGE(),HOST_NAME(),SUSER_NAME(),GETDATE(),' + CONVERT(VARCHAR(10),@RunningID) + ');
END CATCH'
,GC.Name,GC.TestOrder
	FROM	[dbo].[App_GeneralCheck] GC
			LEFT JOIN [dbo].[App_Severity] S ON S.ID = GC.SeverityID
	WHERE	@@MicrosoftVersion / 0x1000000 >= GC.DBVersionID
			AND GC.IsActive = 1
			AND GC.IsPhysicalObject = 1 -- /Only for Physical Object such as Table(Not code objects)
			AND ((GC.IsOnSingleObject = 1 AND @I_ObjectName IS NOT NULL) OR (@I_ObjectName IS NULL AND GC.[IsOnSingleObjectOnly] = 0))
	ORDER BY GC.TestOrder ASC;

	DECLARE @ID INT,
			@ExecuteScript NVARCHAR(4000),
			@Name NVARCHAR(255),
			@TestOrder INT;
	BEGIN TRY

		SET @Print = 'Part 1: Running SP Checks'  + CONVERT(VARCHAR(20),GETDATE(),120);
		IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		DECLARE crExec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT	ID ,
				ExecuteScript,
				Name,TestOrder
		FROM	@RunnableChecks
		ORDER BY TestOrder, ID;
	
		OPEN crExec;
	
		FETCH NEXT FROM crExec INTO @ID, @ExecuteScript, @Name, @TestOrder;
	
		WHILE @@FETCH_STATUS = 0
		BEGIN
	
			BEGIN TRY
					SET @Print = '	Runing - ' + @Name + ' '  + CONVERT(VARCHAR(20),GETDATE(),120);
					IF @I_Debug = 1 
					BEGIN
					    RAISERROR (@Print, 10, 1) WITH NOWAIT;
						PRINT @ExecuteScript;
					END
					EXEC sys.sp_executesql @ExecuteScript, N'@I_ObjectName sysname,@I_LoginName sysname,@RunningID INT', @I_ObjectName = @I_ObjectName, @I_LoginName = @LoginName, @RunningID = @RunningID;
				END TRY
			BEGIN CATCH
					IF XACT_STATE() = -1 -- Transaction is doomed, Rollback everything.
					BEGIN
						ROLLBACK TRAN;
						RAISERROR('Transaction is doomed, Rollback everything. Call the fire department!',16,1);
					END
					INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
					SELECT LEFT(@ExecuteScript,256),ERROR_MESSAGE(), HOST_NAME(),SUSER_NAME(),GETDATE(),@RunningID;--,ERROR_LINE();
					IF @I_Debug = 1 SELECT 'dbo.Mng_ApplicationErrorLog' [TableName],* FROM dbo.Mng_ApplicationErrorLog WHERE MainRunID = @RunningID;
				END CATCH 
	
		FETCH NEXT FROM crExec INTO @ID, @ExecuteScript, @Name, @TestOrder;
	
		END
	
		CLOSE crExec;
		DEALLOCATE crExec;

		--SELECT * FROM #Exeption ORDER BY Severity,Message,ObjectName;

		
		DECLARE @output TABLE(DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CI_AS,
			ObjectName NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
			Type NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
			ColumnName NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
			ConstraintName NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
			Message NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
			URL XML,
			Severity sysname COLLATE SQL_Latin1_General_CP1_CI_AS);

		;WITH CTE AS 
		(
		SELECT	DISTINCT
				e.DatabaseName ,
				e.ObjectName ,
				e.Type ,
				e.ColumnName ,
				e.ConstraintName ,
				e.Message ,
				e.URL ,
				e.Severity 
		FROM	dbo.App_Exeption e
				LEFT JOIN  History.App_IgnoreList il ON e.ErrorID = il.ErrorID
					AND e.DatabaseName = il.DatabaseName
		WHERE	e.MainRunID = @RunningID
				AND IL.ErrorID IS NULL
		)
		INSERT	@output 
		SELECT	e.DatabaseName,
				e.ObjectName,
				e.Type,
				e.ColumnName,
				e.ConstraintName,
				e.Message,
				TRY_CONVERT(XML,e.URL)[URL] ,
				e.Severity
		FROM	CTE e;


		
		--Part 4: Error Handling
		SET @Print = 'Part 4: Error Handling ' + CONVERT(VARCHAR(20),GETDATE(),120);
		IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		IF EXISTS (SELECT TOP (1) 1 FROM dbo.Mng_ApplicationErrorLog WHERE MainRunID = @RunningID)
		BEGIN
			SET @Print =  'There is an Inner Errors. Check Mng_ApplicationErrorLog Table. - SELECT * FROM [dbo].[Mng_ApplicationErrorLog] WHERE MainRunID = ' + CONVERT(VARCHAR(5),@RunningID);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		END

		IF EXISTS(SELECT TOP (1) 1 FROM @output)
		BEGIN
		    SELECT	e.DatabaseName,
					e.ObjectName,
					e.Type,
					e.ColumnName,
					e.ConstraintName,
					e.Message,
					e.URL,
					e.Severity
		    FROM	@output e
			ORDER BY e.Severity,e.Message,e.ObjectName;
		END
		ELSE
		BEGIN
			IF NOT EXISTS (SELECT TOP (1) 1 FROM dbo.Mng_ApplicationErrorLog WHERE MainRunID = @RunningID) PRINT 'No CodeSmell found!';
		END
		IF NOT EXISTS(SELECT TOP (1) 1 FROM History.App_MainRun WHERE ID = @RunningID)
		BEGIN--In case of doomed tran
			SET IDENTITY_INSERT History.App_MainRun ON;
			INSERT History.App_MainRun(ID,ExecuteDate, DatabaseName, ServerName, StartDate, EndDate, IsSingleSP, UserName, ObjectName)
			VALUES(@RunningID,@ExecutionDate,@DataBaseName,@@SERVERNAME,@I_StartDate,@I_EndDate,IIF(@I_ObjectName IS NULL,0,1),IIF(APP_NAME() = 'SQLCMD',dbo.GetParsedPERSIName(ISNULL(@LoginName,SUSER_NAME())),ISNULL(@LoginName,SUSER_NAME())),@I_ObjectName);
			SET IDENTITY_INSERT History.App_MainRun OFF;
		END
		INSERT	History.App_DetailRun(MainRunID, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
		SELECT	@RunningID ,
				e.ObjectName ,
				e.Type ,
				e.ColumnName ,
				e.ConstraintName ,
				e.Message ,
				e.URL ,
				e.Severity,
				e.ErrorID
		FROM	dbo.App_Exeption e
		WHERE	e.MainRunID = @RunningID;
			SET @Print = '
SELECT	DISTINCT MR.DatabaseName,DR.ObjectName ,
		DR.Type ,
		DR.ColumnName ,
		DR.ConstraintName ,
		DR.Message ,
		TRY_CONVERT(XML,DR.URL)[URL] ,
		DR.Severity
FROM	History.App_MainRun MR
		INNER JOIN History.App_DetailRun DR ON DR.MainRunID = MR.ID
WHERE	MR.ID = ' + CONVERT(NVARCHAR(50),@RunningID) + '
ORDER BY DR.Type ASC;'
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			
	END TRY
	BEGIN CATCH
		IF EXISTS (SELECT TOP (1) 1 FROM sys.syscursors WHERE cursor_name = 'crExec')
  		BEGIN
  			CLOSE crExec;
			DEALLOCATE crExec;
  		END  
		
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		OUTPUT Inserted.ID,
			   Inserted.ProcedureName,
			   Inserted.ErrorMessage,
			   Inserted.HostName,
			   Inserted.LoginName,
			   Inserted.ExecutionTime,
			   Inserted.MainRunID
		SELECT	ERROR_PROCEDURE()ProcedureName,ERROR_MESSAGE()ErrorMessage, HOST_NAME()HostName,ISNULL(@LoginName,USER_NAME())LoginName,@ExecutionDate ExecutionTime,@RunningID;
		
		DECLARE @msg NVARCHAR(1000) = ERROR_PROCEDURE() + ': Call your Database Administrator.';
		RAISERROR (@msg,16,1);
		RETURN -1;
	END CATCH

END