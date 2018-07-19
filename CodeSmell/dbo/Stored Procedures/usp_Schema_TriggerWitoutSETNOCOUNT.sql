-- =============================================
-- Author:		Sharon
-- Create date: 10/06/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding a trigger that does not contain SET NOCOUNT ON 
--				(leaving it suspectible to "A trigger returned a resultset and/or was running with SET NOCOUNT OFF while another outstanding result set was active.").
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_TriggerWitoutSETNOCOUNT]
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

	SELECT	@sqlCmd = N'
	;WITH TrigerDef AS (
		SELECT	ISNULL(OBJECT_SCHEMA_NAME(tr.object_id,DB_ID(''' + @DatabaseName + N'''))+ N''.'',N'''')  + ISNULL(OBJECT_NAME(tr.parent_id,DB_ID(''' + @DatabaseName + N''')),N'''') TableName,
				tr.name COLLATE ' + dbo.Setup_GetGlobalParm (1) + ' AS TriggerName,
				[dbo].[ufn_Util_CLR_RegexReplace](sm.definition,''(--.*)|(((/\*)+?[\w\W]+?(\*/)+))'',N'''',0)  COLLATE ' + dbo.Setup_GetGlobalParm (1) + N' [Definition] 
		FROM	' + @DBName + N'sys.sql_modules sm
				INNER JOIN ' + @DBName + N'sys.triggers tr ON sm.object_id = tr.object_id
		WHERE	tr.parent_class_desc != ''DATABASE''
	)
	' + @prefix + N'
	SELECT	@DatabaseName DatabaseName,
			TD.TableName + '' - '' + TD.TriggerName ObjectName,
			''Trigger'' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName Severity' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + ' 
	FROM	TrigerDef TD
	WHERE	[dbo].[ufn_Util_clr_RegexIsMatch] (TD.Definition,''(SET\s*NOCOUNT\s*ON)'',0) = 0;';

	--PRINT @sqlCmd
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
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL
			INSERT #Mng_ApplicationErrorLog
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		ELSE
		BEGIN
			PRINT @sqlCmd;
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		END
		RETURN -1;
	END CATCH
END