-- =============================================
-- Author:		Sharon
-- Create date: 16/100/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Find not trusted constreints
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_NotTrustedConstreints]
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
	SELECT  @DatabaseName DatabaseName,
			S.name + ''.'' + O.name ObjectName,
			I.type_desc Type,
			NULL ColumnName,
			I.Name ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'sys.foreign_keys i
			INNER JOIN ' + @DBName + N'sys.objects o ON i.parent_object_id = o.object_id
			INNER JOIN ' + @DBName + N'sys.schemas s ON o.schema_id = s.schema_id
	WHERE   i.is_not_trusted = 1
			AND i.is_not_for_replication = 0
			AND i.is_disabled = 0
	UNION ALL 
	SELECT  @DatabaseName DatabaseName,
			S.name + ''.'' + O.name ObjectName,
			I.type_desc Type,
			NULL ColumnName,
			I.Name ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'SYS.check_constraints i
			INNER JOIN ' + @DBName + N'sys.objects o ON i.parent_object_id = o.object_id
			INNER JOIN ' + @DBName + N'sys.schemas s ON I.schema_id = s.schema_id
	WHERE   i.is_not_trusted = 1
			AND i.is_not_for_replication = 0
			AND i.is_disabled = 0;';
	
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