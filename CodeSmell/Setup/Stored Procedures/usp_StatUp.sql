-- =============================================
-- Author:		Sharon
-- Create date: 27/5/2013
--				13/07/2015 TRUNCATE TABLE History schema
-- Description:	1. Set configure 'clr enabled' to 1.
--				2. Set dbowner to 'sa'.
--				3. Set TRUSTWORTHY to ON.
-- =============================================
CREATE PROCEDURE [Setup].[usp_StatUp] @Help BIT = 0  
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @AdvancedOptions sql_variant,
			@Print NVARCHAR(2048);
	
	IF @Help = 1
	BEGIN
		SET @Print = 'This DB is check validation by 2 options:
1. By stored procedures that you can find your desired validation.
2. By regular expresion of any code object.

For the 1st step you need to fallow those steps:
A. Write SP from the template by - Setup.usp_CreateSPTemplate 
';
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
	    RETURN;
	END

	

	SELECT  @AdvancedOptions = value_in_use
	FROM    sys.configurations
	WHERE	name = 'show advanced options';
	

	IF (@AdvancedOptions = 0)
	BEGIN
		SET @Print = 'Enabled sp_configure advanced options';
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		EXEC sp_configure 'show advanced options',1;
		RECONFIGURE WITH OVERRIDE;
	END
	-- CLR Activation - Part 1
	IF EXISTS(SELECT TOP 1 1 FROM sys.configurations WHERE name = 'clr enabled' AND value = 0)
	BEGIN
		SET @Print = 'Enabled sp_configure clr';
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		EXEC sp_configure 'clr enabled',1
		RECONFIGURE WITH OVERRIDE    
	END

	IF (@AdvancedOptions = 0)
	BEGIN
		SET @Print = 'Disable sp_configure advanced options';
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
		EXEC sp_configure 'show advanced options',0;
		RECONFIGURE WITH OVERRIDE;
	END

	-- CLR Activation - Part 2
	IF NOT EXISTS(SELECT TOP (1) 1 FROM sys.databases D WHERE D.database_id = DB_ID() AND D.owner_sid = 0x01)
	BEGIN
		SET @Print = 'Change database owner to sa';
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
	    EXEC sp_changedbowner 'sa'; -- fix ownerships problems after transfer
	END
	 
	IF EXISTS(SELECT TOP (1) 1 FROM sys.databases D WHERE D.database_id = DB_ID() AND D.is_trustworthy_on = 0)
	BEGIN
		SET @Print = 'Enable database TRUSTWORTHY to on';
		RAISERROR (@Print, 10, 1) WITH NOWAIT;
	    ALTER DATABASE CURRENT SET TRUSTWORTHY ON WITH NO_WAIT;
	END

	-- Clean Log Table
	EXEC [Setup].[usp_CleanUp];
END