CREATE PROCEDURE [dbo].[usp_SQLskills_ExposeColsInIndexLevels_INCLUDE_UNORDERED]
(
    @DatabaseName SYSNAME ,
    @object_id INT ,
    @index_id INT ,
    @ColsInTree NVARCHAR(MAX) OUTPUT ,
    @ColsInLeaf NVARCHAR(MAX) OUTPUT
)
AS 
BEGIN
    SET NOCOUNT ON;
    DECLARE @DBName NVARCHAR(129);

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
		  
        DECLARE @nonclus_uniq INT ,
            @column_id INT ,
            @column_name NVARCHAR(260) ,
            @col_descending BIT ,
            @colstr NVARCHAR(MAX);

        DECLARE @sqlCmd NVARCHAR(MAX) ,
            @prefix NVARCHAR(1000) = N'';

        CREATE TABLE #clus_keys
            (
              column_id INT ,
              column_name nvarchar(260) ,
              is_descending_key BIT
            );
        CREATE TABLE #nonclus_keys
            (
              column_id INT ,
              is_included_column BIT ,
              column_name NVARCHAR(260) ,
              is_descending_key BIT
            );
	

	-- Get clustered index keys (id and name)
	SET @sqlCmd = N'INSERT #clus_keys
        SELECT  sic.column_id ,
                QUOTENAME(sc.name, N'']'') AS column_name ,
                is_descending_key
        FROM    ' + @DBName + N'sys.index_columns AS sic
                INNER JOIN ' + @DBName + N'sys.columns AS sc ON sic.column_id = sc.column_id
                                          AND sc.object_id = sic.object_id
        WHERE   sic.[object_id] = @object_id
                AND [index_id] = 1;';
	EXEC sys.sp_executesql @sqlCmd ,N'@object_id INT', @object_id = @object_id;
		
	
	-- Get nonclustered index keys
      SET @sqlCmd = N'
		INSERT	#nonclus_keys
		SELECT  sic.column_id ,
                sic.is_included_column ,
                QUOTENAME(sc.name, N'']'') AS column_name ,
                is_descending_key
        FROM    ' + @DBName + N'sys.index_columns AS sic
                INNER JOIN ' + @DBName + N'sys.columns AS sc ON sic.column_id = sc.column_id
                                          AND sc.object_id = sic.object_id
        WHERE   sic.[object_id] = @object_id
                AND sic.[index_id] = @index_id;';
	EXEC sys.sp_executesql @sqlCmd ,N'@object_id INT, @index_id INT', @object_id = @object_id, @index_id = @index_id;
		
	-- Is the nonclustered unique?
        SET @sqlCmd = N'SELECT  @nonclus_uniq = is_unique
        FROM    ' + @DBName + N'sys.indexes
        WHERE   [object_id] = @object_id
                AND [index_id] = @index_id;';
	EXEC sys.sp_executesql @sqlCmd ,N'@object_id INT,@nonclus_uniq INT OUTPUT, @index_id INT', @object_id = @object_id,@nonclus_uniq = @nonclus_uniq OUT, @index_id = @index_id;

    IF ( @nonclus_uniq = 0 ) 
        BEGIN
	-- Case 1: nonunique nonclustered index

	-- cursor for nonclus columns not included and
	-- nonclus columns included but also clus keys
            DECLARE mycursor CURSOR
            FOR
                SELECT  column_id ,
                        column_name ,
                        is_descending_key
                FROM    #nonclus_keys
                WHERE   is_included_column = 0
            OPEN mycursor;
            FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                @col_descending;
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    SELECT  @colstr = ISNULL(@colstr, N'') + @column_name
                            + CASE WHEN @col_descending = 1 THEN '(-)'
                                    ELSE N''
                                END + N', ';
                    FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                        @col_descending;
                END
            CLOSE mycursor;
            DEALLOCATE mycursor;
		
	-- cursor over clus_keys if clustered
            DECLARE mycursor CURSOR
            FOR
                SELECT  column_id ,
                        column_name ,
                        is_descending_key
                FROM    #clus_keys
                WHERE   column_id NOT IN ( SELECT   column_id
                                            FROM     #nonclus_keys
                                            WHERE    is_included_column = 0 )
            OPEN mycursor;
            FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                @col_descending;
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    SELECT  @colstr = ISNULL(@colstr, N'') + @column_name
                            + CASE WHEN @col_descending = 1 THEN '(-)'
                                    ELSE N''
                                END + N', ';
                    FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                        @col_descending;
                END
            CLOSE mycursor;
            DEALLOCATE mycursor;	
		
            SELECT  @ColsInTree = SUBSTRING(@colstr, 1, IIF(LEN(@colstr) - 1<1,1,LEN(@colstr) - 1));
			
	-- find columns not in the nc and not in cl - that are still left to be included.
            DECLARE mycursor CURSOR
            FOR
                SELECT  column_id ,
                        column_name ,
                        is_descending_key
                FROM    #nonclus_keys
                WHERE   column_id NOT IN ( SELECT   column_id
                                            FROM     #clus_keys
                                            UNION
                                            SELECT   column_id
                                            FROM     #nonclus_keys
                                            WHERE    is_included_column = 0 )
                ORDER BY column_name
            OPEN mycursor;
            FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                @col_descending;
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    SELECT  @colstr = ISNULL(@colstr, N'') + @column_name
                            + CASE WHEN @col_descending = 1 THEN '(-)'
                                    ELSE N''
                                END + N', ';
                    FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                        @col_descending;
                END
            CLOSE mycursor;
            DEALLOCATE mycursor;	
		
            SELECT  @ColsInLeaf = SUBSTRING(@colstr, 1, IIF(LEN(@colstr) - 1<1,1,LEN(@colstr) - 1));
		
        END

-- Case 2: unique nonclustered
    ELSE 
        BEGIN
	-- cursor over nonclus_keys that are not includes
            SELECT  @colstr = ''
            DECLARE mycursor CURSOR
            FOR
                SELECT  column_id ,
                        column_name ,
                        is_descending_key
                FROM    #nonclus_keys
                WHERE   is_included_column = 0
            OPEN mycursor;
            FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                @col_descending;
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    SELECT  @colstr = ISNULL(@colstr, N'') + @column_name
                            + CASE WHEN @col_descending = 1 THEN '(-)'
                                    ELSE N''
                                END + N', ';
                    FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                        @col_descending;
                END
            CLOSE mycursor;
            DEALLOCATE mycursor;
		
            SELECT  @ColsInTree = SUBSTRING(@colstr, 1, IIF(LEN(@colstr) - 1<1,1,LEN(@colstr) - 1));
	
	-- start with the @ColsInTree and add remaining columns not present...
            DECLARE mycursor CURSOR
            FOR
                SELECT  column_id ,
                        column_name ,
                        is_descending_key
                FROM    #nonclus_keys
                WHERE   is_included_column = 1;
            OPEN mycursor;
            FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                @col_descending;
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    SELECT  @colstr = ISNULL(@colstr, N'') + @column_name
                            + CASE WHEN @col_descending = 1 THEN '(-)'
                                    ELSE N''
                                END + N', ';
                    FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                        @col_descending;
                END
            CLOSE mycursor;
            DEALLOCATE mycursor;

	-- get remaining clustered column as long as they're not already in the nonclustered
            DECLARE mycursor CURSOR
            FOR
                SELECT  column_id ,
                        column_name ,
                        is_descending_key
                FROM    #clus_keys
                WHERE   column_id NOT IN ( SELECT   column_id
                                            FROM     #nonclus_keys )
                ORDER BY column_name
            OPEN mycursor;
            FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                @col_descending;
            WHILE @@FETCH_STATUS = 0 
                BEGIN
                    SELECT  @colstr = ISNULL(@colstr, N'') + @column_name
                            + CASE WHEN @col_descending = 1 THEN '(-)'
                                    ELSE N''
                                END + N', ';
                    FETCH NEXT FROM mycursor INTO @column_id, @column_name,
                        @col_descending;
                END
            CLOSE mycursor;
            DEALLOCATE mycursor;	

            SELECT  @ColsInLeaf = SUBSTRING(@colstr, 1, IIF(LEN(@colstr) - 1<1,1,LEN(@colstr) - 1));
            SELECT  @colstr = ''
	
        END
-- Cleanup
    DROP TABLE #clus_keys;
    DROP TABLE #nonclus_keys;
	
END