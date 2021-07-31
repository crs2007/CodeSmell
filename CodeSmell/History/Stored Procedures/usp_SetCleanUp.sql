-- =============================================
-- Author:		Sharon Rimer
-- Create date: 21/3/2019
--				On: 04/07/2021 ; By: sharonr
--					ALTER - Adds cleaning from Mng_ApplicationErrorLog
--				On: 30/07/2021 ; By: sharonr
--					ALTER - Adds cleaning from [Background].[Inner_sql_DefinitionRegex]/Inner_sql_modules/Inner_sql_ObjectNameRegex and [dbo].[App_Exeption]
-- Description:	History Clean up
-- =============================================
CREATE PROCEDURE [History].[usp_SetCleanUp]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @MainID TABLE
		  (
			  ID INT NOT NULL
		  );
	INSERT	@MainID (ID)
	SELECT	MR.ID
	FROM	History.App_MainRun MR
	WHERE	MR.ExecuteDate < DATEADD(DAY, -30, GETDATE());
	DECLARE @RC INT = 1;
	WHILE (@RC > 0)
	BEGIN
		DELETE TOP (500) FROM History.App_DetailRun
		WHERE	MainRunID IN ( SELECT ID   FROM @MainID );
		SET @RC = @@ROWCOUNT;
	END;

	SET @RC = 1;
	WHILE (@RC > 0)
	BEGIN
		DELETE TOP (500) FROM History.App_MainRun
		WHERE	ID IN ( SELECT ID  FROM @MainID );
		SET @RC = @@ROWCOUNT;
	END;
	
	SET @RC = 1;
	WHILE (@RC > 0)
	BEGIN
		DELETE TOP (500) FROM [Background].[Inner_sql_DefinitionRegex]
		WHERE	MainRunID IN ( SELECT ID  FROM @MainID );
		SET @RC = @@ROWCOUNT;
	END;

	SET @RC = 1;
	WHILE (@RC > 0)
	BEGIN
		DELETE TOP (500) FROM [Background].[Inner_sql_modules]
		WHERE	MainRunID IN ( SELECT ID  FROM @MainID );
		SET @RC = @@ROWCOUNT;
	END;
	
	SET @RC = 1;
	WHILE (@RC > 0)
	BEGIN
		DELETE TOP (500) FROM [Background].[Inner_sql_ObjectNameRegex]
		WHERE	MainRunID IN ( SELECT ID  FROM @MainID );
		SET @RC = @@ROWCOUNT;
	END;
	SET @RC = 1;
	WHILE (@RC > 0)
	BEGIN
		DELETE TOP (500) FROM [dbo].[App_Exeption]
		WHERE	MainRunID IN ( SELECT ID  FROM @MainID );
		SET @RC = @@ROWCOUNT;
	END;

	IF EXISTS(SELECT TOP (1) 1 FROM [dbo].[Mng_ApplicationErrorLog] WHERE ExecutionTime > DATEADD(DAY, -1,GETDATE()))
	BEGIN
	    SELECT ID, ProcedureName,  ErrorMessage, HostName, LoginName, CONVERT(VARCHAR(25),ExecutionTime,121)ExecutionTime, MainRunID INTO #ToHTML FROM [dbo].[Mng_ApplicationErrorLog] WHERE ExecutionTime > DATEADD(DAY, -1,GETDATE());
		IF EXISTS(SELECT TOP (1) 1 FROM #ToHTML)
		BEGIN
			DECLARE @MailTable NVARCHAR(MAX) = N'';
			DECLARE @MailSubject NVARCHAR(255) = N'CodeSmell - Application Error Log';
			DECLARE @I_body VARCHAR(MAX) = '';
			DECLARE @I_Recipients VARCHAR(MAX);
			DECLARE @I_IsHTMLFormat BIT = 1;
			DECLARE @I_IsHighImportance BIT = 0;

			EXECUTE [Util].[USP_TableToHTML]  1,@MailTable OUTPUT;
			

			SET @I_body += N'<H1>' + @MailSubject + '</H1>
<font size="30">
';
			SET @I_body += @MailTable + '
<br>
</font><br>
{ConsiderEnvironment}';
			EXECUTE [Util].[USP_SendMail] @MailSubject, @I_body, @I_Recipients, @I_IsHTMLFormat, @I_IsHighImportance;

		END

	END

	SET @RC = 1;
	WHILE @RC > 0
	BEGIN
		DELETE  TOP (500) FROM [dbo].[Mng_ApplicationErrorLog] 
		WHERE ExecutionTime < DATEADD(DAY, -30,GETDATE());
		SET @RC = @@ROWCOUNT;
	END

END;