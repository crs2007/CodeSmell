-- =============================================
-- Author:		Sharon
-- Create date: 16/07/2018
-- Description:	CleanUp.
-- =============================================
CREATE PROCEDURE [Setup].[usp_CleanUp]
AS
BEGIN
	SET NOCOUNT ON;
	
	-- Clean Log Table
	TRUNCATE TABLE dbo.Mng_ApplicationErrorLog;
	TRUNCATE TABLE History.App_DetailRun;
	DELETE History.App_MainRun;
END