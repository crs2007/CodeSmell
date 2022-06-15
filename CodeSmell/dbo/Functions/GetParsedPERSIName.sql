-- =============================================
-- Author:		Sharon
-- Create date: 09/05/2022
-- Description:	Return parsed PERSI name
-- =============================================
CREATE   FUNCTION [dbo].[GetParsedPERSIName]
(
	@I_UserName sysname
)
RETURNS sysname
AS
BEGIN
	DECLARE @Value sysname

	SELECT	@Value = REPLACE(REPLACE(REPLACE(
				SUBSTRING(@I_UserName,CHARINDEX('%U=',@I_UserName),LEN(@I_UserName)+1-CHARINDEX('%U=',@I_UserName))
				,'%U=',''),', %CR',''),'=','');

	-- Return the result of the function
	RETURN @Value;

END