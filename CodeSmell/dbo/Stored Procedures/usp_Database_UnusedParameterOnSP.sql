-- =============================================
-- Author:		Sharon
-- Create date: 12/06/2013
-- Update date: 2014/02/26 ,By Sean Smith  http://www.sqlservercentral.com/scripts/unused/95259/
--				24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
--				26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Finding Unused parameter on SP.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_UnusedParameterOnSP]
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
		OBJECT_SCHEMA_NAME(O.object_id,DB_ID(''' + @DatabaseName + N''')) + ''.'' + O.name ObjectName,
		''Procedure'' Type,
		P.name + '' ('' + T.Name + '')'' ColumnName,
		''Output = '' + CASE P.is_output WHEN 1 THEN ''Yes'' ELSE ''No'' END ConstraintName,
		@Message Message,
		@URL_Reference URL,
		@SeverityName Severity,
		@CheckID
FROM	' + @DBName + N'sys.parameters P
		INNER JOIN ' + @DBName + N'sys.objects O ON O.[object_id] = P.[object_id]
		INNER JOIN ' + @DBName + N'sys.sql_modules SQLM ON SQLM.[object_id] = P.[object_id]
		INNER JOIN ' + @DBName + N'sys.types t ON P.system_type_id = T.system_type_id
		LEFT JOIN ( SELECT	XP.[object_id],XP.parameter_id,XP.name + NCHAR (13) AS parameter_name_modified
							,REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (
								XSQLM.[definition] + NCHAR (13)
									, XP.name + N''	'', XP.name + NCHAR (13))
									, XP.name + N'' '', XP.name + NCHAR (13))
									, XP.name + N''!'', XP.name + NCHAR (13))
									, XP.name + N''"'', XP.name + NCHAR (13))
									, XP.name + N''%'', XP.name + NCHAR (13))
									, XP.name + N''&'', XP.name + NCHAR (13))
									, XP.name + N'''''''', XP.name + NCHAR (13))
									, XP.name + N''('', XP.name + NCHAR (13))
									, XP.name + N'')'', XP.name + NCHAR (13))
									, XP.name + N''*'', XP.name + NCHAR (13))
									, XP.name + N''+'', XP.name + NCHAR (13))
									, XP.name + N'','', XP.name + NCHAR (13))
									, XP.name + N''-'', XP.name + NCHAR (13))
									, XP.name + N''.'', XP.name + NCHAR (13))
									, XP.name + N''/'', XP.name + NCHAR (13))
									, XP.name + N'';'', XP.name + NCHAR (13))
									, XP.name + N''<'', XP.name + NCHAR (13))
									, XP.name + N''='', XP.name + NCHAR (13))
									, XP.name + N''>'', XP.name + NCHAR (13))
									, XP.name + N''['', XP.name + NCHAR (13))
									, XP.name + N'']'', XP.name + NCHAR (13))
								AS definition_modified
					FROM	' + @DBName + N'sys.parameters XP
							INNER JOIN ' + @DBName + N'sys.sql_modules XSQLM ON XSQLM.[object_id] = XP.[object_id]
					WHERE	EXISTS ( SELECT	TOP 1 1
									FROM	' + @DBName + N'sys.parameters YP
									WHERE	YP.[object_id] = XP.[object_id]
											AND YP.parameter_id <> XP.parameter_id
											AND LEFT (YP.name, LEN (XP.name)) = XP.name
							
						)
			) FN ON FN.[object_id] = P.[object_id] AND FN.parameter_id = P.parameter_id
		CROSS APPLY ( SELECT ISNULL (FN.parameter_name_modified, P.name) AS parameter_name_compare ,ISNULL (FN.definition_modified, SQLM.[definition]) AS definition_compare) CV
WHERE	P.parameter_id <> 0
		AND O.is_ms_shipped = 0
		AND CHARINDEX (CV.parameter_name_compare, CV.definition_compare, CHARINDEX (CV.parameter_name_compare, CV.definition_compare) + 1) = 0
		' + CASE WHEN @ObjectID IS NOT NULL THEN  'AND @ObjectID = O.Object_ID' ELSE '' END + '
ORDER BY	O.[schema_id],O.name,P.name;';

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