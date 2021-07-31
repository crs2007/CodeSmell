CREATE PROCEDURE [Util].[USP_ScriptTableData]
	@I_TableName		sysname,
	@I_PrintOutput		BIT			 = 0,
	@O_Script			NVARCHAR(MAX) OUTPUT
WITH EXECUTE AS OWNER
AS
------------------------------------------------------------------
-- Application Module:	Utilities
-- Procedure Name:		Util.USP_ScroptTableData		
-- Created:				31/07/2021
-- Author:				sharonr
-- Description:			this sp try to pull data from tables.
--
-- Updates: 
--	On:  ; By: 
--		
--
--
------------------------------------------------------------------
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SELECT @O_Script = 'DECLARE @TableData XML = N'
	DECLARE @cmd NVARCHAR(MAX) = ''
	DECLARE @ColumnList NVARCHAR(MAX) = ''
	DECLARE @CheckSumColumnList NVARCHAR(MAX) = ''
	DECLARE @UpdateColumnList NVARCHAR(MAX) = ''
	DECLARE @XmlValueColumnList NVARCHAR(MAX) = ''
	DECLARE @MatchKey NVARCHAR(MAX) = ''
	DECLARE @TableRawXML XML

	-- get table metadata
	SELECT	c.name,		
		CASE WHEN ic.object_id IS NOT NULL THEN 1 ELSE 0 END is_pk,		
		c.is_identity,		
		CASE 
			WHEN t.name IN ('bigibt', 'int', 'smallint', 'tinyint', 'bit', 'xml', 'datetime', 'smalldatetime', 'date', 'time', 'uniqueidentifier', 'money', 'smallmoney', 'float', 'real') 
				THEN t.name
			WHEN t.name IN ('char', 'varchar', 'nchar', 'nvarchar', 'binary', 'varbinary') 
				THEN t.name + '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CONVERT(NVARCHAR(10), c.max_length) END + ')'
			WHEN t.name IN ('numeric')
				THEN  t.name + '(' + CONVERT(NVARCHAR(10), c.precision) + ', ' +  CONVERT(NVARCHAR(10), c.scale) + ')'
		END ScriptType,
		CASE 
			WHEN t.name IN ('xml') 
				THEN 'CONVERT(NVARCHAR(MAX), ' + c.name + ')'
			ELSE  c.name
		END CheckSumColumn,
		c.column_id
		INTO	#columns
		FROM	sys.columns c
				INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
				LEFT JOIN sys.indexes i ON i.object_id = c.object_id AND i.is_primary_key = 1
				LEFT JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.column_id = c.column_id AND i.index_id = ic.index_id 
		WHERE	c.object_id = OBJECT_ID(@I_TableName)
		ORDER BY c.column_id

		SELECT	@ColumnList = 
			SUBSTRING( 
				CONVERT(NVARCHAR(MAX), 
					(
					SELECT	',' + name  
					FROM	#columns
					ORDER BY column_id
					FOR XML PATH('')
					)
				), 2, 50000),
		@CheckSumColumnList = 
			SUBSTRING( 
				CONVERT(NVARCHAR(MAX), 
					(
					SELECT	',' + CheckSumColumn  
					FROM	#columns
					ORDER BY column_id
					FOR XML PATH('')
					)
				), 2, 50000),
		@UpdateColumnList = 
			SUBSTRING( 
				CONVERT(NVARCHAR(MAX), 
					(
					SELECT	',' + name + ' = src.' + name
					FROM	#columns
					ORDER BY column_id
					FOR XML PATH('')
					)
				), 2, 50000),
		@XmlValueColumnList = 
			SUBSTRING( 
				CONVERT(NVARCHAR(MAX), 
					(
					SELECT	CASE WHEN ScriptType = 'xml' THEN ',c.query(''' + name + '/*'')' + name  
							ELSE ',c.value(''' + name + '[1]'', ''' + ScriptType + ''') ' + name  
							END 
					FROM	#columns
					ORDER BY column_id
					FOR XML PATH('')
					)
				), 2, 50000)

		SELECT	@MatchKey = 'src.' + name + ' = trg.' + name
		FROM	#columns
		WHERE	is_pk = 1

		-- create select command to get the table data as XML
		SELECT	@cmd = '
SET @XmlOut = (
SELECT	' + @ColumnList + ',
		CHECKSUM(' + @CheckSumColumnList + ') [__RowCheckSum]
FROM	' + @I_TableName + '
FOR XML PATH(''row''),ROOT(''data'')
)'

	-- get the table data as XML
	EXEC sys.sp_executesql @cmd, N'@XmlOut XML OUT', @XmlOut = @TableRawXML OUT;

	SELECT @O_Script = @O_Script + '''' + REPLACE(CONVERT(NVARCHAR(MAX), @TableRawXML), '''', '''''') + ''''

	IF EXISTS (SELECT TOP 1 1 FROM #columns WHERE is_identity = 1)
	BEGIN
		SET @O_Script = @O_Script +
'
SET IDENTITY_INSERT ' + @I_TableName + ' ON;
'  
	END

	SELECT @O_Script = @O_Script + '
/*********************************************************************/
/*********************  ' + @I_TableName + ' *********************/
/*********************************************************************/
;WITH trg AS
(
	SELECT	*,
			CHECKSUM(' + @CheckSumColumnList + ') [__RowCheckSum]
	FROM	' + @I_TableName + '
)
MERGE	trg
USING	(
		SELECT	' + @XmlValueColumnList + '
				,c.value(''__RowCheckSum[1]'', ''int'') __RowCheckSum
		FROM	@TableData.nodes(''/data/row'') as T(C) 
		) src
ON ' + @MatchKey + '
WHEN MATCHED AND trg.__RowCheckSum != src.__RowCheckSum THEN 
	UPDATE SET
			' + @UpdateColumnList + '
WHEN NOT MATCHED THEN 
	INSERT (' + @ColumnList + ') VALUES (src.' + REPLACE(@ColumnList, ',', ',src.') + ')
WHEN NOT MATCHED BY SOURCE THEN
	DELETE;
'


	IF EXISTS (SELECT TOP (1) 1 FROM #columns WHERE is_identity = 1)
	BEGIN
		SET @O_Script = @O_Script + '
SET IDENTITY_INSERT ' + @I_TableName + ' OFF;
'
	END
	SET @O_Script = @O_Script + '
GO
';
	/**************** Print Max *************************/
	IF @I_PrintOutput = 1
	BEGIN
		EXECUTE [Util].[USP_PrintMax] @O_Script;
	END 
	DROP TABLE #columns;
END