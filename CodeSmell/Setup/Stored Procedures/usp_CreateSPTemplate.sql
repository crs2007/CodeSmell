-- =============================================
-- Author:		Sharon
-- Create date: 13/07/2017
-- Description:	
-- =============================================
CREATE PROCEDURE Setup.usp_CreateSPTemplate 
	@Author sysname,
	@Description NVARCHAR(MAX),
	@SubjectGroup NVARCHAR(10),
	@Subject NVARCHAR(20),
	@Massege varchar(1000),
	@URL_Reference varchar(512),
	@SubjectGroupID INT,
	@DBVersionID INT,
	@SeverityID INT,
	@Help BIT = 0
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cmd NVARCHAR(MAX);

	IF @Help = 1
	BEGIN
	    SELECT 'SubjectGroup' [Table],* FROM dbo.App_SubjectGroup;
		SELECT 'DBVersion' [Table],* FROM dbo.App_DBVersion;
		SELECT 'Severity' [Table],* FROM dbo.App_Severity;
		RETURN;
	END


	SELECT @cmd = CONCAT('
-- =============================================
-- Author:		',REPLACE(@Author,CHAR(13),''),'
-- Create date: ',CONVERT(VARCHAR(10),GETDATE()),'
-- Update date: 
-- Description:	',REPLACE(@Description,CHAR(13),' '),'.
-- =============================================
CREATE PROCEDURE [dbo].[usp_',REPLACE(REPLACE(REPLACE(@SubjectGroup,']',''),'[',''),CHAR(13),''),'_',REPLACE(REPLACE(REPLACE(@Subject,']',''),'[',''),CHAR(13),''),']
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
	SELECT  @DBName = QUOTENAME(name) + N''.''
	FROM    sys.databases 
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		IF OBJECT_ID(''tempdb..#Mng_ApplicationErrorLog'') IS NOT NULL  
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),''You must enter valid local database name insted - '' + ISNULL(N'' insted - '' + QUOTENAME(@DatabaseName),N'''') ,HOST_NAME(),USER_NAME();  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(MAX) ,
			@prefix NVARCHAR(1000) = N'''';

	IF OBJECT_ID(''tempdb..#Exeption'') IS NOT NULL SET @prefix = N''
	INSERT	#Exeption'';

	SELECT	@sqlCmd = @prefix + N''
	SELECT	@DatabaseName DatabaseName,
			NULL ObjectName,
			''''',@SubjectGroup,''''' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName'' + CASE WHEN @CheckID IS NOT NULL THEN '',@CheckID'' ELSE N'''' END + ''
	FROM    '' + @DBName + N''sys.schemas;
	
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N''@DatabaseName sysname,
				@Massege NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT'', 
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
END');
	DECLARE @MaxID INT;
	BEGIN TRY
		EXEC sys.sp_executesql @cmd;

		
		SELECT TOP (1) @MaxID =  ID + 1 FROM dbo.App_GeneralCheck ORDER BY ID DESC;

		INSERT dbo.App_GeneralCheck (ID,Name,Massege,
											IsActive,
											URL_Reference,
											SubjectGroupID,
											DBVersionID,
											SeverityID,
											IsOnSingleObject)
		VALUES (@MaxID,		-- ID - int
				CONCAT('dbo.usp_',REPLACE(REPLACE(REPLACE(@SubjectGroup,']',''),'[',''),CHAR(13),''),'_',REPLACE(REPLACE(REPLACE(@Subject,']',''),'[',''),CHAR(13),'')),	-- Name - nvarchar(255)
				@Massege,1,	-- IsActive - bit
				@URL_Reference ,		-- URL_Reference - varchar(512)
				@SubjectGroup,		-- SubjectGroupID - int
				@DBVersionID,		-- DBVersionID - int
				@SeverityID,		-- SeverityID - int
				0	-- IsOnSingleObject - bit
			);

	END TRY
	BEGIN CATCH
		THROW;
	END CATCH
	
	
END