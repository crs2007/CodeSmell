CREATE PROCEDURE [Background].[usp_INNER_PopulateTable]
	@I_DataBaseName		sysname,
	@I_StartDate		DATETIME,
	@I_EndDate			DATETIME,
	@I_ObjectName		sysname,
	@I_RunningID		INT
AS
------------------------------------------------------------------
-- Application Module:  Code Smell
-- Procedure Name:		Background.usp_INNER_PopulateTable
-- Created:				27/02/2014
-- Author:				sharonr
-- Description:			Populate Table Background.Inner_sql_modules
--			
-- Updates :
--	On: 20/12/2020 ; By: sharonr
--		adds ignore from single quotemark
--
--    On: 24/07/2021 ; By: sharonr
--        ALTER: Adds support at DefinitionWithStrings
--
-- Parameters: 
--
-- Recordsets: 
--
-- Errors: 
--
------------------------------------------------------------------
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;
	SET LOCK_TIMEOUT 2;
	SET DEADLOCK_PRIORITY -10;
	
	SET @I_ObjectName = REPLACE(REPLACE(@I_ObjectName,'[',''),']','')
	DECLARE @DBName NVARCHAR(129),
			@sqlCmd NVARCHAR(max) = N'' ,
			@prefix NVARCHAR(1000) = N'',  
			@Filter NVARCHAR(2000) = N'',
			@TableJoin NVARCHAR(2000) = N'',
			@ExecutionDate DATETIME = GETDATE(),
			@RegexRemark NVARCHAR(2000) = N'(--.*)|(((\/\*)[\w\W]*?(\*\/)))',
			@RegexText NVARCHAR(2000) = N'(((\''|N\'')[\w\W]*?(\'')))';
	
	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.'
	FROM    sys.databases WITH(NOLOCK)
	WHERE	name = @I_DataBaseName;
	
	
	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT 'You must enter valid local database name' + ISNULL(N' insted - ' + QUOTENAME(@I_DataBaseName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),USER_NAME(),@ExecutionDate,NULL;  
		RAISERROR ('You must enter valid local database name',16,1);
		RETURN -1;
	END

	SELECT	@Filter += CASE WHEN Filter != N'' THEN ' and (' + Filter + ')
	' ELSE '' END,
			@TableJoin += case when TableJoin !='' THEN TableJoin + '
			'ELSE ''end

	FROM 
	(
		SELECT N' o.modify_date >= @I_StartDate ' Filter, N'' TableJoin WHERE @I_StartDate IS NOT NULL
		UNION ALL SELECT N' o.modify_date <= @I_EndDate ', N'' WHERE @I_EndDate IS NOT NULL 
		UNION ALL SELECT N' o.name = @I_ObjectName ', N'' WHERE @I_ObjectName IS NOT NULL AND CHARINDEX('.',@I_ObjectName) = 0
		UNION ALL SELECT N' s.name + ''.'' + o.name = @I_ObjectName ', N'' WHERE @I_ObjectName IS NOT NULL AND CHARINDEX('.',@I_ObjectName) > 0
	)t

	--PureProc
	SET @sqlCmd = CONCAT('
INSERT	Background.Inner_sql_modules(FullObjectName, Definition, Type, Remarks, MainRunID, DefinitionWithStrings)
SELECT  s.name  + ''.'' + o.name  COLLATE ' + dbo.Setup_GetGlobalParm (1) + N' AS FullObjectName ,
		RTRIM(LTRIM(REPLACE(REPLACE(
			[dbo].[ufn_Util_CLR_RegexReplace](
				[dbo].[ufn_Util_CLR_RegexReplace](sm.definition,''',@RegexRemark,N''','''',0) 
				,''',REPLACE(@RegexText,'''',''''''),N''','''',0) COLLATE ' + dbo.Setup_GetGlobalParm (1) + N' 
			, CHAR(10), ''''), CHAR(13), '' ''))) [Definition],
		o.type,
		',IIF(@I_ObjectName IS NOT NULL,N'r.Remark',N'NULL') ,',
		@I_RunningID,
		RTRIM(LTRIM(REPLACE(REPLACE(
				[dbo].[ufn_Util_CLR_RegexReplace](sm.definition,''',@RegexRemark,N''','''',0) 
			, CHAR(10), ''''), CHAR(13), '' '')))
FROM    ',@DBName,N'sys.sql_modules AS sm
		INNER JOIN ',@DBName,N'sys.objects AS o ON sm.object_id = o.object_id
		INNER JOIN ',@DBName,N'sys.schemas s ON s.schema_id = o.schema_id
		',IIF(@I_ObjectName IS NOT NULL,N'
		CROSS APPLY (SELECT REPLACE(REPLACE(REPLACE(STUFF((SELECT '''' + MatchText FROM [dbo].[ufn_Util_clr_RegexMatch] (
					   sm.definition,''' + @RegexRemark + N''',0,'''') FOR XML PATH('''')),1,0,''''),''&#x0D;'',CHAR(13) + CHAR(10)),''&lt;'',''<''),''&gt;'',''>''))r(Remark)
',N''),N'
WHERE   o.type = ''P''
		AND o.name NOT IN (''sp_upgraddiagrams'',''sp_helpdiagrams'')
		',@Filter) ;
	--Delete Table Before Start
	--TRUNCATE TABLE Background.Inner_sql_modules;
	--RAISERROR (@sqlCmd, 10, 1) WITH NOWAIT;
	--PRINT 'Part 2: Populate Background.Inner_sql_modules' + CONVERT(VARCHAR(20),GETDATE(),120);
	EXEC sp_executesql	@sqlCmd, 
							N'@I_DataBaseName SYSNAME, @I_StartDate DATETIME, @I_EndDate DATETIME, @I_ObjectName sysname, @I_RunningID INT', 
							@I_DataBaseName = @I_DataBaseName,
							@I_StartDate = @I_StartDate,
							@I_EndDate = @I_EndDate,
							@I_ObjectName = @I_ObjectName,
							@I_RunningID = @I_RunningID;
END