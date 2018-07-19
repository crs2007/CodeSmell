
CREATE FUNCTION dbo.ufn_get_default_path (@log BIT,
        @value_name NVARCHAR(20))
RETURNS NVARCHAR(260)
AS
BEGIN
    DECLARE @instance_name NVARCHAR(200) ,
			@system_instance_name NVARCHAR(200) ,
			@registry_key NVARCHAR(512) ,
			@path NVARCHAR(260) ;

    SET @instance_name = COALESCE(CONVERT(NVARCHAR(20), SERVERPROPERTY('InstanceName')),
                                    'MSSQLSERVER');

-- sql 2005/2008 with instance
    EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',
        N'Software\Microsoft\Microsoft SQL Server\Instance Names\SQL',
        @instance_name, @system_instance_name OUTPUT;
    SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\'
        + @system_instance_name + '\MSSQLServer';

    IF @value_name = N'DefaultData'
	BEGIN
		IF @log = 1
			BEGIN
				SET @value_name = N'DefaultLog';
			END

		EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE', @registry_key,
			@value_name, @path OUTPUT;

		IF @log = 0
			AND @path IS NULL -- sql 2005/2008 default instance
			BEGIN
				SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\'
					+ @system_instance_name + '\Setup';
				EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',
					@registry_key, N'SQLDataRoot', @path OUTPUT;
				SET @path = @path + '\Data';
			END

		IF @path IS NULL -- sql 2000 with instance
			BEGIN
				SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\'
					+ @instance_name + '\MSSQLServer';
				EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',
					@registry_key, @value_name, @path OUTPUT;
			END

		IF @path IS NULL -- sql 2000 default instance
			BEGIN
				SET @registry_key = N'Software\Microsoft\MSSQLServer\MSSQLServer';
				EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',
					@registry_key, @value_name, @path OUTPUT;
			END

		IF @log = 1
			AND @path IS NULL -- fetch the default data path instead.
			BEGIN
				SELECT  @path = dbo.ufn_get_default_path(0,@value_name)
			END

	END
	ELSE
	BEGIN
		SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\' + @instance_name + '\MSSQLServer';
		EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE', @registry_key, @value_name, @path OUTPUT;
	END
    RETURN @path;
END