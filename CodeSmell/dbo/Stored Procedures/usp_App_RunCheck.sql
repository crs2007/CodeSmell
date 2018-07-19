-- =============================================
-- Author:		Sharon
-- Create date: 10/06/2013
-- Description:	General SP that run all check by Version Number
-- =============================================
CREATE PROCEDURE [dbo].[usp_App_RunCheck]
	@DataBaseName sysname,
	@StartDate DATETIME,
	@EndDate DATETIME
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @DBName NVARCHAR(129),
			@compatibility_level int;

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.',@compatibility_level = compatibility_level
	FROM    sys.databases WITH(NOLOCK)
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT 'You must enter valid local database name' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),USER_NAME(),GETDATE();  
		RAISERROR ('You must enter valid local database name',16,1);
		RETURN;
	END
	
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
		Severity sysname COLLATE SQL_Latin1_General_CP1_CI_AS
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
	SELECT	GC.ID, N'EXEC ' + GC.Name + N' ''' + @DataBaseName + N''',' + ISNULL('''' + REPLACE(GC.Massege,'''','''''') + '',N'NULL') + N''',' + ISNULL('''' + GC.URL_Reference + '''',N'NULL')+ N',' + ISNULL('''' + S.Name + '''',N'NULL') + N';
',GC.Name
	FROM	[dbo].[App_GeneralCheck] GC
			LEFT JOIN [dbo].[App_Severity] S ON S.ID = GC.SeverityID
	WHERE	@@MicrosoftVersion / 0x1000000 >= GC.DBVersionID
			AND GC.IsActive = 1;

	--PRINT @sqlCmd;
	


	DECLARE @ID INT,
			@ExecuteScript NVARCHAR(4000),
			@Name NVARCHAR(255)
	PRINT 'Part 1: Running SP Checks'  + CONVERT(VARCHAR(20),GETDATE(),120);
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
				PRINT 'Runing - ' + @Name + ' '  + CONVERT(VARCHAR(20),GETDATE(),120);;
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

		--Part 2: Running Regex On Moduls
		PRINT 'Part 2: Running Regex On Moduls ' + CONVERT(VARCHAR(20),GETDATE(),120);
		PRINT 'Part 2: PopulateTable ' + CONVERT(VARCHAR(20),GETDATE(),120);
		EXEC Background.usp_INNER_PopulateTable @DataBaseName, @StartDate, @EndDate;
		PRINT 'Part 2: END PopulateTable ' + CONVERT(VARCHAR(20),GETDATE(),120);
		CREATE TABLE #Error (
			ID INT,
			Type VARCHAR(305),
			Massege VARCHAR(512),
			URL_Reference VARCHAR(512),
			IsCheckOnProcName BIT,
			Regex NVARCHAR(1000),
			SearchRegexMethodID INT,
			SeverityID INT,
			NotIn_RegexPettern NVARCHAR(1000)
		);
		PRINT 'Part 2: Insert #Error ' + CONVERT(VARCHAR(20),GETDATE(),120);
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
		PRINT 'Part 2: END Insert #Error ' + CONVERT(VARCHAR(20),GETDATE(),120);
		SET @sqlCmd = N'
;WITH ProcName AS (
	SELECT  E.ID,
			PP.FullObjectName [object_name] ,
			E.Type,
			SUBSTRING(PP.FullObjectName,CHARINDEX(''.'',PP.FullObjectName)+ 1,LEN(PP.FullObjectName)) RegexIsMatch,
			E.Massege,
			E.URL_Reference,
			E.SearchRegexMethodID,
			E.SeverityID
	FROM    Background.Inner_sql_modules PP
			CROSS JOIN #Error E
	WHERE   PP.type = ''P''
			AND E.IsCheckOnProcName = 1
), ProcDefinition AS (
	SELECT	E.ID,
			PP.FullObjectName [object_name],
			E.Type,
			[dbo].[ufn_Util_clr_RegexIsMatch] (PP.Definition,E.Regex,0) RegexIsMatch,
			E.Massege,
			E.URL_Reference,
			PP.[Definition],
			E.SearchRegexMethodID,
			E.SeverityID
	FROM	Background.Inner_sql_modules PP
			CROSS JOIN #Error E
	WHERE	PP.type = ''P''
			AND E.IsCheckOnProcName = 0
			AND E.NotIn_RegexPettern IS NULL
	UNION ALL /*Finding word in fraze that there is missing word in the sentace continuas*/
	SELECT	E.ID,
			PP.FullObjectName object_name,
			E.Type,
			CONVERT(BIT,CASE WHEN [dbo].[ufn_Util_clr_RegexIsMatch] (PP.Definition,E.Regex,0) = 1 THEN [dbo].[ufn_Util_clr_RegexIsMatch] (PP.Definition,E.NotIn_RegexPettern,0) ELSE 1 END) RegexIsMatch,
			E.Massege,
			E.URL_Reference,
			PP.[Definition],
			E.SearchRegexMethodID,
			E.SeverityID
	FROM	Background.Inner_sql_modules PP
			CROSS JOIN #Error E
	WHERE	PP.type = ''P''
			AND E.IsCheckOnProcName = 0
			AND E.NotIn_RegexPettern IS NOT NULL
), [Output] AS (
SELECT	ID,
		object_name,
		Type,
		/*--[Definition],*/
		Massege, /*,RegexReplace*/
		URL_Reference,
		SeverityID
FROM	ProcDefinition
WHERE	RegexIsMatch = 1
		AND SearchRegexMethodID = 1 /*Found In The Code*/
UNION ALL 
SELECT	ID,
		object_name,
		Type,
		/*--[Definition],*/
		Massege, /*,RegexReplace*/
		URL_Reference,
		SeverityID
FROM	ProcDefinition
WHERE	RegexIsMatch = 0
		AND SearchRegexMethodID = 2 /*Not Found In The Code*/
UNION ALL 
SELECT	ID ,
		object_name,
		Type ,
		/*--RegexIsMatch ,*/
		Massege,
		URL_Reference,
		SeverityID
FROM	ProcName
WHERE	RegexIsMatch = 1
)
INSERT	#Exeption
SELECT	/*--o.ID ,*/
		@DatabaseName,
		o.object_name ,
		o.Type,
		NULL, /*--ColumnName*/
		NULL, /*--ConstraintName*/
		o.Massege,
		o.URL_Reference,
		S.Name
FROM	[Output] o
		INNER JOIN [dbo].[App_Severity] S ON o.SeverityID = S.ID
		LEFT JOIN dbo.App_Exclusion E ON E.ErrorID = o.ID
					AND  E.object_name = O.object_name
WHERE	E.ID IS NULL;';

		BEGIN TRY
			PRINT 'Part 2: Run Regex Query' + CONVERT(VARCHAR(20),GETDATE(),120);
			PRINT @sqlCmd;      
			EXEC sp_executesql	@sqlCmd, 
								N'@DatabaseName SYSNAME,
								  @StartDate DATETIME,
								  @EndDate DATETIME
								', 
								@DatabaseName = @DatabaseName,
								@StartDate = @StartDate,
								@EndDate = @EndDate
		END TRY
		BEGIN CATCH
		 
			INSERT #Mng_ApplicationErrorLog
			SELECT ISNULL(ERROR_PROCEDURE(),'dbo.usp_App_RunCheck - Regex'),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		END CATCH
			PRINT 'Part 2: End Run Regex Query' + CONVERT(VARCHAR(20),GETDATE(),120);

		--Part 3: Error Handling
		IF EXISTS (SELECT TOP 1 1 FROM #Mng_ApplicationErrorLog)
			BEGIN
				INSERT	dbo.Mng_ApplicationErrorLog
				SELECT	ProcedureName ,
						ErrorMessage ,
						HostName ,
						LoginName ,
						GETDATE() ExecutionTime 
				FROM	#Mng_ApplicationErrorLog
				PRINT 'There is an Inner Errors. Check Mng_ApplicationErrorLog Table. - SELECT * FROM [dbo].[Mng_ApplicationErrorLog] WHERE CONVERT(DATE,GETDATE()) <ExecutionTime'
			END


			SELECT	* 
			FROM	#Exeption e
			ORDER BY e.Massege,e.ObjectName;

			
			IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL DROP TABLE #DBInfo;
			IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL DROP TABLE #Mng_ApplicationErrorLog
			IF OBJECT_ID('tempdb..#RunnableChecks') IS NOT NULL DROP TABLE #RunnableChecks
			IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL DROP TABLE #Exeption
			
	END TRY
	BEGIN CATCH
		IF EXISTS (SELECT TOP 1 1 FROM SYS.syscursors WHERE cursor_name = 'crExec')
  		BEGIN
  			CLOSE crExec
			DEALLOCATE crExec
  		END  

		IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL DROP TABLE #DBInfo;
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL DROP TABLE #Mng_ApplicationErrorLog
		IF OBJECT_ID('tempdb..#RunnableChecks') IS NOT NULL DROP TABLE #RunnableChecks
		IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL DROP TABLE #Exeption
		  
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT ERROR_PROCEDURE()ProcedureName,ERROR_MESSAGE()ErrorMessage, HOST_NAME()HostName,USER_NAME()LoginName,GETDATE()ExecutionTime
		
		DECLARE @msg NVARCHAR(1000) = ERROR_PROCEDURE() + ': Call your Database Administrator.'
		RAISERROR (@msg,16,1);
		RETURN;
	END CATCH

	TRUNCATE TABLE Background.Inner_sql_modules;

END