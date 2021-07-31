CREATE PROCEDURE [Util].[USP_PrintMax]
	@I_Text		nvarchar(max)
WITH EXECUTE AS OWNER
AS
------------------------------------------------------------------
-- Application Module:	Utilities
-- Procedure Name:		Util.USP_PrintMax		
-- Created:				31/07/2021
-- Author:				sharonr
-- Description:			this sp try to USP_PrintMax over 400 chars.
--
-- Updates: 
--	On:  ; By: 
--		
--
--
------------------------------------------------------------------
BEGIN
	SET NOCOUNT ON

	DECLARE  @CurrentEnd	bigint,		-- track the length of the next substring 
			 @offset		TINYINT;		-- tracks the amount of offset needed 

	SET @I_Text = REPLACE(REPLACE(@I_Text, char(13) + char(10), char(10)), char(13), char(10))

	WHILE LEN(@I_Text) > 1
	BEGIN
		IF CHARINDEX(CHAR(10), @I_Text) between 1 AND 4000
		BEGIN
			SET @CurrentEnd =  CHARINDEX(char(10), @I_Text) - 1
			SET @offset = 2
		END
		ELSE IF CHARINDEX('</row>', @I_Text, 3000) between 3000 AND 4000
		BEGIN
			SET @CurrentEnd =  CHARINDEX('</row>', @I_Text, 3000) + 5
			SET @offset = 1
		END
		ELSE
		BEGIN
			SET @CurrentEnd = 4000
			SET @offset = 1
		END   

		PRINT SUBSTRING(@I_Text, 1, @CurrentEnd) 

		SET @I_Text = SUBSTRING(@I_Text, @CurrentEnd + @offset, 1073741822)   
	END
END