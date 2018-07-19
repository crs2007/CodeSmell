-- =============================================
-- Author:		Sharon
-- Create date: 22/12/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Invalid FK Name
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_InvalidFKName]
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
			OBJECT_SCHEMA_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + OBJECT_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) ObjectName,
			''DesignStandard'' Type,
			c.NAME ColumnName,
			fk.name + '' - Current FK Name'' ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
			-- CASE WHEN CHARINDEX(''_'', c.NAME) = 0
   --          THEN ''FK_'' + OBJECT_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_'' + OBJECT_NAME(fk.referenced_object_id,DB_ID(''' + @DatabaseName + '''))
   --          ELSE ''FK_'' + OBJECT_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_'' OBJECT_NAME(fk.referenced_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_''
   --               + REPLACE(c.NAME,
   --                         REVERSE(SUBSTRING(REVERSE(c.NAME), 1,
   --                                           CHARINDEX(''_'', REVERSE(c.NAME)))),
   --                         '')
			--END + '' - Required FK Name'' Script
	FROM	' + @DBName + N'sys.foreign_keys fk
			INNER JOIN ' + @DBName + N'sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
			INNER JOIN ' + @DBName + N'sys.columns c ON fkc.parent_object_id = c.object_id
										AND fkc.parent_column_id = c.column_id
	WHERE   ( ( CHARINDEX(''_'', c.NAME) = 0
				AND fk.name <> ''FK_'' + OBJECT_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_''
				+ OBJECT_NAME(fk.referenced_object_id,DB_ID(''' + @DatabaseName + '''))
			  )
			  OR ( CHARINDEX(''_'', c.NAME) > 0
				   AND fk.name <> ''FK_'' + OBJECT_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_''
				   + OBJECT_NAME(fk.referenced_object_id,DB_ID(''' + @DatabaseName + ''')) + ''_'' + REPLACE(c.NAME,
																  REVERSE(SUBSTRING(REVERSE(c.NAME),
																  1,
																  CHARINDEX(''_'',
																  REVERSE(c.NAME)))),'''')
				 )
			)
			AND c.NAME NOT IN (''UpdateUserID'',''UpdateCustomerID'',''CreateCustomerID'',''CreateUserID'',''CreateSiteID'',''UpdateSiteID'' )
			AND fk.name NOT IN (
								''FK_UserMng_OrganizationUnit_UserMng_OrganizationUnit_BaseID'',
								''FK_CargoControl_EntryExitCargoMovement_Sites_Site_Create'',
								''FK_CargoControl_EntryExitCargoMovement_Sites_Site_Update'',
								''FK_Storage_StorageMessage_Sites_Site_Create'',
								''FK_Storage_StorageMessage_Sites_Site_Update'',
								''FK_Storage_UnusualEventMessage_Sites_Site_Create'',
								''FK_Storage_UnusualEventMessage_Sites_Site_Update'',
								''FK_RiskMng_RiskFactorCondition_DataDic_c_Field1'',
								''FK_RiskMng_RiskFactorCondition_DataDic_c_Field2'',
								''FK_RiskMng_RiskFactorCondition_DataDic_Relationship1'',
								''FK_RiskMng_RiskFactorCondition_DataDic_Relationship2'',
								''FK_Deficit_DeficitFile_Sites_Site_Create'',
								''FK_Deficit_DeficitFile_Sites_Site_Update'' 
								)
			AND OBJECT_SCHEMA_NAME(fk.object_id,DB_ID(''' + @DatabaseName + ''')) NOT IN (''Actimize'');
			';
	
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