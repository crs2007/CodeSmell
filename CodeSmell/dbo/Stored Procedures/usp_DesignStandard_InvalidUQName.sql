-- =============================================
-- Author:		Sharon
-- Create date: 22/12/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Invalid UQ Name
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_InvalidUQName]
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

	SELECT	@sqlCmd = @prefix + N'
	SELECT	@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(kc.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + OBJECT_NAME(kc.parent_object_id,DB_ID(''' + @DatabaseName + ''')) ObjectName,
			''DesignStandard'' Type,
			NULL ColumnName,
			kc.name + '' - Current UQ Name'' ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + ' Severity
			-- ''UQ_'' + OBJECT_NAME(kc.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_#ColumnName# - Required UQ Name'' Script
	FROM	' + @DBName + N'sys.key_constraints kc
			INNER JOIN ' + @DBName + N'sys.objects O ON O.object_id = kc.parent_object_id
	WHERE   kc.name NOT LIKE ''UQ_'' + OBJECT_NAME(kc.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''%''
			AND kc.type_desc = ''UNIQUE_CONSTRAINT''
			AND OBJECT_SCHEMA_NAME(kc.parent_object_id,DB_ID(''' + @DatabaseName + ''')) <> ''cdc''
			AND OBJECT_NAME(kc.parent_object_id,DB_ID(''' + @DatabaseName + ''')) NOT IN ( ''systranschemas'',''sysdiagrams'')
			AND o.type != ''TT''  -- Table Type;';
	
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