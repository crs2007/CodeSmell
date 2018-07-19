-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Description:	Delete Job history from msdb.
-- =============================================
CREATE PROCEDURE [dbo].[ups_msdb_DeleteJobHistory]
	@DaysToLeft INT = 60
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @OldDate DATETIME = DATEADD(dd,-@DaysToLeft,GETDATE());

	--Step 1:Reindex job history table
	-- Reindex before attempting to run [msdb]..[sp_purge_jobhistory],
	-- or it could take a long time
	ALTER INDEX ALL ON [msdb]..[sysjobhistory]  REBUILD

	EXEC [msdb]..[sp_purge_jobhistory] @oldest_date = @OldDate

	-- Reindex after running [msdb]..[sp_purge_jobhistory]
	ALTER INDEX ALL ON [msdb]..[sysjobhistory]  REBUILD

END