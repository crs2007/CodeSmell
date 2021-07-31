-- =============================================
-- Author:		Sharon
-- Create date: 05/08/2010 --Please Insert comment of today date with a description of your changes in this procedure.(Warning)
-- Description:	General SP that run all check by Version Number
-- =============================================
CREATE PROCEDURE [dbo].[usp_App_TestSP_SupposedToFail]
AS
BEGIN
	--Procedures without SET NOCOUNT ON(Minor)
	DECLARE @@x INT
	SELECT * FROM CodeSmell.dbo.App_Exclusion WHERE 1 = 0;--Do not enter database name in the code.(Major)

END