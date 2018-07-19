-- =============================================
-- Author:		Sharon
-- Create date: 27/02/2014
-- Update date: 
-- Description:	Populate Table
-- =============================================
CREATE PROCEDURE [Background].[usp_INNER_PopulateTable]
	@DataBaseName sysname,
	@StartDate DATETIME,
	@EndDate DATETIME,
	@ObjectName sysname
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET @ObjectName = REPLACE(REPLACE(@ObjectName,'[',''),']','')
	DECLARE @DBName NVARCHAR(129),
			@sqlCmd NVARCHAR(max) = N'' ,
			@prefix NVARCHAR(1000) = N'',  
			@Filter NVARCHAR(2000) = N'',
			@TableJoin NVARCHAR(2000) = N'',
			@ExecutionDate DATETIME = GETDATE();
	
	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.'
	FROM    sys.databases WITH(NOLOCK)
	WHERE	name = @DatabaseName;
	
	
	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog
		SELECT 'You must enter valid local database name' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,OBJECT_NAME(@@PROCID),HOST_NAME(),USER_NAME(),@ExecutionDate,NULL;  
		RAISERROR ('You must enter valid local database name',16,1);
		RETURN -1;
	END

	SELECT	@Filter += CASE WHEN Filter != N'' THEN ' and (' + Filter + ')
	' ELSE '' END,
			@TableJoin += case when TableJoin !='' THEN TableJoin + '
			'ELSE ''end

	FROM 
	(
		SELECT N' o.modify_date >= @StartDate ' Filter, N'' TableJoin WHERE @StartDate IS NOT NULL
		UNION ALL SELECT N' o.modify_date <= @EndDate ', N'' WHERE @EndDate IS NOT NULL 
		UNION ALL SELECT N' o.name = @ObjectName ', N'' WHERE @ObjectName IS NOT NULL AND CHARINDEX('.',@ObjectName) = 0
		UNION ALL SELECT N' s.name + ''.'' + o.name = @ObjectName ', N'' WHERE @ObjectName IS NOT NULL AND CHARINDEX('.',@ObjectName) > 0
	)t

	--PureProc
	SET @sqlCmd = '
		INSERT	Background.Inner_sql_modules
		SELECT  OBJECT_SCHEMA_NAME(o.object_id,DB_ID(@DatabaseName))  + ''.'' + o.name  COLLATE ' + dbo.Setup_GetGlobalParm (1) + N' AS FullObjectName ,
				RTRIM(LTRIM(REPLACE(REPLACE(
				[dbo].[ufn_Util_CLR_RegexReplace](sm.definition,''(--.*)|(((/\*)+?[\w\W]+?(\*/)+))'','''',0)  COLLATE ' + dbo.Setup_GetGlobalParm (1) + N' 
				, CHAR(10), ''''), CHAR(13), '' ''))) [Definition],
				o.type
		FROM    ' + @DBName + N'sys.sql_modules AS sm
				INNER JOIN ' + @DBName + N'sys.objects AS o ON sm.object_id = o.object_id
				INNER JOIN ' + @DBName + 'sys.schemas s ON s.schema_id = o.schema_id
		WHERE   o.type = ''P''
				AND o.name NOT IN (''sp_upgraddiagrams'',''sp_helpdiagrams'')
				' + @Filter ;
	--Delect Table Before Start
	TRUNCATE TABLE Background.Inner_sql_modules;

	--PRINT 'Part 2: Populate Background.Inner_sql_modules' + CONVERT(VARCHAR(20),GETDATE(),120);
	EXEC sp_executesql	@sqlCmd, 
							N'@DatabaseName SYSNAME,
								@StartDate DATETIME,
								@EndDate DATETIME,
								@ObjectName sysname
							', 
							@DatabaseName = @DatabaseName,
							@StartDate = @StartDate,
							@EndDate = @EndDate,
							@ObjectName = @ObjectName;

END