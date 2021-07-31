CREATE PROCEDURE [dbo].[usp_App_RunCheck]
	@I_DataBaseName				sysname,
	@I_StartDate				DATE,
	@I_EndDate					DATE,
	@I_ObjectName				sysname = NULL,
	@I_Detail					BIT = 0,
	@I_Part1					BIT = 1,
	@I_CollectProcDefinition	BIT = 1,
	@I_CollectProcName			BIT = 1,
	@I_Code						NVARCHAR(MAX) = NULL,
	@I_Debug					BIT = 0,
	@I_LoginName				sysname = NULL,
	@O_SQLCMDError				NVARCHAR(2048) OUTPUT,
	@I_EventType				VARCHAR(50) = NULL
AS
------------------------------------------------------------------
-- Application Module:  Code Smell
-- Procedure Name:		dbo.usp_App_RunCheck
-- Created:				10/06/2013
-- Author:				sharonr
-- Description:			General SP that run all check by Version Number
--			
-- Updates :
--	On: 10/07/2020	By: dragos
--		Added part to check if an object related to the current one (same version, newer or older version) was compiled by another user in the las 30 days
--			
--	On: 13/08/2020	By: sharonr
--		Added suport of get outpot to PARSI via SQLCMD
--		New output parameter @O_SQLCMDError
--
--	On: 20/12/2020 ; By: sharonr
--		adds ignore from single quotemark
--
--	On: 02/07/2021	By: sharonr
--		Added @I_EventType to activate test only on specific event
--
--  On: 24/07/2021 ; By: sharonr
--      ALTER: Adds to Insert the column name. support new logic DefinitionWithStrings
--
--  On: 29/07/2021 ; By: sharonr
--      ALTER: Move Part pre 1 to be first. there is some SP tests related to the collections
--
-- Parameters: 
--
-- Recordsets: 
--
-- Errors: 
--
------------------------------------------------------------------
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @DBName					NVARCHAR(129),
			@CompatibilityLevel		INT,
			@RunningID				INT,
			@ExecutionDate			DATETIME = GETDATE(),
			@Print					NVARCHAR(2048),
			@DataBaseName			sysname,
			@base_ObjectName		sysname,
			@PrintableOutput		NVARCHAR(2048),
			@RegexRemark			NVARCHAR(2000) = N'(--.*)|(((\/\*)[\w\W]*?(\*\/)))',
			@RegexText				NVARCHAR(2000) = N'(((\''|N\'')[\w\W]*?(\'')))',
			@EventBitMask			INT;
	DECLARE @i						INT = 2147483647;
	

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.',
			@CompatibilityLevel = compatibility_level,
			@DataBaseName = name
	FROM    sys.databases 
	WHERE	name = @I_DataBaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT 'You must enter valid local database name' + ISNULL(N' insted - ' + QUOTENAME(@I_DataBaseName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),ISNULL(@I_LoginName,USER_NAME()),@ExecutionDate,NULL;  
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
	INSERT History.App_MainRun VALUES(@ExecutionDate,@DataBaseName,@@SERVERNAME,@I_StartDate,@I_EndDate,IIF(@I_ObjectName IS NULL,0,1),ISNULL(@I_LoginName,SUSER_NAME()),@I_ObjectName);
	SELECT @RunningID = SCOPE_IDENTITY();

	DECLARE @sqlCmd NVARCHAR(max) = N'' ,
			@prefix NVARCHAR(1000) = N'';  

	-- Contein SP to run.
	DECLARE @RunnableChecks TABLE (
		ID INT NOT NULL,
		ExecuteScript NVARCHAR(4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		Name NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
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

	SELECT @EventBitMask = BitmaskFlag FROM dbo.TriggerEvent WHERE [Name] = @I_EventType;
	
	INSERT	@RunnableChecks(ID, ExecuteScript, Name)
	SELECT	GC.ID, N'USE ' + QUOTENAME(@I_DataBaseName) + ';
DECLARE @ObjectID INT' + IIF(@I_ObjectName IS NOT NULL,' = OBJECT_ID(@I_ObjectName)','') + ';
BEGIN TRY
	EXECUTE [' + DB_NAME() + N'].' + GC.Name + N' @DatabaseName = ''' + @DataBaseName + N''', @Message = ' + ISNULL(N'N''' + REPLACE(GC.[Message],'''','''''') + N'''',N'NULL') + N', @URL_Reference = ' + ISNULL('''' + GC.URL_Reference + '''',N'NULL')+ N', @SeverityName = ' + ISNULL('''' + S.Name + '''',N'NULL') + N', @ObjectID = @ObjectID, @CheckID = ' + CONVERT(NVARCHAR(50),GC.ID) +  N', @LoginName = @I_LoginName, @RunningID = @RunningID;
END TRY
BEGIN CATCH
	IF XACT_STATE() = -1 ROLLBACK TRAN;
	INSERT	[' + DB_NAME() + N'].dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
	VALUES(''' + GC.Name + N''',ERROR_MESSAGE(),HOST_NAME(),SUSER_NAME(),GETDATE(),' + CONVERT(VARCHAR(10),@RunningID) + ');
END CATCH',GC.Name
	FROM	[dbo].[App_GeneralCheck] GC
			LEFT JOIN [dbo].[App_Severity] S ON S.ID = GC.SeverityID
	WHERE	@@MicrosoftVersion / 0x1000000 >= GC.DBVersionID
			AND GC.IsActive = 1
			AND GC.IsPhysicalObject = 0
			AND ((GC.IsOnSingleObject = 1 AND @I_ObjectName IS NOT NULL) OR (@I_ObjectName IS NULL AND GC.[IsOnSingleObjectOnly] = 0));

	DECLARE @ID INT,
			@ExecuteScript NVARCHAR(4000),
			@Name NVARCHAR(255);

	BEGIN TRY
		SET @Print =  'Part pre 1: PopulateTable ' + CONVERT(VARCHAR(20),GETDATE(),120);
		IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		--Get Definition without remarks into -> Background.Inner_sql_modules
		IF @I_ObjectName IS NULL
		BEGIN
			EXEC Background.usp_INNER_PopulateTable @DataBaseName, @I_StartDate, @I_EndDate, @I_ObjectName, @RunningID;
		END
		ELSE
		BEGIN
			--Make code from multiline to single line
			INSERT	Background.Inner_sql_modules(FullObjectName, Definition, Type, Remarks, MainRunID,DefinitionWithStrings)
			SELECT	@I_ObjectName AS FullObjectName ,
					RTRIM(LTRIM(REPLACE(REPLACE(
						[dbo].[ufn_Util_CLR_RegexReplace](
							[dbo].[ufn_Util_CLR_RegexReplace](V.Code,@RegexRemark,'',0)
						,@RegexText,'',0)
						, CHAR(10), ''), CHAR(13), ' '))) [Definition],
					'P',
					r.Remark,
					@RunningID,
					RTRIM(LTRIM(REPLACE(REPLACE(
							[dbo].[ufn_Util_CLR_RegexReplace](V.Code,@RegexRemark,'',0)
						, CHAR(10), ''), CHAR(13), ' '))) [DefinitionWithStrings]
			FROM	(VALUES(@I_Code))V(Code)
					CROSS APPLY (SELECT REPLACE(REPLACE(REPLACE(STUFF((SELECT '' + MatchText FROM [dbo].[ufn_Util_clr_RegexMatch] (
					V.Code,@RegexRemark,0,'') FOR XML PATH('')),1,0,''),'&#x0D;',CHAR(13) + CHAR(10)),'&lt;','<'),'&gt;','>'))r(Remark)
					;
		END

		SET @Print = 'Part pre 1: END PopulateTable ' + CONVERT(VARCHAR(20),GETDATE(),120);
		IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		IF @I_Part1 = 1
		BEGIN
			SET @Print = 'Part 1: Running SP Checks'  + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			DECLARE crExec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT	ID ,
					ExecuteScript,
					Name
			FROM	@RunnableChecks
			ORDER BY ID;
	
			OPEN crExec;
	
			FETCH NEXT FROM crExec INTO @ID, @ExecuteScript, @Name
	
			WHILE @@FETCH_STATUS = 0
			BEGIN
	
				BEGIN TRY
					SET @Print = '	Runing - ' + @Name + ' '  + CONVERT(VARCHAR(20),GETDATE(),120);
					IF @I_Debug = 1 
					BEGIN
					    RAISERROR (@Print, 10, 1) WITH NOWAIT;
						PRINT @ExecuteScript;
					END
					EXEC sys.sp_executesql @ExecuteScript, N'@I_ObjectName sysname,@I_LoginName sysname,@RunningID INT', @I_ObjectName = @I_ObjectName, @I_LoginName = @I_LoginName, @RunningID = @RunningID;
				END TRY
				BEGIN CATCH
					IF XACT_STATE() = -1 -- Transaction is doomed, Rollback everything.
					BEGIN
						ROLLBACK TRAN;
						RAISERROR('Transaction is doomed, Rollback everything. Call the fire department!',16,1);
					END
					INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
					SELECT LEFT(@ExecuteScript,256),ERROR_MESSAGE(), HOST_NAME(),ISNULL(@I_LoginName,SUSER_NAME()),GETDATE(),@RunningID;--,ERROR_LINE();
					IF @I_Debug = 1 SELECT 'dbo.Mng_ApplicationErrorLog' [TableName],* FROM dbo.Mng_ApplicationErrorLog WHERE MainRunID = @RunningID;
				END CATCH  
			IF @I_Debug = 1 SELECT 'dbo.App_Exeption' [TableName], * FROM dbo.App_Exeption WHERE MainRunID = @RunningID;
			FETCH NEXT FROM crExec INTO @ID, @ExecuteScript, @Name
	
			END
	
			CLOSE crExec;
			DEALLOCATE crExec;

		END
		
		IF (CONVERT(TINYINT,ISNULL(@I_CollectProcDefinition,1)) + CONVERT(TINYINT,ISNULL(@I_CollectProcName,1))) > 0
		BEGIN

			-- Collect test checks to run on the inventory
			SET @Print =  'Part 2: Insert @Error (Collect test checks to run on the inventory)' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			INSERT	@Error(ID, [Type], [Message], URL_Reference, IsCheckOnProcName, Regex, SearchRegexMethodID, SeverityID, NotIn_RegexPettern,CodeTypeID)
			SELECT	E.ID ,
					SG.Subject + ' - ' + E.Name [Type],
					E.[Message] ,
					E.URL_Reference ,
					E.IsCheckOnProcName,
					RP.Regex,
					CL.SearchRegexMethodID,
					E.SeverityID,
					NIRP.Regex NotIn_RegexPettern,
					CL.CodeTypeID
			FROM	dbo.App_Error E
					INNER JOIN dbo.App_CL_ErrVerPet CL ON E.ID = CL.ErrorID
					INNER JOIN dbo.App_DBVersion V ON e.DBVersionID = V.ID
					INNER JOIN dbo.App_RegexPettern RP ON RP.ID = CL.RegexPetternID
					INNER JOIN dbo.App_SubjectGroup SG ON SG.ID = E.SubjectGroupID
					LEFT JOIN  dbo.App_RegexPettern NIRP ON NIRP.ID = CL.[NotIn_RegexPetternID]
			WHERE	@@MicrosoftVersion / 0x1000000 >= V.ID
					AND E.IsActive = 1
					AND	(@EventBitMask IS NULL OR TriggerEvent_Bitmask & @EventBitMask = @EventBitMask OR TriggerEvent_Bitmask IS NULL)
			UNION ALL
			SELECT	0,
					'Procedure' Type,
					'Do not enter database name in the code.' [Message],
					NULL,
					0 [IsCheckOnProcName],
					CONCAT('\b',@DatabaseName,'\b') [Regex],
					1, /*Found In The Code*/
					2, -- SeverityID: Minor
					NULL NotIn_RegexPettern,
					1;
			SET @Print = 'Part 2: END Insert @Error ' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;

			--TRUNCATE TABLE Background.Inner_sql_DefinitionRegex;
			--TRUNCATE TABLE Background.Inner_sql_ObjectNameRegex;

			DECLARE @SPcnt INT;
			SELECT	@SPcnt = COUNT_BIG(1) 
			FROM	Background.Inner_sql_modules
			WHERE	Type = 'P'
					AND MainRunID = @RunningID;
		
		IF @I_CollectProcDefinition = 1
		BEGIN
			--ProcDefinition
			SET @Print = 'Part 3: Collect Proc Definition + Regex term ' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			INSERT	Background.Inner_sql_DefinitionRegex(ID, FullObjectName, SearchRegexMethodID, Regex, NotIn_RegexPettern, MainRunID, CodeTypeID)
			SELECT	E.ID,
					PP.FullObjectName,
					E.SearchRegexMethodID,
					E.Regex,
					E.NotIn_RegexPettern,
					@RunningID,
					E.CodeTypeID
			FROM	@Error E
					CROSS JOIN Background.Inner_sql_modules PP
			WHERE	PP.type = 'P' 
					AND PP.MainRunID = @RunningID
					AND E.IsCheckOnProcName = 0;
		END
		IF @I_CollectProcName = 1
		BEGIN
			--ProcName
			SET @Print = 'Part 3: Collect Proc name + Regex term ' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			INSERT	Background.Inner_sql_ObjectNameRegex(ID, FullObjectName, SearchRegexMethodID, ObjectName, MainRunID)
			SELECT  E.ID,
					PP.FullObjectName,
					E.SearchRegexMethodID,
					SUBSTRING(PP.FullObjectName,CHARINDEX('.',PP.FullObjectName)+ 1,LEN(PP.FullObjectName)) ObjectName,
					@RunningID
			FROM    Background.Inner_sql_modules PP
					CROSS JOIN @Error E
			WHERE   PP.type = 'P'
					AND PP.MainRunID = @RunningID
					AND E.IsCheckOnProcName = 1;
		
		---------------------------------------------------------------------------------------------------------
			--Find match/dismatch by regex to collect
			SET @Print = 'Part 3: Find match/dismatch by RegEx only into @OutTmp ' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			INSERT	@OutTmp(ID, ObjectName)
			SELECT	DISTINCT TOP(@i)  
					DR.ID,
					M.FullObjectName
			FROM	[Background].[Inner_sql_modules] M
					CROSS APPLY (SELECT	ID 
								 FROM	Background.Inner_sql_DefinitionRegex DR
								 WHERE	DR.MainRunID = M.MainRunID
										AND M.FullObjectName = DR.FullObjectName
										AND DR.NotIn_RegexPettern IS NULL
										AND DR.SearchRegexMethodID IN (1,2) -- (1-Regex is Match, 2-Regex is not match)
										AND [dbo].[ufn_Util_clr_RegexIsMatch] (CASE DR.CodeTypeID WHEN 1 THEN M.Definition
																		  WHEN 2 THEN M.DefinitionWithStrings
																		  WHEN 3 THEN M.Remarks ELSE M.Definition END,DR.Regex,0) = IIF(DR.SearchRegexMethodID = 1,1,0))DR-- 1-Regex is Match(1)/2-Total Regex is not match(0)
			WHERE	M.MainRunID = @RunningID
			OPTION (RECOMPILE,OPTIMIZE FOR (@i = 50000));
			
			SET @Print = 'Part 3: Find match by RegEx + RegEx dismatch into @OutTmp ' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
			INSERT	@OutTmp(ID, ObjectName)
			SELECT	DISTINCT TOP(@i)  
					DR.ID,
					M.FullObjectName
			FROM	[Background].[Inner_sql_modules] M
					CROSS APPLY (SELECT	ID ,DR.NotIn_RegexPettern
								 FROM	Background.Inner_sql_DefinitionRegex DR
								 WHERE	DR.MainRunID = M.MainRunID
										AND M.FullObjectName = DR.FullObjectName
										AND DR.NotIn_RegexPettern IS NOT NULL 
										AND [dbo].[ufn_Util_clr_RegexIsMatch] (CASE DR.CodeTypeID WHEN 1 THEN M.Definition
																		  WHEN 2 THEN M.DefinitionWithStrings
																		  WHEN 3 THEN M.Remarks ELSE M.Definition END,DR.Regex,0) = 1-- Regex is Match
										)DR
			WHERE	[dbo].[ufn_Util_clr_RegexIsMatch] (M.Definition,DR.NotIn_RegexPettern,0) = 0-- Regex is not match
					AND	M.MainRunID = @RunningID
			OPTION (RECOMPILE,OPTIMIZE FOR (@i = 50000));
			
			------------------------------------------------------------------------------------
			SET @Print = 'Part 3: Collect all records from @OutTmp into dbo.App_Exeption(@I_Detail = 1) ' + CONVERT(VARCHAR(20),GETDATE(),120);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;

			INSERT	dbo.App_Exeption (MainRunID,DatabaseName,ObjectName,[Type],[Message],[URL],Severity,ErrorID)
			SELECT	@RunningID,
					@DatabaseName,
					O.ObjectName,
					Er.[Type],
					Er.[Message],
					Er.URL_Reference,
					S.[Name],
					Er.ID
			FROM	@OutTmp O
					INNER JOIN @Error Er ON Er.ID = O.ID
					INNER JOIN [dbo].[App_Severity] S ON Er.SeverityID = S.ID
					LEFT JOIN dbo.App_Exclusion Ex ON O.ID = Ex.ID
								AND  O.ObjectName = Ex.object_name
			WHERE	Ex.ID IS NULL;

			DECLARE @output TABLE(DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CI_AS,
				ObjectName NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
				[Type] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
				ColumnName NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
				ConstraintName NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
				[Message] NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
				[URL] XML,
				Severity sysname COLLATE SQL_Latin1_General_CP1_CI_AS);
			IF	@I_Detail = 1 OR @I_ObjectName IS NOT NULL
			BEGIN
				INSERT	@output(DatabaseName, ObjectName, [Type], ColumnName, ConstraintName, [Message], [URL], Severity)
				SELECT	e.DatabaseName ,
						e.ObjectName ,
						e.[Type] ,
						e.ColumnName ,
						e.ConstraintName ,
						e.Message ,
						TRY_CONVERT(XML,e.URL)[URL] ,
						e.Severity 
				FROM	dbo.App_Exeption e
						LEFT JOIN  History.App_IgnoreList il ON e.ErrorID = il.ErrorID
							AND e.DatabaseName = il.DatabaseName
				WHERE	e.MainRunID = @RunningID
						AND IL.ErrorID IS NULL;
			END
			ELSE
			BEGIN
				;WITH Exeption AS (
					SELECT	@DatabaseName [DatabaseName],
							CONVERT(NVARCHAR(255),CASE WHEN O.iOVER = 1 THEN 'Over 20% SP: ' ELSE O.ObjectName END) [ObjectName],
							ISNULL(Er.Type,O.Type)[Type],
							ISNULL(Er.Message,O.Message)Message,
							ISNULL(Er.URL_Reference,O.URL) [URL],
							S.Name [Severity],
							ISNULL(Er.ID,O.ID) [ErrorID]
					FROM	(SELECT	O.ErrorID ID, O.ObjectName ,O.Message,O.Type,O.URL,
							 CASE WHEN t.CNT > (@SPcnt * 0.2) THEN ROW_NUMBER() OVER (PARTITION BY t.ID,t.CNT ORDER BY O.ObjectName) ELSE 1 END iRN,
							 CASE WHEN t.CNT > (@SPcnt * 0.2) THEN 1 ELSE 0 END iOVER
			    			 FROM	dbo.App_Exeption O
									INNER JOIN (SELECT	Oe.ErrorID ID ,
			    										COUNT_BIG(Oe.ErrorID) CNT
			    								FROM	dbo.App_Exeption Oe
												WHERE	Oe.MainRunID = @RunningID
												GROUP BY Oe.ErrorID)t ON t.ID = O.ErrorID
							WHERE	O.MainRunID = @RunningID
							) O
							LEFT JOIN @Error Er ON Er.ID = O.ID
							LEFT JOIN [dbo].[App_Severity] S ON Er.SeverityID = S.ID
							LEFT JOIN dbo.App_Exclusion Ex ON O.ID = Ex.ID
										AND  O.ObjectName = Ex.object_name
					WHERE	Ex.ID IS NULL
							AND O.iRN = 1)
				INSERT	@output (DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity)
				SELECT	e.DatabaseName ,
						e.ObjectName ,
						e.Type ,
						CONVERT(NVARCHAR(2000),NULL) [ColumnName],
						CONVERT(NVARCHAR(2000),NULL) [ConstraintName],
						e.Message ,
						TRY_CONVERT(XML,e.URL)[URL] ,
						e.Severity 
				FROM	Exeption e
						LEFT JOIN History.App_IgnoreList il ON e.ErrorID = il.ErrorID
							AND e.DatabaseName = il.DatabaseName
				WHERE	IL.ErrorID IS NULL;
				--ORDER BY e.Severity,e.Message,e.ObjectName;
			END
		END
		END

		IF EXISTS(SELECT TOP (1) 1 FROM @output)
		BEGIN
			IF APP_NAME() = 'SQLCMD'
			BEGIN
				SET @O_SQLCMDError = '';
				SELECT	@O_SQLCMDError += CONCAT(ROW_NUMBER() OVER (ORDER BY e.Severity,e.Message,e.ObjectName),'. ',
						e.Message,CHAR(13))
				FROM	@output e
				WHERE	Severity != 'Warning'
						AND e.Message NOT IN ('Please Insert comment of today date with a description of your changes in this procedure.')
						
				ORDER BY e.Severity,e.Message,e.ObjectName;
				IF @@ROWCOUNT = 0
				BEGIN
					SET @O_SQLCMDError = NULL;
				END
				
			    --RAISERROR(@PrintableOutput,16,1);
			END
			ELSE IF APP_NAME() = 'Microsoft SQL Server Management Studio - Query'
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
		END
		ELSE
		BEGIN
		    PRINT 'The Code is not smelling!';
		END

		--Part 4: Error Handling
		SET @Print = 'Part 4: Error Handling ' + CONVERT(VARCHAR(20),GETDATE(),120);
		IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		IF EXISTS (SELECT TOP (1) 1 FROM dbo.Mng_ApplicationErrorLog WHERE MainRunID = @RunningID)
		BEGIN
			SET @Print =  'There is an Inner Errors. Check Mng_ApplicationErrorLog Table. - SELECT * FROM [dbo].[Mng_ApplicationErrorLog] WHERE MainRunID = ' + CONVERT(VARCHAR(5),@RunningID);
			IF @I_Debug = 1 RAISERROR (@Print, 10, 1) WITH NOWAIT;
		END
		IF NOT EXISTS(SELECT TOP (1) 1 FROM History.App_MainRun WHERE ID = @RunningID)
		BEGIN--In case of doomed tran
			SET IDENTITY_INSERT History.App_MainRun ON;
			INSERT History.App_MainRun(ID,ExecuteDate, DatabaseName, ServerName, StartDate, EndDate, IsSingleSP, UserName, ObjectName)
			VALUES(@RunningID,@ExecutionDate,@DataBaseName,@@SERVERNAME,@I_StartDate,@I_EndDate,IIF(@I_ObjectName IS NULL,0,1),ISNULL(@I_LoginName,SUSER_NAME()),@I_ObjectName);
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
SELECT	MR.DatabaseName,DR.ObjectName ,
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
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		OUTPUT Inserted.ID,
			   Inserted.ProcedureName,
			   Inserted.ErrorMessage,
			   Inserted.HostName,
			   Inserted.LoginName,
			   Inserted.ExecutionTime,
			   Inserted.MainRunID
		SELECT	ISNULL(ERROR_PROCEDURE(),OBJECT_NAME(@@PROCID)) ProcedureName, ISNULL(ERROR_MESSAGE(),'End of SP(No error)') ErrorMessage, HOST_NAME()HostName,ISNULL(@I_LoginName,USER_NAME())LoginName,@ExecutionDate ExecutionTime,@RunningID;
		
		IF EXISTS (SELECT TOP (1) 1 FROM sys.syscursors WHERE cursor_name = 'crExec')
  		BEGIN
  			CLOSE crExec;
			DEALLOCATE crExec;
  		END  
		DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE();-- + ': Call your Database Administrator.';
		RAISERROR (@msg,16,1);
		RETURN -1;
	END CATCH

END