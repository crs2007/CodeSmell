-- =============================================
-- Author:		sharonr
-- Create date: 24/07/2021
-- Update date: 26/07/2021 @LoginName sysname = NULL,@RunningID INT = NULL. Remove Temp tables
-- Description:	Find Previous Modifications.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_FindPreviousModifications]
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
	DECLARE @sqlCmd NVARCHAR(MAX);
	IF @LoginName IS NULL SELECT @LoginName = SUSER_NAME();

	SELECT	@sqlCmd =  N';WITH base_ObjectName AS (
	SELECT	TOP (1) S.name + ''.'' + ISNULL(SUBSTRING(O.name, 1, ISNULL(NULLIF(PATINDEX(''%_V[0-9][0-9]'', O.name), 0), NULLIF(PATINDEX(''%_V[0-9]'', O.name), 0)) - 1), O.name) base_ObjectName
	FROM	' + @DBName + N'sys.objects O 
			INNER JOIN ' + @DBName + N'sys.schemas S ON S.schema_id = O.schema_id
	WHERE	O.object_id = @ObjectID
	), cte AS (
		SELECT ROW_NUMBER() OVER (PARTITION BY mr.ObjectName ORDER BY mr.ExecuteDate DESC ) AS RowNumber
				, mr.ExecuteDate
				, mr.UserName
				, mr.ObjectName
		FROM ' + DB_NAME() + N'.History.App_MainRun mr
			CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9][0-9]'', ObjectName), 0), 2)) ca1(Pat2, Chars)
			CROSS APPLY (VALUES(NULLIF(PATINDEX(''%_V[0-9]'', ObjectName), 0), 1)) ca2(Pat1, Chars)
			CROSS APPLY (VALUES(ISNULL(SUBSTRING(ObjectName, 1, ISNULL(ca1.Pat2, ca2.Pat1) - 1), ObjectName))) ca3(SP)
		WHERE ca3.SP = (SELECT TOP (1) b.base_ObjectName COLLATE ' + dbo.Setup_GetGlobalParm (1) + N' FROM base_ObjectName b)
				AND mr.UserName != @LoginName
				AND mr.ExecuteDate > DATEADD(DAY,-30,GETDATE())
				AND mr.DatabaseName = @DatabaseName
				AND mr.ID != @RunningID
	)
	INSERT [' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, Message, Severity, ErrorID)
	SELECT	@RunningID,
			@DatabaseName DatabaseName,
			c.ObjectName,
			''Procedure'' Type,
			REPLACE(REPLACE(REPLACE(@Message,''$ObjectName$'',c.ObjectName),''$ExecuteDate$'',CONVERT(NVARCHAR(23),c.ExecuteDate , 121)),''$UserName$'',c.UserName) AS Message,
			@SeverityName,
			@CheckID
	FROM	cte c
	WHERE	c.RowNumber = 1;';

	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Message NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT,
				@RunningID INT,
				@LoginName sysname', 
				@DatabaseName = @DatabaseName,
				@Message = @Message,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@ObjectID = @ObjectID,
				@CheckID = @CheckID,
				@RunningID = @RunningID,
				@LoginName = @LoginName;
	END TRY
	BEGIN CATCH
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),@LoginName,GETDATE(),@RunningID; 
		RETURN -1;
	END CATCH
END