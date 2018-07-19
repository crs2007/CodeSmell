-- =============================================
-- Author:		Sharon
-- Create date: 12/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding Unused SP when SQL Server is up at list for capel of days.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_UnusedSP]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL
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
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),'You must enter valid local database name insted - ' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,HOST_NAME(),USER_NAME();  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(max) ,
			@prefix NVARCHAR(1000) = N'';

	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL SET @prefix = N'
	INSERT	#Exeption';
	--
	SELECT	@sqlCmd = @prefix + N'
	SELECT	@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(p.object_id,DB_ID(''' + @DatabaseName + N''')) + ''.'' + p.name ObjectName,
			''Procedure'' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM	' + @DBName + N'sys.procedures p
			INNER JOIN ' + @DBName + N'SYS.sql_modules M ON M.object_id = p.object_id
			LEFT JOIN	(
						SELECT  st.objectid
						FROM    sys.dm_exec_cached_plans cp
								CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
						WHERE   st.dbid = DB_ID(''' + @DBName + N''')
								AND cp.objtype = ''proc''
						) t ON t.objectid = p.object_id
	WHERE	T.objectid IS NULL
			AND M.is_recompiled = 0
			AND EXISTS 	(SELECT TOP 1 1 FROM sys.dm_os_sys_info SI WHERE sqlserver_start_time > DATEADD(DAY,CONVERT(INT,' + dbo.Setup_GetGlobalParm (2) + N'),GETDATE()))
			AND P.Name NOT IN (''sp_alterdiagram'',''sp_creatediagram'',''sp_dropdiagram'',''sp_helpdiagramdefinition'',''sp_helpdiagrams'',''sp_renamediagram'',''sp_upgraddiagrams'')
			' + CASE WHEN @ObjectID IS NOT NULL THEN 'AND @ObjectID = P.OBJECT_ID' ELSE '' END 

	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Massege NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT', 
				@DatabaseName = @DatabaseName,
				@Massege = @Massege,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@ObjectID = @ObjectID,
				@CheckID = @CheckID;
	END TRY
	BEGIN CATCH
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		RETURN -1;
	END CATCH
END