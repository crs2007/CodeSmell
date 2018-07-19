CREATE FUNCTION [dbo].[ufn_Util_clr_RegexMatch]
(@Input NVARCHAR (MAX) NULL, @Pattern NVARCHAR (4000) NULL, @IsCS BIT NULL, @arg INT NULL)
RETURNS 
     TABLE (
        [MatchText] NVARCHAR (4000) NULL)
AS
 EXTERNAL NAME [CodeSmallesCLR].[UserDefinedFunctions].[RegexMatch]

