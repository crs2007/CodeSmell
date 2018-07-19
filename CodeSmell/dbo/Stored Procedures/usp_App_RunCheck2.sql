-- =============================================
-- Author:		Sharon
-- Create date: 10/06/2013
-- Description:	General SP that run all check by Version Number
-- =============================================
CREATE PROCEDURE [dbo].[usp_App_RunCheck2]
	@DataBaseName sysname,
	@StartDate DATE,
	@EndDate DATE,
	@Detail BIT = 0
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @DBName NVARCHAR(129),
			@compatibility_level INT,
			@RunningID INT,
			@ExecutionDate DATETIME = GETDATE(),
			@Print NVARCHAR(2048);

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.',@compatibility_level = compatibility_level
	FROM    sys.databases 
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT 'You must enter valid local database name' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),USER_NAME(),@ExecutionDate,NULL;  
		RAISERROR ('You must enter valid local database name',16,1);
		RETURN - 1;
	END

	SELECT TOP 1 @RunningID = MR.ID FROM  History.App_MainRun mr WHERE MR.DatabaseName = @DBName AND MR.StartDate = @StartDate AND MR.EndDate = @EndDate
	IF @@ROWCOUNT > 0
	BEGIN
		SELECT	DISTINCT 
				MR.DatabaseName,
				DR.ObjectName ,
                DR.Type ,
                DR.ColumnName ,
                DR.ConstraintName ,
                DR.Massege ,
                DR.URL ,
                DR.Severity
		FROM	History.App_MainRun MR
				INNER JOIN History.App_DetailRun DR ON DR.MainRunID = MR.ID
		WHERE	MR.ID = @RunningID;
		RETURN 1;
	END
	INSERT History.App_MainRun VALUES(@ExecutionDate,@DataBaseName,@@SERVERNAME,@StartDate,@EndDate);
	SELECT @RunningID = SCOPE_IDENTITY();

	DECLARE @sqlCmd NVARCHAR(max) = N'' ,
			@prefix NVARCHAR(1000) = N'';  

	IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL DROP TABLE #Mng_ApplicationErrorLog;
	-- Inner Error log for check test SP.
    CREATE TABLE #Mng_ApplicationErrorLog (
		[ProcedureName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ErrorMessage] [nvarchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		[HostName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[LoginName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	);
	
	IF OBJECT_ID('tempdb..#RunnableChecks') IS NOT NULL DROP TABLE #RunnableChecks;
	-- Contein SP to run.
	CREATE TABLE #RunnableChecks (
		ID INT NOT NULL,
		ExecuteScript NVARCHAR(4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		Name NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	);

	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL DROP TABLE #Exeption;
	-- Collecte all errors from checks.
	CREATE TABLE #Exeption (
		DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CI_AS,
		ObjectName NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Type NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		ColumnName NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
		ConstraintName NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Massege NVARCHAR(2000) COLLATE SQL_Latin1_General_CP1_CI_AS,
		URL VARCHAR(512) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Severity sysname COLLATE SQL_Latin1_General_CP1_CI_AS,
		ErrorID INT NULL
	);

	IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL DROP TABLE #DBInfo;
    CREATE TABLE #DBInfo
    (
		ParentObject VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Object VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Field VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Value VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
    );

	INSERT #DBInfo
	EXEC ('DBCC DBInfo(' + @DatabaseName + ') With TableResults, NO_INFOMSGS');

	INSERT	#RunnableChecks
	SELECT	GC.ID, N'EXEC ' + GC.Name + N' ''' + @DataBaseName + N''',' + ISNULL('''' + REPLACE(GC.Massege,'''','''''') + '',N'NULL') + N''',' + ISNULL('''' + GC.URL_Reference + '''',N'NULL')+ N',' + ISNULL('''' + S.Name + '''',N'NULL') + N',NULL,' + CONVERT(NVARCHAR(50),GC.ID) +  N';
',GC.Name
	FROM	[dbo].[App_GeneralCheck] GC
			LEFT JOIN [dbo].[App_Severity] S ON S.ID = GC.SeverityID
	WHERE	@@MicrosoftVersion / 0x1000000 >= GC.DBVersionID
			AND GC.IsActive = 1;

	--PRINT @sqlCmd;
	
	DECLARE @ID INT,
			@ExecuteScript NVARCHAR(4000),
			@Name NVARCHAR(255);

	SET @Print = 'Part 1: Running SP Checks'  + CONVERT(VARCHAR(20),GETDATE(),120);
	RAISERROR (@Print, 10, 1) WITH NOWAIT;

	BEGIN TRY	
		DECLARE crExec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT	ID ,
				ExecuteScript,
				Name
		FROM	#RunnableChecks
		ORDER BY ID;
	
		OPEN crExec;
	
		FETCH NEXT FROM crExec INTO @ID, @ExecuteScript, @Name
	
		WHILE @@FETCH_STATUS = 0
		BEGIN
	
			BEGIN TRY
				SET @Print = 'Runing - ' + @Name + ' '  + CONVERT(VARCHAR(20),GETDATE(),120);
				RAISERROR (@Print, 10, 1) WITH NOWAIT;
				--PRINT @ExecuteScript
				EXEC sys.sp_executesql @ExecuteScript;
			END TRY
			BEGIN CATCH
				INSERT #Mng_ApplicationErrorLog
				SELECT ISNULL(ERROR_PROCEDURE(),@Name),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();--,ERROR_LINE();
			END CATCH  
	
		FETCH NEXT FROM crExec INTO @ID, @ExecuteScript, @Name
	
		END
	
		CLOSE crExec;
		DEALLOCATE crExec;

		--SELECT * FROM #Exeption ORDER BY Severity,Massege,ObjectName;

		--Part 2: Running Regex On Moduls
		SET @Print =  'Part 2: Running Regex On Moduls ' + CONVERT(VARCHAR(20),GETDATE(),120);
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		SET @Print =  'Part 2: PopulateTable ' + CONVERT(VARCHAR(20),GETDATE(),120);
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		EXEC Background.usp_INNER_PopulateTable @DataBaseName, @StartDate, @EndDate,NULL;
		SET @Print = 'Part 2: END PopulateTable ' + CONVERT(VARCHAR(20),GETDATE(),120);
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		CREATE TABLE #Error (
			ID INT,
			Type VARCHAR(305) COLLATE SQL_Latin1_General_CP1_CI_AS,
			Massege VARCHAR(512) COLLATE SQL_Latin1_General_CP1_CI_AS,
			URL_Reference VARCHAR(512) COLLATE SQL_Latin1_General_CP1_CI_AS,
			IsCheckOnProcName BIT,
			Regex NVARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS,
			SearchRegexMethodID INT,
			SeverityID INT,
			NotIn_RegexPettern NVARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS
		);
		SET @Print =  'Part 2: Insert #Error ' + CONVERT(VARCHAR(20),GETDATE(),120);
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		INSERT	#Error
		SELECT	E.ID ,
				SG.Subject + ' - ' + E.Name Type,
				E.Massege ,
				E.URL_Reference ,
				E.IsCheckOnProcName,
				RP.Regex,
				CL.SearchRegexMethodID,
				E.SeverityID,
				NIRP.Regex NotIn_RegexPettern
		FROM	dbo.App_Error E
				INNER JOIN dbo.App_CL_ErrVerPet CL ON E.ID = CL.ErrorID
				INNER JOIN dbo.App_DBVersion V ON e.DBVersionID = V.ID
				INNER JOIN dbo.App_RegexPettern RP ON RP.ID = CL.RegexPetternID
				INNER JOIN dbo.App_SubjectGroup SG ON SG.ID = E.SubjectGroupID
				LEFT JOIN  dbo.App_RegexPettern NIRP ON NIRP.ID = CL.[NotIn_RegexPetternID]
		WHERE	@@MicrosoftVersion / 0x1000000 >= V.ID
				AND E.IsActive = 1
		UNION ALL
		SELECT	0,
				'Procedure' Type,
				'Do not enter database name in the code.' Massege,
				NULL,
				0,
				@DatabaseName,
				1, /*Found In The Code*/
				2, -- SeverityID: Minor
				NULL NotIn_RegexPettern;
		SET @Print = 'Part 2: END Insert #Error ' + CONVERT(VARCHAR(20),GETDATE(),120);
		RAISERROR (@Print, 10, 1) WITH NOWAIT;

		TRUNCATE TABLE Background.Inner_sql_DefinitionRegex;
		TRUNCATE TABLE Background.Inner_sql_ObjectNameRegex;

		DECLARE @SPcnt INT;
		SELECT	@SPcnt = COUNT_BIG(1) 
		FROM	Background.Inner_sql_modules
		WHERE	Type = 'P';


		--ProcDefinition
		INSERT	Background.Inner_sql_DefinitionRegex
		SELECT	E.ID,
				PP.FullObjectName,
				E.SearchRegexMethodID,
				PP.[Definition],
				E.Regex,
				E.NotIn_RegexPettern
		FROM	#Error E
				CROSS JOIN  Background.Inner_sql_modules PP
		WHERE	PP.type = 'P' 
				AND E.IsCheckOnProcName = 0
		ORDER BY E.ID,
				PP.FullObjectName;
		--ProcName
		INSERT	Background.Inner_sql_ObjectNameRegex
		SELECT  E.ID,
				PP.FullObjectName,
				E.SearchRegexMethodID,
				SUBSTRING(PP.FullObjectName,CHARINDEX('.',PP.FullObjectName)+ 1,LEN(PP.FullObjectName)) ObjectName
		FROM    Background.Inner_sql_modules PP
				CROSS JOIN #Error E
		WHERE   PP.type = 'P'
				AND E.IsCheckOnProcName = 1
		ORDER BY E.ID,
				PP.FullObjectName;


		CREATE TABLE #OutTmp (ID INT, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CI_AS);

		DECLARE @i INT = 2147483647;

		INSERT	#OutTmp
		SELECT	DISTINCT TOP(@i)  
				DR.ID,
				M.FullObjectName
		FROM	[Background].[Inner_sql_modules] M
				CROSS APPLY (SELECT	ID 
							 FROM	Background.Inner_sql_DefinitionRegex DR
							 WHERE	M.FullObjectName = DR.FullObjectName
									AND DR.NotIn_RegexPettern IS NULL
									AND DR.SearchRegexMethodID = 1
									AND [dbo].[ufn_Util_clr_RegexIsMatch] (DR.Definition,DR.Regex,0) = 1)DR
		OPTION (RECOMPILE,OPTIMIZE FOR (@i = 50000))--, QUERYTRACEON 8649)

		INSERT	#OutTmp
		SELECT	DISTINCT TOP(@i)  
				DR.ID,
				M.FullObjectName
		FROM	[Background].[Inner_sql_modules] M
				CROSS APPLY (SELECT	ID ,DR.Definition,DR.NotIn_RegexPettern
							 FROM	Background.Inner_sql_DefinitionRegex DR
							 WHERE	M.FullObjectName = DR.FullObjectName
									AND DR.NotIn_RegexPettern IS NOT NULL
									AND [dbo].[ufn_Util_clr_RegexIsMatch] (DR.Definition,DR.Regex,0) = 1
									)DR
		WHERE	[dbo].[ufn_Util_clr_RegexIsMatch] (DR.Definition,DR.NotIn_RegexPettern,0) = 0
		OPTION (RECOMPILE,OPTIMIZE FOR (@i = 50000))--, QUERYTRACEON 8649)

		INSERT	#OutTmp
		SELECT	DISTINCT TOP(@i)  
				DR.ID,
				M.FullObjectName
		FROM	[Background].[Inner_sql_modules] M
				CROSS APPLY (SELECT	ID 
							 FROM	Background.Inner_sql_DefinitionRegex DR
							 WHERE	M.FullObjectName = DR.FullObjectName
									AND DR.NotIn_RegexPettern IS NULL
									AND DR.SearchRegexMethodID = 2
									AND [dbo].[ufn_Util_clr_RegexIsMatch] (DR.Definition,DR.Regex,0) = 0)DR
		OPTION (RECOMPILE,OPTIMIZE FOR (@i = 50000))--, QUERYTRACEON 8649)
		
		IF	@Detail = 1 
			INSERT	#Exeption
			SELECT	@DatabaseName,
					O.ObjectName,
					Er.Type,
					NULL, /*--ColumnName*/
					NULL, /*--ConstraintName*/
					Er.Massege,
					Er.URL_Reference,
					S.Name,
					Er.ID
			FROM	#OutTmp O
					INNER JOIN #Error Er ON Er.ID = O.ID
					INNER JOIN [dbo].[App_Severity] S ON Er.SeverityID = S.ID
					LEFT JOIN dbo.App_Exclusion Ex ON O.ID = Ex.ID
								AND  O.ObjectName = Ex.object_name
			WHERE	Ex.ID IS NULL;
		ELSE
			INSERT	#Exeption

			SELECT	@DatabaseName,
					CASE WHEN O.iOVER = 1 THEN 'Over 20% SP: ' ELSE O.ObjectName END,
					Er.Type,
					NULL, /*--ColumnName*/
					NULL, /*--ConstraintName*/
					Er.Massege,
					Er.URL_Reference,
					S.Name,
					Er.ID
			FROM	(SELECT	O.ID, O.ObjectName ,
					 CASE WHEN t.CNT > (@SPcnt * 0.2) THEN ROW_NUMBER() OVER (PARTITION BY t.ID,t.CNT ORDER BY O.ObjectName) ELSE 1 END iRN,
					 CASE WHEN t.CNT > (@SPcnt * 0.2) THEN 1 ELSE 0 END iOVER
			    	 FROM	#OutTmp O
							INNER JOIN (SELECT	 ID ,
			    								 COUNT_BIG(ID) CNT
			    						FROM	#OutTmp O
										GROUP BY ID)t ON t.ID = O.ID
					) O
					INNER JOIN #Error Er ON Er.ID = O.ID
					INNER JOIN [dbo].[App_Severity] S ON Er.SeverityID = S.ID
					LEFT JOIN dbo.App_Exclusion Ex ON O.ID = Ex.ID
								AND  O.ObjectName = Ex.object_name
			WHERE	Ex.ID IS NULL
					AND O.iRN = 1;
		--SET @sqlCmd = N'';

		--BEGIN TRY
		--	PRINT 'Part 2: Run Regex Query' + CONVERT(VARCHAR(20),GETDATE(),120);
		--	PRINT @sqlCmd;      
		--	EXEC sp_executesql	@sqlCmd, 
		--						N'@DatabaseName SYSNAME,
		--						  @StartDate DATETIME,
		--						  @EndDate DATETIME
		--						', 
		--						@DatabaseName = @DatabaseName,
		--						@StartDate = @StartDate,
		--						@EndDate = @EndDate
		--END TRY
		--BEGIN CATCH
		 
		--	INSERT #Mng_ApplicationErrorLog
		--	SELECT ISNULL(ERROR_PROCEDURE(),'dbo.usp_App_RunCheck - Regex'),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		--END CATCH
		--	SET @Print =  'Part 2: End Run Regex Query' + CONVERT(VARCHAR(20),GETDATE(),120);
		--	RAISERROR (@Print, 10, 1) WITH NOWAIT;

		--Part 3: Error Handling
		IF EXISTS (SELECT TOP 1 1 FROM #Mng_ApplicationErrorLog)
			BEGIN
				INSERT	dbo.Mng_ApplicationErrorLog
				SELECT	ProcedureName ,
						ErrorMessage ,
						HostName ,
						LoginName ,
						@ExecutionDate ExecutionTime ,
						@RunningID
				FROM	#Mng_ApplicationErrorLog
				SET @Print =  'There is an Inner Errors. Check Mng_ApplicationErrorLog Table. - SELECT * FROM [dbo].[Mng_ApplicationErrorLog] WHERE MainRunID = ' + CONVERT(VARCHAR(5),@RunningID);
				RAISERROR (@Print, 10, 1) WITH NOWAIT;
			END

			SELECT	e.DatabaseName ,
                    e.ObjectName ,
                    e.Type ,
                    e.ColumnName ,
                    e.ConstraintName ,
                    e.Massege ,
                    e.URL ,
                    e.Severity 
			FROM	#Exeption e
					LEFT JOIN  History.App_IgnoreList il ON e.ErrorID = il.ErrorID
						AND e.DatabaseName = il.DatabaseName
			WHERE	IL.ErrorID IS NULL
			ORDER BY e.Severity,e.Massege,e.ObjectName;

			INSERT History.App_DetailRun
			SELECT	@RunningID ,
                    e.ObjectName ,
                    e.Type ,
                    e.ColumnName ,
                    e.ConstraintName ,
                    e.Massege ,
                    e.URL ,
                    e.Severity,
					e.ErrorID
			FROM	#Exeption e

		SET @Print = 'SELECT	DISTINCT MR.DatabaseName,DR.ObjectName ,
                                 DR.Type ,
                                 DR.ColumnName ,
                                 DR.ConstraintName ,
                                 DR.Massege ,
                                 DR.URL ,
                                 DR.Severity
FROM	History.App_MainRun MR
		INNER JOIN History.App_DetailRun DR ON DR.MainRunID = MR.ID
WHERE	MR.ID = ' + CONVERT(NVARCHAR(50),@RunningID) + ';'
			RAISERROR (@Print, 10, 1) WITH NOWAIT;

			IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL DROP TABLE #DBInfo;
			IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL DROP TABLE #Mng_ApplicationErrorLog;
			IF OBJECT_ID('tempdb..#RunnableChecks') IS NOT NULL DROP TABLE #RunnableChecks;
			IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL DROP TABLE #Exeption;
			IF OBJECT_ID('tempdb..#OutTmp') IS NOT NULL DROP TABLE #OutTmp;
	END TRY
	BEGIN CATCH
		IF EXISTS (SELECT TOP 1 1 FROM SYS.syscursors WHERE cursor_name = 'crExec')
  		BEGIN
  			CLOSE crExec;
			DEALLOCATE crExec;
  		END  

		IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL DROP TABLE #DBInfo;
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL DROP TABLE #Mng_ApplicationErrorLog;
		IF OBJECT_ID('tempdb..#RunnableChecks') IS NOT NULL DROP TABLE #RunnableChecks;
		IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL DROP TABLE #Exeption;
		IF OBJECT_ID('tempdb..#OutTmp') IS NOT NULL DROP TABLE #OutTmp;
		  
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT ERROR_PROCEDURE()ProcedureName,ERROR_MESSAGE()ErrorMessage, HOST_NAME()HostName,USER_NAME()LoginName,@ExecutionDate ExecutionTime,@RunningID;
		
		DECLARE @msg NVARCHAR(1000) = ERROR_PROCEDURE() + ': Call your Database Administrator.';
		RAISERROR (@msg,16,1);
		RETURN -1;
	END CATCH

	TRUNCATE TABLE Background.Inner_sql_modules;

END