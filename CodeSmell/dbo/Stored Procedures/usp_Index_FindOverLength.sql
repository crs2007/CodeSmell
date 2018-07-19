-- =============================================
-- Author:		Sharon
-- Create date: 17/03/2013
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	Find Over Length
-- =============================================
CREATE PROCEDURE [dbo].[usp_Index_FindOverLength]
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
	DECLARE @sqlCmd NVARCHAR(max) ,
			@prefix NVARCHAR(1000) = N'';

	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL SET @prefix = N'
	INSERT	#Exeption';

	SELECT	@sqlCmd = @prefix + N'
	SELECT	@DatabaseName DatabaseName,
			S.name + ''.'' + t.name ObjectName,
			''Index'' Type,
			NULL ColumnName,
			I.NAME ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM    ' + @DBName + N'sys.tables t
			INNER JOIN ' + @DBName + N'SYS.schemas S ON S.schema_id = t.schema_id
			INNER JOIN ' + @DBName + N'sys.indexes i ON t.object_id = i.object_id
			CROSS APPLY (SELECT	TOP 1  SUM(C.max_length) LengthSizeInByte
						 FROM	' + @DBName + N'sys.index_columns ic
								INNER JOIN ' + @DBName + N'sys.columns c ON c.object_id = ic.object_id
															AND c.column_id = ic.column_id
						 WHERE	ic.object_id = i.object_id
								AND ic.index_id = i.index_id
								AND ic.is_included_column = 0) ls
	WHERE   i.type > 0
			AND S.name != ''sys''
			AND LS.LengthSizeInByte > 900;';
	
	BEGIN TRY
		EXEC sp_executesql @sqlCmd, 
				N'@DatabaseName sysname,
				@Massege NVARCHAR(1000),
				@URL_Reference VARCHAR(512),
				@SeverityName sysname,
				@ObjectID INT,
				@CheckID INT', 
				@DatabaseName = @DatabaseName,
				@Massege = @Massege,
				@URL_Reference = @URL_Reference,
				@SeverityName = @SeverityName,
				@ObjectID = @ObjectID,
				@CheckID = @CheckID;
	END TRY
	BEGIN CATCH
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		RETURN -1;
	END CATCH
END