-- =============================================
-- Author:		Sharon
-- Create date: 05/07/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding Broken Dependencies.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_BrokenDependencies]
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
			SCH.name + ''.'' + OBJ.name ObjectName,
			''Dependencies - '' + CASE 
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsProcedure'') = 1 THEN ''Procedure''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsView'') = 1 THEN ''View''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsTable'') = 1 THEN ''Table''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsSystemTable'') = 1 THEN ''Table''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsScalarFunction'') = 1 THEN ''Function''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsTableFunction'') = 1 THEN ''Function''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsInlineFunction'') = 1 THEN ''Function''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsTrigger'') = 1 THEN ''Trigger''
WHEN OBJECTPROPERTY(DEP.referencing_id,''IsQueue'') = 1 THEN ''Queue''
ELSE ''ObjectDoesNotExists''
END [Type],
			NULL ColumnName,
			NULL ConstraintName,
			''ReferencedObjectName: '' + ISNULL(DEP.referenced_schema_name,''dbo'') + ''.'' + DEP.referenced_entity_name + '' '' +  @Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'sys.sql_expression_dependencies AS DEP
			INNER JOIN ' + @DBName + N'sys.objects AS OBJ ON DEP.referencing_id = OBJ.object_id
			INNER JOIN ' + @DBName + N'sys.schemas AS SCH ON OBJ.schema_id = SCH.schema_id
	WHERE	DEP.referenced_id IS NULL
			AND DEP.referenced_server_name IS NULL
			AND DEP.referenced_database_name IS NULL
			AND DEP.is_ambiguous = 0
			AND DEP.referenced_schema_name IS NOT NULL;';
	
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