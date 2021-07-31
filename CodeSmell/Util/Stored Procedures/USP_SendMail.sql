CREATE PROCEDURE Util.USP_SendMail
	@I_subject			VARCHAR(256),
	@I_body				VARCHAR(MAX),
	@I_Recipients		VARCHAR(MAX) ,
	@I_IsHTMLFormat		BIT			 = 0,
	@I_IsHighImportance BIT			 = 0,
	@I_CopyRecipients	VARCHAR(MAX) = NULL
WITH EXECUTE AS OWNER
AS
------------------------------------------------------------------
-- Application Module:	Utilities
-- Procedure Name:		Util.USP_SendMail		
-- Created:				14/2/2018
-- Author:				sharonr
-- Description:			this sp try to send HTML email.
--
-- Updates: 
--	On: 01/08/2018 ; By: Rimer Sharon
--		-- GDPR - Adds @I_IsHighImportance.
--
--	On: 20/05/2020 ; By: Rimer Sharon
--		-- Adds Util.UDF_S_GetConfiguration('Environment') to @I_subject
--
--	On: 13/10/2020 ; By: Rimer Sharon
--		-- Adds @I_LogMailDetails to log all detail of the sent mail
--
--	On: 21/01/2021 ; By: Rimer Sharon
--		-- Adds @I_CopyRecipients for copy_recipients
--
------------------------------------------------------------------
-- Parameters:
--	@I_subject
--	-- email subject
--	@I_body
--	-- email body
--	@Recipients
--	-- email recipients
--	@I_IsHTMLFormat		BIT			 = 0
--	-- If sent the mail in HTML format or TEST format
--	@I_IsHighImportance BIT			 = 0
--	-- If you would like to add exclamation mark to the mail
------------------------------------------------------------------
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF SESSION_CONTEXT(N'IsUnitTest') = N'1'
	BEGIN
		RETURN -1;
	END

	DECLARE @MailImportance VARCHAR(6) = 'Normal',
			@MailProfile	sysname;

	SELECT	TOP (1) @MailProfile = name 
	FROM	msdb.dbo.sysmail_account 
	ORDER BY account_id;
			
	
	BEGIN TRY

		IF @I_Recipients IS NULL SELECT @I_Recipients = TRY_CONVERT(VARCHAR(100),Value) FROM dbo.Setup_GlobleParameter WHERE Name = 'MailRecipients';
		SET @I_subject = CONCAT(@I_subject, ' - ',CONVERT(VARCHAR(100),SERVERPROPERTY('MachineName')))
		SET @I_body = CONCAT('-=- Message from {ServerName} -=-<br><br><br>', @I_body)
		SET @I_body = REPLACE(@I_body, '{ConsiderEnvironment}', '<br><br><br><font color="#009900" face="Webdings" size="4">P</font>
<font color="#009900" face="verdana,arial,helvetica" size="2"><strong>Please consider the environment before printing this email.</strong></font>')  -- {ConsiderEnvironment} is a valid placeholder within the message body
		SET @I_body = REPLACE(@I_body, '{ServerName}', @@SERVERNAME)  -- {ServerName} is a valid placeholder within the message body
		IF @I_IsHTMLFormat = 1
		BEGIN
			SET @I_body = CONCAT('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <title>Certificate renewal Notification</title>
        <style type="text/css">
        body {margin: 0; padding: 0; min-width: 100%!important;}
        .content {width: 100%; max-width: 600px;}  
        </style>
    </head>
    <body>',@I_body,'
    </body>
</html>');
		END

		IF @I_IsHighImportance = 1
		BEGIN
		    SET @MailImportance = 'High';
		END


		EXEC msdb.dbo.sp_send_dbmail
				@profile_name	=	@MailProfile,
				@recipients		=	@I_Recipients,
				@copy_recipients =  @I_CopyRecipients,
				@subject		=	@I_subject,
				@body			=	@I_body,
				@body_format	=	'HTML',
				@importance		=	@MailImportance,
				@exclude_query_output = 1;
	END TRY
	BEGIN CATCH		
		--SET @msg = CONCAT('fail to send mail. error: ', ERROR_MESSAGE(), ' (', ERROR_NUMBER() ,') line: ', ERROR_LINE(), ';');
		--Can used to call Slack or any other methud that does not relay on mail server
		THROW;
	END CATCH			
END