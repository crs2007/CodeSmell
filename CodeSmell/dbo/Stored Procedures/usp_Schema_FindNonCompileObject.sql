
-- =============================================
-- Author:		Sharon
-- Create date: 09/07/2018
-- Update date: 
-- Description:	Finding a Non-Compiling Object.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Schema_FindNonCompileObject]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @DBName NVARCHAR(129);

	-- Local DB Only
	SELECT  @DBName = QUOTENAME(name) + N'.'
	FROM    sys.databases 
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL  
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),'You must enter valid local database name insted - ' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,HOST_NAME(),USER_NAME();  
		RETURN -1;
	END
	DECLARE @sqlCmd NVARCHAR(MAX) ,
			@prefix NVARCHAR(1000) = N'';

	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL SET @prefix = N'
	INSERT	#Exeption';
	
	CREATE TABLE #DBObj(ObjectName NVARCHAR(512) NOT NULL,type_desc sysname NOT NULL);
	DECLARE @Name NVARCHAR(1000);
	DECLARE @Sqltype sysname;
	DECLARE @Result INT;

	SELECT	@sqlCmd = N'
	INSERT #DBObj
	SELECT s.name + ''.'' + o.name,o.type_desc
	FROM   ' + @DBName + N'sys.objects o
			INNER JOIN ' + @DBName + N'sys.schemas s on s.schema_id = o.schema_id
	WHERE  o.type_desc IN ( ''SQL_STORED_PROCEDURE'', ''SQL_TRIGGER'',
						  ''SQL_SCALAR_FUNCTION'', ''SQL_TABLE_VALUED_FUNCTION'',
						  ''SQL_INLINE_TABLE_VALUED_FUNCTION'', ''VIEW''
						)
		   --include the following if you have schema bound objects since they are not supported
		   AND ISNULL(OBJECTPROPERTY(o.object_id, ''IsSchemaBound''), 0) = 0
	OPTION(RECOMPILE);';
	EXEC sp_executesql @sqlCmd;
	
	BEGIN TRY
		
		DECLARE ObjectCursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT	ObjectName,
				type_desc
		FROM	#DBObj

		OPEN ObjectCursor;

		FETCH NEXT FROM ObjectCursor INTO @Name,@Sqltype;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @sqlCmd = N'USE [' + @DatabaseName + '];
EXEC sp_refreshsqlmodule ''' + @Name + '''';
			--PRINT @Sql;

			BEGIN TRY
				EXEC @Result = sp_executesql @sqlCmd;
				IF @Result <> 0
					RAISERROR('Failed', 16, 1);
			END TRY
			BEGIN CATCH
				--PRINT 'The module ' + @Sqltype + ' ''' + @Name + ''' does not compile.';
				
				SELECT	@sqlCmd = @prefix + N'
				SELECT	@DatabaseName DatabaseName,
						@Name ObjectName,
						@Sqltype Type,
						NULL ColumnName,
						NULL ConstraintName,
						REPLACE(REPLACE(@Massege,''$DATA_TYPE$'',@Sqltype),''$OBJECT_NAME$'',@Name) Massege,
						@URL_Reference URL,
						@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + ' Severity';

				
				EXEC sp_executesql @sqlCmd, 
						N'@DatabaseName sysname,
						@Massege NVARCHAR(1000),
						@URL_Reference VARCHAR(512),
						@SeverityName sysname,
						@ObjectID INT,
						@CheckID INT,
						@Name NVARCHAR(1000),
						@Sqltype sysname', 
						@DatabaseName = @DatabaseName,
						@Massege = @Massege,
						@URL_Reference = @URL_Reference,
						@SeverityName = @SeverityName,
						@ObjectID = @ObjectID,
						@CheckID = @CheckID,
						@Name = @Name,
						@Sqltype = @Sqltype;
			END CATCH;

			FETCH NEXT FROM ObjectCursor INTO @Name,@Sqltype;
		END;

		CLOSE ObjectCursor;
		DEALLOCATE ObjectCursor;
	END TRY
	BEGIN CATCH
		IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL
			INSERT #Mng_ApplicationErrorLog
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		ELSE
		BEGIN
			PRINT @sqlCmd;
			SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		END
		RETURN -1;
	END CATCH
END