-- =============================================
-- Author:		Sharon
-- Create date: 22/12/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Invalid FK Name
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandard_InvalidFKName]
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
	DECLARE @sqlCmd NVARCHAR(MAX) ;

	SELECT	@sqlCmd = N'INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
	SELECT	DISTINCT @RunningID,
			@DatabaseName DatabaseName,
			OBJECT_SCHEMA_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) + ''.'' + OBJECT_NAME(fk.parent_object_id,DB_ID(''' + @DatabaseName + ''')) ObjectName,
			''DesignStandard'' Type,
			c.NAME ColumnName,
			fk.name + '' - Current FK Name'' ConstraintName,
			@Message Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
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
			);
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