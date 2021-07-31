-- =============================================
-- Author:		Sharon
-- Create date: 27/12/2018
-- Update Date: 05/07/2021 Update the logic
-- Description:	usp_CreateServerTrigger
-- =============================================
CREATE PROCEDURE Setup.usp_CreateServerTrigger
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @cmd NVARCHAR(MAX),
			@Print NVARCHAR(2048),
			@TriggerName sysname = N'str_CodeSmell_ObjectChange';
	IF EXISTS ( SELECT	TOP (1) 1
	FROM	master.sys.server_triggers
	WHERE	name = @TriggerName
	)
	BEGIN
		SELECT @cmd = 'DROP TRIGGER [' + @TriggerName + '] ON ALL SERVER;';
	    EXEC sys.sp_executesql @cmd;
	END

	SELECT @cmd = CONCAT('CREATE TRIGGER ',QUOTENAME(@TriggerName),' 	
	ON ALL SERVER FOR CREATE_PROCEDURE, ALTER_PROCEDURE, CREATE_TRIGGER, ALTER_TRIGGER, CREATE_FUNCTION, ALTER_FUNCTION
---------------------------------------------------------------------------------------
-- #####					DEV ONLY!!!											#### --
---------------------------------------------------------------------------------------
-- Application Module:	CodeSmell
-- Procedure Name:		',@TriggerName,'
-- Create date:			',CONVERT(VARCHAR(25),GETDATE(),121),'
-- Author:				sharonr
-- Description:			this trigger will raise alerts for changes in marked objects
--
-- Updates :
--	On: 07/07/2020; By: sharonr
--			Adds support with @LoginName
--
--	On: 13/08/2020	By: sharonr
--		Added suport of get outpot to PARSI via SQLCMD
--		New output parameter @O_SQLCMDError
--
--	On: 02/07/2021	By: sharonr
--		Added @I_EventType to activate test only on specific event
--
---------------------------------------------------------------------------------------
-- #####					DEV ONLY!!!											#### --
---------------------------------------------------------------------------------------
AS
BEGIN
	SET NOCOUNT ON;
	SET ANSI_WARNINGS ON;
	SET XACT_ABORT ON;
	IF SESSION_CONTEXT(N''IgnoreCodeSmell'') = N''1''
	BEGIN
		PRINT(''Ignoring Code Smell'');
		RETURN;
	END		 			 		
	DECLARE @Alert			VARCHAR(1000) = ''### Server Trigger ',@TriggerName,''',
			@ObjectName		sysname,
			@DatabaseName	sysname,
			@Code			NVARCHAR(MAX),
			@LoginName		sysname,
			@O_SQLCMDError	NVARCHAR(2048),
			@EventType		VARCHAR(50);

	BEGIN TRY
			
		IF EXISTS(--CodeSmell
			SELECT TOP (1) 1 FROM [CodeSmell].[dbo].Setup_Players P WHERE APP_NAME() = P.APP_NAME AND HOST_NAME() LIKE P.HOST_NAME
			)
		BEGIN
			;WITH EventCTE AS
			(
				SELECT	EVENTDATA()		ED
			),
			ObjectCTE AS
			(
				SELECT	x.value(''DatabaseName[1]'',	''sysname'')		DatabaseName,
						CONCAT(x.value(''SchemaName[1]'', ''sysname'')	, ''.'', x.value(''ObjectName[1]'', ''sysname'')) ObjectName,
						x.value(''TSQLCommand[1]'', ''nvarchar(MAX)'') Command, 
						x.value(''LoginName[1]'', ''varchar(256)'') LoginName,
						x.value(''EventType[1]'',	 ''varchar(50)'')EventType
				FROM	EventCTE
						CROSS APPLY ED.nodes(''EVENT_INSTANCE[1]'') T(x)		
			)			
			--INSERT db_workspace.dbo.XXX20180805 (datetimeX, UserName, Prog,DatabaseName,ObjectName,HostName) 
			SELECT	@DatabaseName	= DatabaseName,
					@ObjectName		= ObjectName,
					@Code			= Command,
					@LoginName		= LoginName,
					@EventType		= EventType
			FROM	ObjectCTE;
			--WAITFOR DELAY ''00:00:10.000''
			IF LEN(@Code) > 105
			BEGIN
				EXEC [CodeSmell].[dbo].[usp_App_RunValidationCheckOnSP] @DatabaseName, @ObjectName, @Code, @LoginName, @O_SQLCMDError OUTPUT,@EventType;
				IF @O_SQLCMDError IS NOT NULL
				BEGIN
					RAISERROR (@O_SQLCMDError, 16, 1);
				END
			END
				
		END

																 														 
	END TRY
	BEGIN CATCH	
		IF ERROR_NUMBER() = 50000
		BEGIN
			SET @Alert = ERROR_MESSAGE();
			--SELECT @Alert [@Alert]
			--PRINT @Alert;
			THROW 50000,@Alert,1;
		END
		ELSE
		BEGIN
			SET @Alert = CONCAT(@Alert, '' failed: '', ERROR_MESSAGE(), '' (line: '', ERROR_LINE(), '')'');
			PRINT @Alert;
		END
	END CATCH			 				 
END;');

	
	EXEC sys.sp_executesql @cmd;
	---------------------------------------------------
	SET @TriggerName = N'str_CodeSmell_PObjectChange';
	IF EXISTS ( SELECT	TOP (1) 1
	FROM	master.sys.server_triggers
	WHERE	name = @TriggerName
	)
	BEGIN
		SELECT @cmd = 'DROP TRIGGER [' + @TriggerName + '] ON ALL SERVER;';
	    EXEC sys.sp_executesql @cmd;
	END

	SELECT @cmd = CONCAT('CREATE TRIGGER ',QUOTENAME(@TriggerName),' 	
	ON ALL SERVER FOR CREATE_TABLE
---------------------------------------------------------------------------------------
-- #####					DEV ONLY!!!											#### --
---------------------------------------------------------------------------------------
-- Application Module:	CodeSmell
-- Procedure Name:		',@TriggerName,'
-- Create date:			',CONVERT(VARCHAR(25),GETDATE(),121),'
-- Author:				sharonr
-- Description:			this trigger will raise alerts for changes in marked objects
--
-- Updates : 
--	On: ; By: 
--	
--
---------------------------------------------------------------------------------------
-- #####					DEV ONLY!!!											#### --
---------------------------------------------------------------------------------------
AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS ON			 			 		
	DECLARE @Alert			VARCHAR(1000) = ''### Server Trigger ',@TriggerName,''',
			@ObjectName		sysname,
			@DatabaseName	sysname,
			@Code			NVARCHAR(MAX),
			@Date			DATE = GETDATE();

	BEGIN TRY
			
		IF EXISTS(--CodeSmell
			SELECT TOP (1) 1 FROM [CodeSmell].[dbo].Setup_Players P WHERE APP_NAME() = P.APP_NAME AND HOST_NAME() LIKE P.HOST_NAME
			)
		BEGIN
			;WITH EventCTE AS
			(
				SELECT	EVENTDATA()		ED
			),
			ObjectCTE AS
			(
				SELECT	x.value(''DatabaseName[1]'',	''sysname'')		DatabaseName,
						CONCAT(x.value(''SchemaName[1]'', ''sysname'')	, ''.'', x.value(''ObjectName[1]'', ''sysname'')) ObjectName,
						x.value(''TSQLCommand[1]'', ''nvarchar(MAX)'') Command
				FROM	EventCTE
						CROSS APPLY ED.nodes(''EVENT_INSTANCE[1]'') T(x)		
			)			
			--INSERT db_workspace.dbo.XXX20180805 (datetimeX, UserName, Prog,DatabaseName,ObjectName,HostName) 
			SELECT	@DatabaseName	= DatabaseName,
					@ObjectName		= ObjectName,
					@Code			= Command
			FROM	ObjectCTE;
			--WAITFOR DELAY ''00:00:10.000''
			IF LEN(@Code) > 10
			BEGIN
				EXEC [CodeSmell].[dbo].[usp_App_RunCheck_Object] @DatabaseName, @Date,@Date, @ObjectName, 0;
			END
				
		END

	END TRY
	BEGIN CATCH			
		SET @Alert = CONCAT(@Alert, '' failed: '', ERROR_MESSAGE(), '' (line: '', ERROR_LINE(), '')'')
		PRINT @Alert
	END CATCH
END;');
	
	EXEC sys.sp_executesql @cmd;
END