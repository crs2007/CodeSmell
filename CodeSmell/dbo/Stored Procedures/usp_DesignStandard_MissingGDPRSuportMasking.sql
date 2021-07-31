-- =============================================
-- Author:		Sharon
-- Create date: 27/01/2020
-- Update date: 26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Missing GDPR Suport Masking
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_MissingGDPRSuportMasking]
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
	SELECT  @DBName = QUOTENAME(name) + N'.'
	FROM    sys.databases 
	WHERE	name = @DatabaseName;
	
	IF @@ROWCOUNT = 0 
	BEGIN
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),'You must enter valid local database name insted - ' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,HOST_NAME(),@LoginName,GETDATE(),@RunningID;  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(max) ;

	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			s.name + ''.'' + t.name ObjectName,
			''DesignStandard'' Type,
			c.name ColumnName,
			NULL ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName,
			@CheckID
	FROM	' + @DBName + N'sys.tables t
			INNER JOIN ' + @DBName + N'sys.schemas s ON s.schema_id = t.schema_id
			INNER JOIN ' + @DBName + N'sys.indexes i ON i.object_id = t.object_id
			LEFT JOIN ' + @DBName + N'sys.columns c ON c.object_id = t.object_id
	WHERE   c.is_masked = 0
			AND (
				c.name LIKE ''%Zip%''
				OR c.name LIKE ''%Email%'' 
				OR c.name LIKE ''%LastName%''
				OR c.name LIKE ''%Social%''
				OR c.name LIKE ''%PlaceOfBirth%''
				OR c.name LIKE ''%Address%''
				OR c.name LIKE ''%MaidenName%''
				OR c.name LIKE ''%PhoneNumber%''
				OR c.name LIKE ''%Mobile%''
				)
			AND t.object_id = @ObjectID;
			';
	
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Message NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT,
				@RunningID INT', 
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
END