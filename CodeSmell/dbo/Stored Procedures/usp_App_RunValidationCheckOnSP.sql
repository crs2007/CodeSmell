-- =============================================
-- Author:		Sharon
-- Create date: 05/08/2018
-- Description:	General SP that run all check by Version Number
--
-- Updates :
--	On: 13/08/2020	By: sharonr
--		Added suport of get outpot to PARSI via SQLCMD
--		New output parameter @O_SQLCMDError
--
--	On: 02/07/2021	By: sharonr
--		Added @I_EventType to activate test only on specific event
-- =============================================
CREATE PROCEDURE dbo.usp_App_RunValidationCheckOnSP
	@I_DataBaseName sysname,
	@I_ObjectName	sysname,
	@I_Code			NVARCHAR(MAX)	= NULL,
	@I_LoginName	sysname			= NULL,
	@O_SQLCMDError	NVARCHAR(2048)	OUTPUT,
	@I_EventType	VARCHAR(50) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	IF SESSION_CONTEXT(N'IgnoreCodeSmell') = N'1'
	BEGIN
		RETURN -1;
	END
    
	DECLARE @StartDate				DATE = GETDATE();
	DECLARE @EndDate				DATE = GETDATE();
	DECLARE @Detail					BIT = 0;
	DECLARE @Part1					BIT = 1;
	DECLARE @CollectProcDefinition	BIT = 1;
	DECLARE @CollectProcName		BIT = 1;
	IF EXISTS(SELECT TOP (1) 1 FROM dbo.App_IgnoreList WHERE @I_DataBaseName = [Value] AND ValueType = 'Database')
	BEGIN
	    RETURN;
	END
	BEGIN TRY
		EXECUTE [dbo].[usp_App_RunCheck] @I_DataBaseName = @I_DataBaseName,
										 @I_StartDate = @StartDate,
										 @I_EndDate = @EndDate,
										 @I_ObjectName = @I_ObjectName,
										 @I_Detail = @Detail,
										 @I_Part1 = @Part1,
										 @I_CollectProcDefinition = @CollectProcDefinition,
										 @I_CollectProcName = @CollectProcName,
										 @I_Code = @I_Code,
										 @I_Debug = 0,
										 @I_LoginName = @I_LoginName,
										 @O_SQLCMDError = @O_SQLCMDError OUTPUT,
										 @I_EventType = @I_EventType;
	
	END TRY
	BEGIN CATCH
		DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE();
		RAISERROR (@msg,16,1);	
	END CATCH

--PRINT @I_Code
END