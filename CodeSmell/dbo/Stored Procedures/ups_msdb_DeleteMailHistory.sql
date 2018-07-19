-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Description:	Delete Mail history from msdb.
-- =============================================
CREATE PROCEDURE [dbo].[ups_msdb_DeleteMailHistory]
	@DaysToLeft INT = 60
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @OldDate DATETIME = DATEADD(dd,-@DaysToLeft,GETDATE());

	--Step 1:Reindex database mail histroy tables
	-- Reindex before attempting to run [msdb]..[sysmail_delete_mailitems_sp] and [msdb]..[sysmail_delete_log_sp],
	-- or it could take a long time
	ALTER INDEX ALL ON [msdb]..[sysmail_log] REBUILD
	ALTER INDEX ALL ON [msdb]..[sysmail_faileditems] REBUILD 
	ALTER INDEX ALL ON [msdb]..[sysmail_unsentitems] REBUILD
	ALTER INDEX ALL ON [msdb]..[sysmail_sentitems] REBUILD
	
	EXEC  [msdb]..[sysmail_delete_log_sp] @logged_before = @OldDate
	EXEC  [msdb]..[sysmail_delete_mailitems_sp] @sent_before = @OldDate

	ALTER INDEX ALL ON [msdb]..[sysmail_log] REBUILD
	ALTER INDEX ALL ON [msdb]..[sysmail_faileditems] REBUILD 
	ALTER INDEX ALL ON [msdb]..[sysmail_unsentitems] REBUILD
	ALTER INDEX ALL ON [msdb]..[sysmail_sentitems] REBUILD

END