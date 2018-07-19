CREATE FUNCTION [dbo].[ufn_Util_clr_RegexIsMatch]
(@Input NVARCHAR (MAX) NULL, @Pattern NVARCHAR (4000) NULL, @IsCS BIT NULL)
RETURNS BIT
AS
 EXTERNAL NAME [CodeSmallesCLR].[UserDefinedFunctions].[RegexIsMatch]

