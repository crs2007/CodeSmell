-- =============================================
-- Author:		Sharon
-- Create date: 2021-11-28
-- Update date: 30/11/2021 adds condition AND ca3.Ver > 4
--				31/12/2021 adds AND OA.OldVersionCount > 0
-- Description:	Clean old versions of that stored procedure to be with orginized database.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DesignStandards_CleanOldVersionSPs]
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
			CONCAT(s.name, ''.'', o.name) ObjectName,
			''Design Standards'' Type,
			NULL ColumnName,
			NULL ConstraintName,
			REPLACE(@Message,''$OldVersionCount$'',OA.OldVersionCount) Message,
			@URL_Reference URL,
			@SeverityName Severity,
			@CheckID
	FROM    ' + @DBName + N'sys.procedures o
			INNER JOIN ' + @DBName + N'sys.schemas s ON s.schema_id = o.schema_id
			CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9][0-9]'', o.name), 0), 2)) ca1(Pat2, Chars)
			CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9]'', o.name), 0), 1)) ca2(Pat1, Chars)
			CROSS APPLY (VALUES(CONVERT(INT, ISNULL(SUBSTRING(o.name, ISNULL(ca1.Pat2, ca2.Pat1) + 2, IIF(ca1.Pat2 IS NOT NULL, ca1.Chars, ca2.Chars)), 0)))) ca3(Ver)
			CROSS APPLY (VALUES(ISNULL(SUBSTRING(o.name, 1, ISNULL(ca1.Pat2, ca2.Pat1) - 1), o.name))) ca4(SP)
			OUTER APPLY (SELECT COUNT(1) OldVersionCount
						FROM	' + @DBName + N'sys.procedures ino 
								INNER JOIN ' + @DBName + N'sys.schemas ins ON ins.schema_id = ino.schema_id 
								CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9][0-9]'', ino.name), 0), 2)) ica1(Pat2, Chars)
								CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9]'', ino.name), 0), 1)) ica2(Pat1, Chars)
								CROSS APPLY (VALUES(CONVERT(INT, ISNULL(SUBSTRING(ino.name, ISNULL(ica1.Pat2, ica2.Pat1) + 2, IIF(ica1.Pat2 IS NOT NULL, ica1.Chars, ica2.Chars)), 0)))) ica3(Ver)
								CROSS APPLY (VALUES(ISNULL(SUBSTRING(ino.name, 1, ISNULL(ica1.Pat2, ica2.Pat1) - 1), ino.name))) ica4(SP)
						WHERE	ins.schema_id = s.schema_id 
								AND ica3.Ver < (ca3.Ver - 3)
								AND ica4.SP = ca4.SP
						)OA
	WHERE	o.object_id = @ObjectID
			AND ca3.Ver > 4
			AND OA.OldVersionCount > 0;';
	
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