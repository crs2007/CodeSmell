-- =============================================
-- Author:		Sharon
-- Create date: 18/02/2014
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Finding Default - Constraint That Not Relevant.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_DefaultConstraintThatNotRelevant]
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
			OBJECT_SCHEMA_NAME(o.object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + o.name ObjectName,
			''Default Constraint'' Type,
			C.NAME ColumnName,
			df.name  AS ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM	' + @DBName + N'sys.default_constraints df
			INNER JOIN ' + @DBName + N'sys.objects o ON df.parent_object_id = o.object_id
			INNER JOIN ' + @DBName + N'sys.columns c ON df.parent_column_id = c.column_id
				AND c.object_id = o.object_id
	WHERE	c.is_nullable = 1
		AND o.name NOT IN (''MSpeer_lsns''
							,''MSpeer_topologyrequest''
							,''MSpeer_request''
							,''sysarticlecolumns''
							,''syspublications''
							,''syspublications''
							,''MSpeer_conflictdetectionconfigresponse''
							)
	ORDER BY OBJECT_SCHEMA_NAME(o.object_id);';
	
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