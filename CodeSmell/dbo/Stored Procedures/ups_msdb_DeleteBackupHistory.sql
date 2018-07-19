-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Description:	Delete backup history from msdb.
-- =============================================
CREATE PROCEDURE [dbo].[ups_msdb_DeleteBackupHistory]
	@DaysToLeft INT = 60
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @OldDate DATETIME = DATEADD(dd,-@DaysToLeft,GETDATE());

	--Step 1:Reindex backup history tables
	-- Reindex before attempting to run [msdb]..[sp_delete_backuphistory],
	-- or it could take a long time
	ALTER INDEX ALL ON [msdb]..[backupfile] REBUILD
	ALTER INDEX ALL ON [msdb]..[backupset] REBUILD
	ALTER INDEX ALL ON [msdb]..[backupmediaset] REBUILD
	ALTER INDEX ALL ON [msdb]..[restorefile] REBUILD
	ALTER INDEX ALL ON [msdb]..[restorefilegroup] REBUILD
	ALTER INDEX ALL ON [msdb]..[restorehistory] REBUILD

	EXEC [msdb]..[sp_delete_backuphistory] @OldDate

	--Reindex after running [msdb]..[sp_delete_backuphistory]
	ALTER INDEX ALL ON [msdb]..[backupfile] REBUILD
	ALTER INDEX ALL ON [msdb]..[backupset] REBUILD
	ALTER INDEX ALL ON [msdb]..[backupmediaset] REBUILD
	ALTER INDEX ALL ON [msdb]..[restorefile] REBUILD
	ALTER INDEX ALL ON [msdb]..[restorefilegroup] REBUILD
	ALTER INDEX ALL ON [msdb]..[restorehistory] REBUILD
END