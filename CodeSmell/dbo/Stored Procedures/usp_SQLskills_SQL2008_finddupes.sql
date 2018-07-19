-- =============================================
-- Author:		Kimberly L. Tripp
-- Create date: <Create Date,,>
-- Update date: 24/08/2014 @ObjectID INT
--				13/07/2015 @CheckID INT = NULL
-- Description:	See my blog for updates and/or additional information
--				http://www.SQLskills.com/blogs/Kimberly (Kimberly L. Tripp)
-- =============================================
CREATE PROCEDURE [dbo].[usp_SQLskills_SQL2008_finddupes]
(
    @DatabaseName SYSNAME ,
    @Massege NVARCHAR(1000) ,
    @URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL
)
AS --  Jul 2011: V1 to find duplicate indexes.
BEGIN
    SET NOCOUNT ON;
    DECLARE @DBName NVARCHAR(129);

    DECLARE @ObjID INT ,			-- the object id of the table
			@ObjName NVARCHAR(776) = NULL ,		-- the table to check for duplicates
												-- when NULL it will check ALL tables
			@SchemaName SYSNAME ,
			@TableName SYSNAME ,
			@ExecStr NVARCHAR(4000)

	-- Local DB Only
    SELECT  @DBName = QUOTENAME(name) + N'.'
    FROM    sys.databases
    WHERE   name = @DatabaseName;

    IF @@ROWCOUNT = 0 
    BEGIN
        IF OBJECT_ID('tempdb..#Mng_ApplicationErrorLog') IS NOT NULL 
            INSERT  #Mng_ApplicationErrorLog
                    SELECT  OBJECT_NAME(@@PROCID) ,
                            'You must enter valid local database name insted - '
                            + ISNULL(N' insted - '
                                        + QUOTENAME(@DatabaseName), N'') ,
                            HOST_NAME() ,
                            USER_NAME();  
        RETURN -1;
    END
    
    IF @DatabaseName = N'tempdb' 
    BEGIN
        RAISERROR('WARNING: This procedure cannot be run against tempdb. Skipping tempdb.', 10, 0)
        RETURN (1);
    END

-- Check to see the the table exists and initialize @ObjID.
    SELECT  @SchemaName = PARSENAME(@ObjName, 2)

    IF @SchemaName IS NULL 
        SELECT  @SchemaName = SCHEMA_NAME()

-- Check to see the the table exists and initialize @ObjID.
    IF @ObjName IS NOT NULL 
        BEGIN
            SELECT  @ObjID = OBJECT_ID(@ObjName)
	
            IF @ObjID IS NULL 
                BEGIN
                    RAISERROR(15009,-1,-1,@ObjName,@DatabaseName)
        -- select * from sys.messages where message_id = 15009
                    RETURN (1)
                END
        END


    CREATE TABLE #DropIndexes
        (
          DatabaseName SYSNAME ,
          SchemaName SYSNAME ,
          TableName SYSNAME ,
          IndexName SYSNAME ,
          DropStatement NVARCHAR(2000)
        )

    CREATE TABLE #FindDupes
        (
          index_id INT ,
          is_disabled BIT ,
          index_name NVARCHAR(129) ,
          index_description VARCHAR(210) ,
          index_keys NVARCHAR(2126) ,
          included_columns NVARCHAR(MAX) ,
          filter_definition NVARCHAR(MAX) ,
          columns_in_tree NVARCHAR(2126) ,
          columns_in_leaf NVARCHAR(MAX)
        )

    DECLARE @sqlCmd NVARCHAR(MAX) ,
			@prefix NVARCHAR(1000) = N'';

    CREATE TABLE #obj
        (
          SchemaName SYSNAME ,
          NAME SYSNAME
        );
    SET @sqlCmd = N'
INSERT #obj
SELECT  OBJECT_SCHEMA_NAME(id,DB_ID(@DatabaseName)) ,
        name
FROM    ' + @DBName + 'sys.sysobjects
WHERE   type = ''U''';
	--PRINT @sqlCmd;
    EXEC sys.sp_executesql @sqlCmd, N'@DatabaseName sysname',
        @DatabaseName = @DatabaseName


-- OPEN CURSOR OVER TABLE(S)
    DECLARE TableCursor CURSOR LOCAL STATIC
    FOR
        SELECT  SchemaName ,
                name
        FROM    #obj
        ORDER BY SchemaName ,
                name
	    
    OPEN TableCursor 

    FETCH TableCursor
    INTO @SchemaName, @TableName

-- For each table, list the add the duplicate indexes and save 
-- the info in a temporary table that we'll print out at the end.

    WHILE @@fetch_status >= 0 
        BEGIN
            TRUNCATE TABLE #FindDupes
    
            SELECT  @ExecStr = 'EXEC dbo.usp_SQLskills_SQL2008_finddupes_helpindex  ''' + @DatabaseName + ''', '''
                    + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
                    + N''''

    --SELECT @ExecStr

            INSERT  #FindDupes
            EXEC (@ExecStr)	
    
    --SELECT * FROM #FindDupes
	
            INSERT  #DropIndexes
                    SELECT DISTINCT
                            @DatabaseName ,
                            @SchemaName ,
                            @TableName ,
                            t1.index_name ,
                            N'DROP INDEX ' + QUOTENAME(@SchemaName, N']')
                            + N'.' + QUOTENAME(@TableName, N']') + N'.'
                            + t1.index_name
                    FROM    #FindDupes AS t1
                            JOIN #FindDupes AS t2 ON t1.columns_in_tree = t2.columns_in_tree
                                                     AND t1.columns_in_leaf = t2.columns_in_leaf
                                                     AND ISNULL(t1.filter_definition,
                                                              1) = ISNULL(t2.filter_definition,
                                                              1)
                                                     AND PATINDEX('%unique%',
                                                              t1.index_description) = PATINDEX('%unique%',
                                                              t2.index_description)
                                                     AND t1.index_id > t2.index_id
                
            FETCH TableCursor
        INTO @SchemaName, @TableName
        END
	
    DEALLOCATE TableCursor

-- DISPLAY THE RESULTS
	IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL SET @prefix = N'
	INSERT	#Exeption';
	--
	SELECT	@sqlCmd = @prefix + N'
	SELECT	DatabaseName DatabaseName,
			SchemaName + N''.'' + TableName ObjectName,
			''Index'' Type,
			IndexName ColumnName,
			DropStatement ConstraintName,
			@Massege Massege,
			@URL_Reference URL,
			@SeverityName' + CASE WHEN @CheckID IS NOT NULL THEN ',@CheckID' ELSE N'' END + '
	FROM	#DropIndexes;';
	
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
  
    
    --IF ( SELECT COUNT(*)
    --     FROM   #DropIndexes
    --   ) = 0 
    --    RAISERROR('Database: %s has NO duplicate indexes.', 10, 0, @DatabaseName)
    --ELSE 
    --    SELECT  *
    --    FROM    #DropIndexes
    --    ORDER BY SchemaName ,
    --            TableName

    --IF OBJECT_ID('tempdb..#obj') IS NOT NULL 
    --    DROP TABLE #obj;
    --RETURN (0) -- sp_SQLskills_SQL2008_finddupes

END