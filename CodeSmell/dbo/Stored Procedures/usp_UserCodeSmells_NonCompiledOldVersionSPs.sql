-- =============================================
-- Author:		Sharon
-- Create date: 08/05/2022
-- Update date: 
-- Description:	Finding a Old SP Versions Non-Compiling Object.
-- =============================================
CREATE PROCEDURE dbo.usp_UserCodeSmells_NonCompiledOldVersionSPs
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
	DECLARE @sqlCmd NVARCHAR(max);
	CREATE TABLE #DBObj(ObjectName NVARCHAR(512) NOT NULL,type_desc sysname NOT NULL);
	DECLARE @DBObj TABLE (ObjectName NVARCHAR(512) NOT NULL,type_desc sysname NOT NULL);
	DECLARE @Name NVARCHAR(1000);
	DECLARE @Sqltype sysname;
	DECLARE @Result INT;
	DECLARE @TC INT;
	SELECT	@sqlCmd = N'INSERT #DBObj(ObjectName,type_desc)
	SELECT	OA.ObjectName,''p''
	FROM    ' + @DBName + N'sys.procedures o
			INNER JOIN ' + @DBName + N'sys.schemas s ON s.schema_id = o.schema_id
			CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9][0-9]'', o.name), 0), 2)) ca1(Pat2, Chars)
			CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9]'', o.name), 0), 1)) ca2(Pat1, Chars)
			CROSS APPLY (VALUES(CONVERT(INT, ISNULL(SUBSTRING(o.name, ISNULL(ca1.Pat2, ca2.Pat1) + 2, IIF(ca1.Pat2 IS NOT NULL, ca1.Chars, ca2.Chars)), 0)))) ca3(Ver)
			CROSS APPLY (VALUES(ISNULL(SUBSTRING(o.name, 1, ISNULL(ca1.Pat2, ca2.Pat1) - 1), o.name))) ca4(SP)
			OUTER APPLY (SELECT CONCAT(ins.name, ''.'', ino.name) ObjectName
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
			AND ca3.Ver > 4;';
	
	--SELECT 'dbo.usp_UserCodeSmells_NonCompiledOldVersionSPs' [#Debug], @ObjectID [@ObjectID]
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@ObjectID INT', 
				@DatabaseName = @DatabaseName,
				@ObjectID = @ObjectID;
	END TRY
	BEGIN CATCH
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),@LoginName,GETDATE(),@RunningID; 
		RETURN -1;
	END CATCH
	INSERT @DBObj(ObjectName, type_desc)
	SELECT ObjectName, type_desc FROM #DBObj;
	DROP TABLE #DBObj;
	BEGIN TRY
		
		DECLARE ObjectCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT	ObjectName, type_desc
		FROM	@DBObj;

		OPEN ObjectCursor;

		FETCH NEXT FROM ObjectCursor INTO @Name,@Sqltype;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @sqlCmd = N'USE [' + @DatabaseName + '];
EXEC sp_refreshsqlmodule ''' + @Name + ''';';
			--PRINT @sqlCmd;

			BEGIN TRY
				SET @TC = @@TRANCOUNT;
				EXEC @Result = sp_executesql @sqlCmd;
				IF @Result <> 0
					RAISERROR('Failed', 11, 1);
			END TRY
			BEGIN CATCH
				IF @TC > 0 BEGIN TRANSACTION;
				INSERT dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
				SELECT	@RunningID,
						@DatabaseName DatabaseName,
						@Name ObjectName,
						@Sqltype Type,
						NULL ColumnName,
						CONCAT('IF OBJECT_ID(''',@Name,''') IS NOT NULL
BEGIN
	EXEC(''ALTER SCHEMA [CanDel] TRANSFER ',@Name,';'');
END') ConstraintName,
						@Message Message,
						@URL_Reference URL,
						@SeverityName Severity,
						@CheckID;
			END CATCH;

			FETCH NEXT FROM ObjectCursor INTO @Name,@Sqltype;
		END;

		CLOSE ObjectCursor;
		DEALLOCATE ObjectCursor;
	END TRY
	BEGIN CATCH
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),@LoginName,GETDATE(),@RunningID; 
		RETURN -1;
	END CATCH
END