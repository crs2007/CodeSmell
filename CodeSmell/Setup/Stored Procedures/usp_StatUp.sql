-- =============================================
-- Author:		Sharon
-- Create date: 27/5/2013
--				13/07/2015 TRUNCATE TABLE History schema
--				02/08/2021 Adds step 5(Job)
-- Description:	1. Set configure 'clr enabled' to 1.
--				2. Set dbowner to 'sa'.
--				3. Set TRUSTWORTHY to ON.
--				4. Clean Log Table
--				5. Create The Cleaning retantion Job
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

	--Create The Cleaning retantion Job
	IF NOT EXISTS (SELECT TOP 1 1 FROM msdb.dbo.sysjobs WHERE name = N'CodeSmell::Cleanup') 
	BEGIN
		DECLARE @Category sysname = N'CodeSmell';
		DECLARE @DatabaseName sysname = DB_NAME();
		DECLARE @jobId BINARY(16);
		DECLARE @schedule_id INT;

		IF NOT EXISTS (SELECT TOP (1) 1 FROM msdb.dbo.syscategories WHERE name=@Category AND category_class=1)
				EXEC msdb..sp_add_category @class=N'JOB', @type=N'LOCAL', @name=@Category;
		EXEC msdb.dbo.sp_add_job @job_name=N'CodeSmell::Cleanup', 
			@enabled=1, 
			@notify_level_eventlog=0, 
			@notify_level_email=0, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Clean old records', 
			@category_name=@Category, 
			@owner_login_name=N'sa', @job_id = @jobId OUTPUT;
		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CleanUp', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=3, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'TSQL', 
				@command=N'Exec History.usp_SetCleanUp;', 
				@database_name=@DatabaseName, 
				@flags=0;
		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Server Object Check', 
				@step_id=2, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'TSQL', 
				@command=N'EXECUTE CodeSmell.Setup.usp_Monitor_CheckServerObject;', 
				@database_name=N'master', 
				@flags=0;
		EXEC msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;
		EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'CodeSmell', 
				@enabled=1, 
				@freq_type=4, 
				@freq_interval=1, 
				@freq_subday_type=1, 
				@freq_subday_interval=0, 
				@freq_relative_interval=0, 
				@freq_recurrence_factor=0, 
				@active_start_date=20190321, 
				@active_end_date=99991231, 
				@active_start_time=200000, 
				@active_end_time=235959, 
				@schedule_id = @schedule_id OUTPUT;
		EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';
	END
END