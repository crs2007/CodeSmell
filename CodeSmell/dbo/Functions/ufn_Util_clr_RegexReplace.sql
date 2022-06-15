CREATE FUNCTION [dbo].[ufn_Util_clr_RegexReplace]
(@Input NVARCHAR (MAX) NULL, @Pattern NVARCHAR (4000) NULL, @Replacement NVARCHAR (MAX) NULL, @IsCS BIT NULL)
RETURNS NVARCHAR (MAX)
AS
 EXTERNAL NAME [CodeSmellCLR].[UserDefinedFunctions].[RegexReplace]

