-- =============================================
-- Author:		Sharon
-- Create date: 09/11/2020
-- Description:	How to run
-- =============================================
CREATE PROCEDURE Setup.usp_Help
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Print NVARCHAR(2048);
	
		SET @Print = CONCAT('DECLARE @O_SQLCMDError NVARCHAR(2048);
EXECUTE [dbo].[usp_App_RunCheck] @I_DataBaseName = ''',(SELECT TOP (1) name FROM sys.databases WHERE database_id > 4 AND state = 0),''',		
								 @I_StartDate = ''',CONVERT(VARCHAR(10),DATEADD(YEAR,-20,GETDATE()),121),''',		
								 @I_EndDate = ''',CONVERT(VARCHAR(10),GETDATE(),121),''',			
								 @I_ObjectName = NULL,				
								 @I_Detail = 1,						
								 @I_Part1 = 1,						
								 @I_CollectProcDefinition = 1,		
								 @I_CollectProcName = 1,			
								 @I_Code = NULL,					
								 @I_Debug = 0,						
								 @I_LoginName = NULL,				
								 @O_SQLCMDError = @O_SQLCMDError OUTPUT;
IF @O_SQLCMDError IS NOT NULL SELECT @O_SQLCMDError [@O_SQLCMDError];');
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
	    RETURN;

	
END