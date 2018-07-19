-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [History].[usp_GetLastDefaultParameter]
AS
BEGIN
	SET NOCOUNT ON;
	

	SELECT	TOP 1 MR.DatabaseName,mr.StartDate,mr.EndDate
	FROM	History.App_MainRun MR
	WHERE	@@SERVERNAME = MR.ServerName
	ORDER BY ID DESC;
END