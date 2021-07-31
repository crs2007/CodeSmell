-- =============================================
-- Author:		Sharon
-- Create date: 16/07/2018
--				On: 30/07/2021 ; By: sharonr
--					ALTER - Adds cleaning from [Background].[Inner_sql_DefinitionRegex]/Inner_sql_modules/Inner_sql_ObjectNameRegex and [dbo].[App_Exeption]

-- Description:	CleanUp.
-- =============================================
CREATE PROCEDURE [Setup].[usp_CleanUp]
AS
BEGIN
	SET NOCOUNT ON;
	
	-- Clean Log Table
	TRUNCATE TABLE dbo.Mng_ApplicationErrorLog;
	TRUNCATE TABLE History.App_DetailRun;
	TRUNCATE TABLE [dbo].[App_Exeption];
	TRUNCATE TABLE [Background].[Inner_sql_ObjectNameRegex];
	TRUNCATE TABLE [Background].[Inner_sql_modules];
	TRUNCATE TABLE [Background].[Inner_sql_DefinitionRegex];
	
	DELETE History.App_MainRun;
END