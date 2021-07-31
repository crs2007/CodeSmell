CREATE PROCEDURE [Util].[USP_PrintConfigTableData]
	@I_Text		nvarchar(max)
WITH EXECUTE AS OWNER
AS
------------------------------------------------------------------
-- Application Module:	Utilities
-- Procedure Name:		Util.USP_PrintConfigTableData		
-- Created:				31/07/2021
-- Author:				sharonr
-- Description:			this sp Prints data from importent tables.
--
-- Updates: 
--	On:  ; By: 
--		
--
--
------------------------------------------------------------------
BEGIN
	SET NOCOUNT ON;

	DECLARE @TableName sysname;
	DECLARE @Script NVARCHAR(MAX);
	DECLARE @FullScript NVARCHAR(MAX) = N'';

	DECLARE curTableName CURSOR FAST_FORWARD READ_ONLY FOR 
	SELECT	s.name + '.' + t.name
	FROM	sys.schemas s 
			INNER JOIN sys.tables t ON t.schema_id = s.schema_id
	WHERE	t.name IN
	(
	N'App_CodeType',
	N'App_DBVersion',
	N'App_enum_SearchRegexMethod',
	N'App_Error',
	N'App_RegexPettern',
	N'App_Severity',
	N'App_SQLServerVersion',
	N'App_SubjectGroup',
	N'Setup_GlobleParameter',
	N'TriggerEvent',
	N'Passwords',
	N'VM_MemoryOverhead',
	N'App_CL_ErrVerPet',
	N'App_GeneralCheck'
	)
	ORDER BY s.name,t.name;
	OPEN curTableName;

	FETCH NEXT FROM curTableName INTO @TableName;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @Script = NULL;
		EXECUTE [Util].[USP_ScriptTableData] @I_TableName = @TableName,			-- sysname
											 @I_PrintOutput = 0,			-- bit
											 @O_Script = @Script OUTPUT;
		SELECT @FullScript = @FullScript + '
' + ISNULL(@Script,'');
		FETCH NEXT FROM curTableName INTO @TableName;
	END

	CLOSE curTableName;
	DEALLOCATE curTableName;

	EXECUTE [Util].[USP_PrintMax] @FullScript;
END