-- =============================================
-- Author:		Sharon
-- Create date: 24/06/2013
-- Description:	Delete ALL history from msdb.
-- =============================================
CREATE PROCEDURE [dbo].[ups_msdb_DeleteHistory]
	@DaysToLeft INT = 60
AS
BEGIN
	SET NOCOUNT ON;

    BEGIN TRY 
		
		EXECUTE [dbo].[ups_msdb_DeleteMailHistory] @DaysToLeft;
		EXECUTE [dbo].[ups_msdb_DeleteJobHistory] @DaysToLeft;
		EXECUTE [dbo].[ups_msdb_DeleteBackupHistory] @DaysToLeft;

    END TRY
    BEGIN CATCH
    	INSERT [dbo].[Mng_ApplicationErrorLog]
    	SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME(),GETDATE();

		--RAISERROR (ERROR_MESSAGE(),16,1);
		RETURN;
    END CATCH

END