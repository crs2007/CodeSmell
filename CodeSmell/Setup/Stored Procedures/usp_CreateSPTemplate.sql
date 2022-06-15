-- =============================================
-- Author:		Sharon
-- Create date: 13/07/2017
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
--				28/11/2021 Support @OnlyPrint
-- Description:	Create Stored Procedure Template 
-- =============================================
CREATE PROCEDURE [Setup].[usp_CreateSPTemplate]
	@Author sysname,
	@Description NVARCHAR(MAX),
	@Subject NVARCHAR(20),
	@Message varchar(1000),
	@URL_Reference varchar(512),
	@SubjectGroupID INT,
	@DBVersionID INT,
	@SeverityID INT,
	@Help BIT = 0,
	@OnlyPrint BIT = 1
AS
BEGIN
	SET NOCOUNT ON;
	EXEC sys.sp_set_session_context @key = N'IgnoreCodeSmell', @value = N'1';

	DECLARE @cmd NVARCHAR(MAX),
			@InitCmd NVARCHAR(MAX),
			@SubjectGroup NVARCHAR(25),
			@MaxID INT,
			@uspName sysname;

	IF @Help = 1
	BEGIN
	    SELECT 'SubjectGroup' [Table],* FROM dbo.App_SubjectGroup;
		SELECT 'DBVersion' [Table],* FROM dbo.App_DBVersion;
		SELECT 'Severity' [Table],* FROM dbo.App_Severity;
		RETURN;
	END

	SELECT	@SubjectGroup = [Subject]
	FROM	dbo.App_SubjectGroup
	WHERE	ID = @SubjectGroupID;
	SELECT @uspName = CONCAT(N'usp_',REPLACE(REPLACE(REPLACE(REPLACE(@SubjectGroup,' ',''),']',''),'[',''),CHAR(13),''),'_',REPLACE(REPLACE(REPLACE(REPLACE(@Subject,' ',''),']',''),'[',''),CHAR(13),''));
	SELECT @InitCmd = CONCAT('IF OBJECT_ID(''dbo.',@uspName,''') IS NULL
BEGIN
	EXEC (''CREATE PROCEDURE dbo.',@uspName,' AS'');
END')
	SELECT @cmd = CONCAT('
-- =============================================
-- Author:		',REPLACE(ISNULL(@Author,SUSER_NAME()),CHAR(13),''),'
-- Create date: ',CONVERT(VARCHAR(10),GETDATE(),121),'
-- Update date: 
-- Description:	',REPLACE(@Description,CHAR(13),' '),'.
-- =============================================
ALTER PROCEDURE [dbo].[',@uspName,']
	@DatabaseName sysname,
	@Message NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL,
	@LoginName sysname = NULL,
	@RunningID INT = NULL
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
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),''You must enter valid local database name insted - '' + ISNULL(N'' insted - '' + QUOTENAME(@DatabaseName),N'''') ,HOST_NAME(),@LoginName,GETDATE(),@RunningID;  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(max) ;

	SELECT	@sqlCmd = N''INSERT ['' + DB_NAME() + ''].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			NULL ObjectName,
			''''',@SubjectGroup,''''' Type,
			NULL ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    '' + @DBName + N''sys.schemas;'';
	
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N''@DatabaseName sysname,
				@Message NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT,
				@RunningID INT'', 
				@DatabaseName = @DatabaseName,
				@Message = @Message,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@ObjectID = @ObjectID,
				@CheckID = @CheckID,
				@RunningID = @RunningID;
	END TRY
	BEGIN CATCH
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),@LoginName,GETDATE(),@RunningID; 
		RETURN -1;
	END CATCH
END');

	IF OBJECT_ID(@uspName) IS NULL
	BEGIN
		BEGIN TRY
			IF @OnlyPrint = 1
			BEGIN
			    SELECT @InitCmd = CONCAT('USE ',QUOTENAME(DB_NAME()),';
GO
',@InitCmd,'
GO');
				PRINT @InitCmd;
				PRINT @cmd;
				PRINT 'GO';
			END
			ELSE
			BEGIN
				EXECUTE sys.sp_executesql @InitCmd;
			    EXECUTE sys.sp_executesql @cmd;
			END
			
		
			SELECT TOP (1) @MaxID =  ID + 1 FROM dbo.App_GeneralCheck ORDER BY ID DESC;
			IF @OnlyPrint = 1
			BEGIN
			    SELECT @cmd = CONCAT('INSERT dbo.App_GeneralCheck (ID,Name,Message, IsActive,URL_Reference,SubjectGroupID,DBVersionID,SeverityID,IsOnSingleObject,IsOnSingleObjectOnly,IsPhysicalObject)
SELECT	',@MaxID,',''',CONCAT('dbo.',@uspName),''',''',@Message,''',1,',IIF(@URL_Reference IS NULL,'NULL','' + @URL_Reference + ''),', ',@SubjectGroupID,', ',@DBVersionID,', ',@SeverityID,',1,0,0
WHERE	NOT EXISTS (SELECT TOP (1) 1 FROM dbo.App_GeneralCheck WHERE Name = ''',CONCAT('dbo.',@uspName),''');
GO');
				PRINT @cmd;
			END
			ELSE
            BEGIN
				INSERT dbo.App_GeneralCheck (ID,Name,Message,
													IsActive,
													URL_Reference,
													SubjectGroupID,
													DBVersionID,
													SeverityID,
													IsOnSingleObject,
													IsOnSingleObjectOnly,
													IsPhysicalObject)
				SELECT	@MaxID,
						CONCAT('dbo.',@uspName),
						@Message,1,	
						@URL_Reference ,
						@SubjectGroupID,
						@DBVersionID,
						@SeverityID,
						1,0,0
				WHERE	NOT EXISTS (SELECT TOP (1) 1 FROM dbo.App_GeneralCheck WHERE Name = CONCAT('dbo.',@uspName));
            END

		END TRY
		BEGIN CATCH
			PRINT @cmd;
			THROW;
		END CATCH
	
	END
END