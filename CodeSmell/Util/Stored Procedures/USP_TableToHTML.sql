CREATE PROCEDURE Util.USP_TableToHTML
	@I_AddStyleTag		BIT = 1,
	@O_HTML				NVARCHAR(MAX)	OUTPUT
AS
---------------------------------------------------------------------------------------------------------
-- Application Module:	Utilities
-- Procedure Name:      Util.USP_TableToHTML
-- Create date:			14/05/2019
-- Author:				zacf
-- Description:			This stored procedure convert the data in #ToHTML to HTML code. column names will be used as headers with <TH> tag
--
-- Updates :  
--	On:  ; By:  
--
-- Parameters:
--
-- Errors: 
--		
---------------------------------------------------------------------------------------------------------
BEGIN
	SET NOCOUNT ON

	DECLARE @cmd	NVARCHAR(MAX) = ''

	SELECT	@cmd += CONCAT('CONCAT([', name, '],'''') td, ')
	FROM	tempdb.sys.columns
	WHERE	object_id = OBJECT_ID('tempdb..#ToHTML')
	ORDER BY column_id

	SET @cmd = CONCAT('SET @o = (SELECT ', @cmd, 'NULL FROM #ToHTML FOR XML RAW(''tr''), ELEMENTS)')

	EXEC sys.sp_executesql @cmd, N'@o nvarchar(max) OUTPUT', @o = @O_HTML OUT

	SET @O_HTML = CONCAT('<table>',
						(
							SELECT	name th
							FROM	tempdb.sys.columns
							WHERE	object_id = OBJECT_ID('tempdb..#ToHTML')
							ORDER BY column_id
							FOR XML PATH(''), ROOT('tr'), ELEMENTS
						),
						@O_HTML,
						'</table>'
				)

	SET @O_HTML = REPLACE(@O_HTML, '<td></td>', '<td>&nbsp;</td>')

	IF @I_AddStyleTag = 1
		BEGIN
	    	SET @O_HTML = '<style type="text/css">
	table, th, td {font-family:Calibri; font-size:15px; border: 1px solid black; border-spacing: 0px; padding: 6px;}	
	table {border-collapse: collapse;}	
	th {background-color: #e0e0e0}
</style>
' + @O_HTML
		END
END