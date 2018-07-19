-- =============================================
-- Author:		Sharon
-- Create date: 10/06/2013
-- Description:	Return Global Parmeter
-- =============================================
CREATE FUNCTION [dbo].[Setup_GetGlobalParm]
(
	@ID INT
)
RETURNS NVARCHAR(255)
AS
BEGIN
	DECLARE @Value NVARCHAR(255)

	SELECT	TOP 1 @Value = Value
	FROM	dbo.Setup_GlobleParameter
	WHERE	ID = @ID

	-- Return the result of the function
	RETURN @Value

END