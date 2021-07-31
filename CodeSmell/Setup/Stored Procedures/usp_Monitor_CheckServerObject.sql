-- =============================================
-- Author:		Sharon Rimer
-- Create date: 07/07/2021
-- Description:	CheckServerObject
-- =============================================
CREATE PROCEDURE Setup.usp_Monitor_CheckServerObject
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @TrigerCount INT;
	DECLARE @Triger TABLE(TriggerName sysname NOT NULL);
	INSERT @Triger(TriggerName)VALUES('str_CodeSmell_ObjectChange'),  ('str_CodeSmell_PObjectChange');
	SET @TrigerCount = @@ROWCOUNT;
	DECLARE @MailTable NVARCHAR(MAX) = N'';
	DECLARE @MailSubject NVARCHAR(255) = N'CodeSmell - Missing server object';
	DECLARE @I_body VARCHAR(MAX) = CONCAT(N'Server : ', @@SERVERNAME, '<br>
MachineName:', CONVERT(VARCHAR(250), SERVERPROPERTY('MachineName')), '<br>
ComputerNamePhysicalNetBIOS :', CONVERT(VARCHAR(250), SERVERPROPERTY('ComputerNamePhysicalNetBIOS')), '<br>');
	DECLARE @I_Recipients VARCHAR(MAX) = 'PlatformDBAUnit@users.888holdings.com;';
	DECLARE @I_IsHTMLFormat BIT = 1;
	DECLARE @I_IsHighImportance BIT = 0;
	



	IF NOT EXISTS (	  SELECT	COUNT(1)
					  FROM		sys.server_triggers tr
								INNER JOIN @Triger	t ON t.TriggerName = tr.name COLLATE DATABASE_DEFAULT
					  WHERE		is_disabled = 0
					  HAVING	COUNT(1) = @TrigerCount)
	BEGIN
		SELECT	@I_body += CONCAT(
							   t.TriggerName,
							   IIF(tr.name IS NULL, ' is missing', IIF(tr.is_disabled = 1, ' is disabled', '')),
							   '<br>
')
		FROM	@Triger						  t
				LEFT JOIN sys.server_triggers tr ON t.TriggerName = tr.name  COLLATE DATABASE_DEFAULT
		WHERE	tr.is_disabled = 1
				OR	tr.name IS NULL;
		BEGIN TRY
			SELECT	@I_body += CONCAT(
								   '<br>By - ',
								   ISNULL(
								   (   SELECT		TOP(1)
													A.LoginName
									   FROM			@Triger									  t
													INNER JOIN db_dba..[INFR_DDLTriggerAudit] A WITH(NOLOCK)ON A.ObjectName  COLLATE DATABASE_DEFAULT = t.TriggerName
									   WHERE		A.AppName LIKE 'Microsoft SQL Server Management Studio%'
													AND A.ObjectType != 'EVENT SESSION'
													AND A.EventDate > DATEADD(DAY, -7, GETDATE())
									   ORDER BY		A.EventDate DESC),
								   'Unknown'));
		END TRY
		BEGIN CATCH

		END CATCH;

		SET @I_body += N'<H1>' + @MailSubject + '</H1>
<font size="30">
'		;
		SET @I_body += @MailTable + '
<br>
</font><br>
{ConsiderEnvironment}';
		EXECUTE [Util].[USP_SendMail] @MailSubject, @I_body, @I_Recipients, @I_IsHTMLFormat, @I_IsHighImportance;
	END;
END;