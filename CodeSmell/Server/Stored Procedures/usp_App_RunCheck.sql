-- =============================================
-- Author:		Sharon
-- Create date: 20/03/2014
-- Description:	Server smell
--{TODO: physical_memory_kb only in 2012}
-- =============================================
CREATE PROCEDURE [Server].[usp_App_RunCheck]
AS
BEGIN
	SET NOCOUNT ON;
	--Cleanup
	DELETE FROM dbo.App_Exeption WHERE MainRunID = -1;

	DECLARE @CPU_Core INT;
	DECLARE @output TABLE ( line VARCHAR(255) );
	DECLARE @sql VARCHAR(400)

	-- Get VLF Counts for all databases on the instance (Query 25) (VLF Counts)
	-- (adapted from Michelle Ufford) 
	CREATE TABLE #VLFInfo (RecoveryUnitID int, FileID  int,
						   FileSize bigint, StartOffset bigint,
						   FSeqNo      bigint, [Status]    bigint,
						   Parity      bigint, CreateLSN   numeric(38));
	 
	CREATE TABLE #VLFCountResults(DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CI_AS, VLFCount int);
	 
	EXEC sp_MSforeachdb N'Use [?]; 

					INSERT INTO #VLFInfo 
					EXEC sp_executesql N''DBCC LOGINFO([?])''; 
	 
					INSERT INTO #VLFCountResults 
					SELECT DB_NAME(), COUNT(*) 
					FROM #VLFInfo; 

					TRUNCATE TABLE #VLFInfo;'
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,DatabaseName,
			'Database' Type,
			'High VLF counts can affect write performance and they can make database restores and recovery take much longer. ' + DatabaseName + '(VLF:' + CONVERT(VARCHAR(10),VLFCount ) + ')' Message,
			'Minor' Severity,
			'Try to keep your VLF counts under 200 in most cases' Action  
	FROM	#VLFCountResults
	WHERE	VLFCount > 200
	ORDER BY VLFCount DESC
	OPTION(RECOMPILE);
	-- High VLF counts can affect write performance 
	-- and they can make database restores and recovery take much longer
	-- Try to keep your VLF counts under 200 in most cases	 
	DROP TABLE #VLFInfo;
	DROP TABLE #VLFCountResults;

	--http://blogs.msdn.com/b/sqlsakthi/archive/2011/03/14/max-worker-threads-and-when-you-should-change-it.aspx
	DECLARE @logicalCPU INT;
	DECLARE @maxWorkerThreads INT;

	SELECT	@maxWorkerThreads = TRY_CONVERT(INT,C.value)
	FROM	sys.configurations C
	WHERE	C.name = 'max worker threads';

	SELECT	@logicalCPU = cpu_count
	FROM	sys.dm_os_sys_info WITH (NOLOCK)
	OPTION(RECOMPILE);
	IF @@Version LIKE '%64-bit%'
	BEGIN
		IF @logicalCPU <= 4
		BEGIN
			IF @maxWorkerThreads NOT IN (0,512)
				INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
				SELECT  -1,@@SERVERNAME ServerName,
						'CPU' Type,
						'Max worker threads:' + CONVERT(VARCHAR(10), @maxWorkerThreads) Message ,
						'http://blogs.msdn.com/b/sqlsakthi/archive/2011/03/14/max-worker-threads-and-when-you-should-change-it.aspx' URL,
						'Major' Severity,
						'Max worker threads shuold be 0 or Total available logical CPU’s <= 4 : 512 On 64bit system' Action 
		END
		ELSE
		BEGIN
			IF @maxWorkerThreads NOT IN (0,256 + ((@logicalCPU - 4) * 16))
				INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
				SELECT  -1,@@SERVERNAME ServerName,
						'CPU' Type,
						'Max worker threads:' + CONVERT(VARCHAR(10), @maxWorkerThreads) Message ,
						'http://blogs.msdn.com/b/sqlsakthi/archive/2011/03/14/max-worker-threads-and-when-you-should-change-it.aspx' URL,
						'Major' Severity,
						'Max worker threads shuold be 0 or Total available logical CPU’s > 4 : 512 + ((logicalCPU - 4) * 16)) On 64bit system' Action 
		END   
	END
	ELSE--32bit
	BEGIN
		IF @logicalCPU <= 4
		BEGIN
			IF @maxWorkerThreads NOT IN (0,256)
				INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
				SELECT  -1,@@SERVERNAME ServerName,
						'CPU' Type,
						'Max worker threads:' + CONVERT(VARCHAR(10), @maxWorkerThreads) Message ,
						'http://blogs.msdn.com/b/sqlsakthi/archive/2011/03/14/max-worker-threads-and-when-you-should-change-it.aspx' URL,
						'Major' Severity,
						'Max worker threads shuold be 0 or Total available logical CPU’s <= 4 : 256 On 32bit system' Action 
		END
		ELSE
		BEGIN
			IF @maxWorkerThreads NOT IN (0,256 + ((@logicalCPU - 4) * 8))
				INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
				SELECT  -1,@@SERVERNAME ServerName,
						'CPU' Type,
						'Max worker threads:' + CONVERT(VARCHAR(10), @maxWorkerThreads) Message ,
						'http://blogs.msdn.com/b/sqlsakthi/archive/2011/03/14/max-worker-threads-and-when-you-should-change-it.aspx' URL,
						'Major' Severity,
						'Max worker threads shuold be 0 or Total available logical CPU’s > 4 : 256 + ((logicalCPU - 4) * 8))On 32bit system' Action 
		END    
	END

	----– SQL Server Error log. This query might take a few seconds
	----– if you have not recycled your error log recently
	--CREATE TABLE #Manufacturer (LogDate DATETIME,ProcessInfo sysname,Text VARCHAR(4000))
	--INSERT #Manufacturer
	--EXEC xp_readerrorlog 0, 1, "Manufacturer";

	--SELECT TOP 1 1 FROM #Manufacturer WHERE Text LIKE '%VMware%'
	IF EXISTS(SELECT TOP(1) 1 FROM sys.dm_os_sys_info WHERE virtual_machine_type = 1) /*HYPERVISOR*/
	BEGIN
		SELECT	@CPU_Core = cpu_count/hyperthread_ratio
		FROM	sys.dm_os_sys_info WITH (NOLOCK);

		INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
		SELECT  -1,@@SERVERNAME ServerName,
				'CPU' Type,
				'CPU resources ratio of the physical cores is 1:' + CONVERT(VARCHAR(10), cpu_count / hyperthread_ratio) Message ,
				'http://www.vmware.com/files/pdf/solutions/SQL_Server_on_VMware-Best_Practices_Guide.pdf' URL,
				'Major' Severity,
				'Provide CPU resources by maintaining a 1:1 ratio of the physical cores' Action 
		FROM	sys.dm_os_sys_info WITH (NOLOCK) 
		WHERE	hyperthread_ratio != 1
				AND cpu_count / hyperthread_ratio > 1
		OPTION(RECOMPILE);
		--INSERT	#Exeption
		--SELECT  @@SERVERNAME ServerName,
		--		'Memory' Type,
		--		'CPU resources ratio of the physical cores is ' + CONVERT(VARCHAR(10),cpu_count/hyperthread_ratio ) + ':' + CONVERT(VARCHAR(10),hyperthread_ratio ) Message,
		--		'http://www.vmware.com/files/pdf/solutions/SQL_Server_on_VMware-Best_Practices_Guide.pdf' URL,
		--		'Major' Severity,
		--		'Provide CPU resources by maintaining a 1:1 ratio of the physical cores' Action 
		--FROM	sys.dm_os_sys_info WITH (NOLOCK) 
		--WHERE	hyperthread_ratio != 1	
		
	
		/*---------------------------------------------------------------------------------------------------
		4.3.4.2. Tier 1 SQL Server workloads 
		Achieving adequate performance is the primary goal. Consider setting the memory reservation equal to 
		the provisioned memory, to avoid ballooning or swapping. When calculating the amount of memory to 
		provision for the virtual machine, use the following formulas: 
		VM Memory = SQL Max Server Memory + ThreadStack + OS Mem + VM Overhead 
		ThreadStack = SQL Max Worker Threads * ThreadStackSize 
		ThreadStackSize	 = 1MB on x86 
						 = 2MB on x64 
						 = 4MB on IA64 
		OS Mem: 1GB for every 4 CPU Cores 

		*/
		DECLARE @OS_Mem FLOAT,
				@ThreadStack INT,
				@vCPU INT,
				@PhysicalMemory INT,
				@VMOverhead INT;

		DECLARE @XPMSVER TABLE ([IDX] [int] NULL
		,[NAME] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		,[INT_VALUE] [float] NULL
		,[C_VALUE] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL);
		INSERT INTO @XPMSVER
		EXEC( 'master.dbo.xp_msver');

		DECLARE @PlatformType INT;
		SELECT	@PlatformType = CASE WHEN C_VALUE LIKE '%x86%' THEN 1
									 WHEN C_VALUE LIKE '%x64%' THEN 2
									 WHEN C_VALUE LIKE '%IA64%' THEN 4
				END
		FROM	@XPMSVER
		WHERE	name = 'Platform'
		OPTION(RECOMPILE);

			--OS Mem: 1GB for every 4 CPU Cores 
			SELECT	@OS_Mem = (cpu_count/hyperthread_ratio)/4.0,
					@vCPU = cpu_count,
					@PhysicalMemory = physical_memory_kb/1024 --MB
			FROM	sys.dm_os_sys_info WITH (NOLOCK)
			OPTION(RECOMPILE);
	
			SELECT	@ThreadStack = max_workers_count * @PlatformType 
			FROM	sys.dm_os_sys_info WITH (NOLOCK);
	
			SELECT	@VMOverhead = mo.Memory_MB
			FROM	[Server].[VM_MemoryOverhead] mo
			WHERE	mo.vCPU = CASE WHEN @vCPU > 8 THEN 8 ELSE @vCPU END
					AND @PhysicalMemory BETWEEN VM_Memory_MB_From AND VM_Memory_MB_Till
			OPTION(RECOMPILE);

			INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
			SELECT  -1,@@SERVERNAME ServerName,
					'Memory' Type,
					'Minimum Memory For This VM is ' + CONVERT(VARCHAR(50),@PhysicalMemory ) + 'MB and does not meet VM requirements: ' + CONVERT(VARCHAR(50),(CONVERT(BIGINT,value)) + @ThreadStack + @OS_Mem + @VMOverhead ) Message,
					'http://www.vmware.com/files/pdf/solutions/SQL_Server_on_VMware-Best_Practices_Guide.pdf' URL,
					'Major' Severity,
					'VM Memory = SQL Max Server Memory + ThreadStack + OS Mem + VM Overhead ' Action 
			FROM	sys.configurations WITH (NOLOCK)
			WHERE	name = 'max server memory (MB)'
					AND (CONVERT(BIGINT,value)) + @ThreadStack + @OS_Mem + @VMOverhead > @PhysicalMemory
					and value != '2147483647'
			OPTION(RECOMPILE);
			---------------------------------------------------------------------------------------------------
	END

	-- Memory
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Memory' Type,
			'Max server memory configure worng ' + CONVERT(varchar(25),C.value) + 'MB. Physical memory: ' + CONVERT(varchar(25),I.physical_memory_kb/1024) + 'MB. You should leave about 10-12% for OS.' Message,
			'Minor' Severity,
			'Configure max server memory' Action 
	FROM	sys.configurations C WITH (NOLOCK)
			CROSS JOIN sys.dm_os_sys_info I WITH (NOLOCK)
			CROSS APPLY (SELECT TOP 1 CASE WHEN value = 1 THEN 0.12 ELSE 0.1 END Factor FROM sys.configurations iC WITH (NOLOCK) WHERE	iC.name = 'clr enabled') uf
	WHERE	C.name = 'max server memory (MB)'
			AND C.value > CONVERT(INT,((I.physical_memory_kb - (CASE WHEN (I.physical_memory_kb * uf.Factor) < 4194304 THEN 4194304.0 ELSE I.physical_memory_kb * uf.Factor END))/1024))
	OPTION(RECOMPILE);
	
	--Average Page Life Expectancy
/*
For those of you not familiar with Page Life Expectancy (PLE), this is the length
of time that a database page will stay in the buffer cache without references. 
Microsoft recommends a minimum target of 300 seconds for PLE, which is roughly (5) minutes.
I have to admit that even in my own environment, we rarely see PLE more than (3) to (4) minutes.
I wondered what would the average DBA do in a situation where they do not have the luxury of using
a 3rd party monitoring tool to capture (PLE)? In this post I decided to share a useful script that
I wrote that will sample the DMV sys.dm_os_performance_counters table to provide an average PLE 
captured in (1) minute intervals. I hope this query will prove useful for those DBA's that do not
have a 3rd party monitoring tool, or find themselves in a situation where they can only rely on 
a query to give them the results.
*/

/****************************************************************************** 
NOTES: 
 This script provides a sampling of PLE based on (1) minute intervals from 
 sys.dm_os_performance_counters. Originally written on December 29, 2012 
 by Akhamie Patrick
*******************************************************************************/ 
DECLARE @counter INT --This will be used to iterate the sampling loop for the PLE measure. 
SET @counter = 0 
DECLARE @pleSample TABLE 
    (
      CaptureTime DATETIME ,
      PageLifeExpectancy BIGINT
    );
WHILE @counter < 30 --Sampling will run approximately 1 minute. 
BEGIN 
--Captures Page Life Expectancy from sys.dm_os_performance_counters 
    INSERT @pleSample(CaptureTime, PageLifeExpectancy)
    SELECT  CURRENT_TIMESTAMP ,
            cntr_value
    FROM    sys.dm_os_performance_counters
    WHERE   [object_name] = N'SQLServer:Buffer Manager'
            AND counter_name = N'Page life expectancy'
	OPTION(RECOMPILE);
    SET @counter = @counter + 1 
    WAITFOR DELAY '00:00:00.2';
END 

DECLARE @PLE TABLE([AveragePageLifeExpectancy] BIGINT);
--This query will return the average PLE based on a 1 minute sample. 
INSERT @PLE(AveragePageLifeExpectancy)
SELECT  AVG(PageLifeExpectancy) AS [AveragePageLifeExpectancy]
FROM    @pleSample 
IF OBJECT_ID('tempdb..#pleSample') IS NOT NULL DROP TABLE #pleSample

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName ,
			'Memory' Type ,
			'Page life expectancy(PLE) is to low - '
			+ CONVERT(VARCHAR(25), [AveragePageLifeExpectancy]) + 'sec. Physical memory: '
			+ CONVERT(VARCHAR(25), @PhysicalMemory) + 'MB' Message ,
			'Minor' Severity ,
			'PLE is a good measurement of memory pressure. Higher PLE is better. Watch the trend, not the absolute value.' Action 
	FROM    @PLE
			CROSS APPLY (	SELECT	CONVERT(INT,CASE WHEN CONVERT(INT,C.value)/1024.0 < (I.physical_memory_kb/1024.0/1024.0) THEN ((CONVERT(INT,C.value)/1024.0)/4) * 300 ELSE ((I.physical_memory_kb/1024.0/1024.0)/4) * 300 END )PLEvalue
								FROM	sys.configurations C WITH (NOLOCK) CROSS JOIN sys.dm_os_sys_info I WITH (NOLOCK)
								WHERE	C.name = 'max server memory (MB)')T
	WHERE   [AveragePageLifeExpectancy] < t.PLEvalue -- Seconds
	OPTION (RECOMPILE);

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Memory' Type,
			'"MAX_EVENTS_LIMIT" on XE is set to high(' + CONVERT(VARCHAR(15),ring_buffer_event_count)+ ')' Message,
			'http://www.sqlskills.com/blogs/jonathan/why-i-hate-the-ring_buffer-target-in-extended-events/?utm_source=rss&utm_medium=rss&utm_campaign=why-i-hate-the-ring_buffer-target-in-extended-events' URL,
			'Major' Severity,
			'Set "MAX_EVENTS_LIMIT" to less than ' + CONVERT(VARCHAR(15),ring_buffer_event_count) Action 
	FROM    ( SELECT    target_data.value('(RingBufferTarget/@eventCount)[1]',
										  'int') AS ring_buffer_event_count ,
						target_data.value('count(RingBufferTarget/event)', 'int') AS event_node_count
			  FROM      ( SELECT    CAST(target_data AS XML) AS target_data
						  FROM      sys.dm_xe_sessions AS s
									INNER JOIN sys.dm_xe_session_targets AS st ON s.address = st.event_session_address
						  WHERE     s.name = N'system_health'
									AND st.target_name = N'ring_buffer'
						) AS n
			) AS t
	WHERE	ring_buffer_event_count > 10000 -- MAX_EVENTS_LIMIT
	OPTION (RECOMPILE);


----------------------------- Server ---------------------------------
	--Service
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1 MainRunID,@@SERVERNAME ServerName,
			'Server' Type,
			servicename + ' startup state: ' + startup_type_desc Message,
			'Major' Severity,
			'Change service startup methud to Automatic' ACTION
	FROM    sys.dm_server_services WITH ( NOLOCK )
	WHERE   servicename LIKE 'SQL Server%'
			AND startup_type != 2 --Automatic
	UNION ALL 
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			servicename + ' is in state: ' + status_desc Message,
			'Major' Severity,
			'Start Service' Action 
	FROM    sys.dm_server_services WITH ( NOLOCK )
	WHERE   servicename LIKE 'SQL Server%'
			AND status != 4 --Running
	UNION ALL 
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			servicename + ' service account is differnt from agent service' Message,
			'Major' Severity,
			'Change Service account of agent service to ' + s.service_account Action 
	FROM    sys.dm_server_services s WITH ( NOLOCK )
			CROSS JOIN (SELECT	service_account
			            FROM	sys.dm_server_services WITH ( NOLOCK )
						WHERE   servicename LIKE 'SQL Server Agent%') t
	WHERE   servicename LIKE 'SQL Server (%'
			AND t.service_account != s.service_account
	OPTION  ( RECOMPILE );
	
	--configurations
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			CONVERT(varchar(40),C.Name) + ' configure worng ' Message,
			'Worning' Severity,
			'Turn on - ' + CONVERT(varchar(25),C.Name) Action 
	FROM	sys.configurations C WITH (NOLOCK)
	WHERE	C.name IN ('optimize for ad hoc workloads','backup compression default')
			AND C.value = 0
	OPTION  ( RECOMPILE );

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT	-1,@@SERVERNAME ServerName,
			'Server' Type,
			CONVERT(varchar(40),C.Name) + ' value(' + CONVERT(varchar(25),C.value) + ') !=  value_in_use(' + CONVERT(varchar(25),C.value_in_use) + ')' Message,
			'Worning' Severity,
			'Turn on - ' + CONVERT(varchar(25),C.Name) Action 
	FROM	sys.configurations C
	WHERE	C.value != C.value_in_use
	OPTION(RECOMPILE);
	--IF @@VERSION LIKE '%Microsoft SQL Server 2014%'
	--EXEC ('INSERT	#Exeption
	--SELECT	@@SERVERNAME ServerName,
	--		''Server'' Type,
	--		CONVERT(varchar(40),C.Name) + '' value('' + CONVERT(varchar(25),C.value) + '') !=  value_in_use('' + CONVERT(varchar(25),C.value_in_use) + '')'' Message,
	--		NULL URL,
	--		''Worning'' Severity,
	--		''Turn on - '' + CONVERT(varchar(25),C.Name) Action 
	--FROM	sys.configurations C
	--WHERE	C.value != C.value_in_use;');
-------------------------------------------------------------------------------------------
/*********************************
  FIND WEAK PASSWORDS SCRIPT
--Author: Shimon Gibraltar
--Email: shimongb@gmail.com
*********************************/
DECLARE @syslogin TABLE(NAME sysname COLLATE SQL_Latin1_General_CP1_CI_AS,Header VARBINARY(4),Salt VARBINARY(4),password_hash VARBINARY(256));
--Collect sql logins data
INSERT @syslogin(NAME, Header, Salt, password_hash)
SELECT  NAME  COLLATE SQL_Latin1_General_CP1_CI_AS [NAME],
        SUBSTRING(password_hash, 0, 3) Header ,
        CONVERT(VARBINARY(4), SUBSTRING(CONVERT(NVARCHAR(MAX), password_hash),2, 2)) Salt ,
        password_hash
FROM    sys.sql_logins WITH (NOLOCK)
OPTION(RECOMPILE);

--define the crypto algoritms to check
DECLARE @alg TABLE(Algoritm NVARCHAR(10) NOT NULL)
INSERT  @alg( Algoritm )
VALUES  --( 'MD2' ),( 'MD4' ),( 'MD5' ), -- Only for 2005 todo
( 'SHA' ),( 'SHA1' ),( 'SHA2_256' ),( 'SHA2_512' );

-->>> ••••• and this is where the magic happens! ••••• <<<---
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT	DISTINCT -1,
			@@SERVERNAME ServerName,
			'Server' Type,
			'Login ' + t.NAME + ' has a weak password.' Message,
			'Worning' Severity,
			'Change password for login - ' + t.Name Action 
        --t.Name ,
        --t.Algoritm ,
        --t.ClearTextPassword ,
        --t.OriginalPasswordHash ,
        --t.salt
	FROM    ( SELECT    SL.NAME ,
						a.Algoritm ,
						P.[Password] ClearTextPassword ,
						sl.password_hash OriginalPasswordHash ,
						sl.Header + sl.Salt + HASHBYTES(A.Algoritm,
														P.[Password]
														+ CONVERT(NVARCHAR(MAX), sl.Salt)) MyHashedPassword ,
						CONVERT(VARBINARY(4), SUBSTRING(CONVERT(NVARCHAR(MAX), sl.password_hash),
														2, 2)) salt
			  FROM      @syslogin SL
						CROSS JOIN @alg A
						CROSS JOIN (SELECT	[Password]
									FROM	[Server].[Passwords] P 
									UNION ALL 
									SELECT	name  [Password]
									FROM	@syslogin
									)P
			) t
	WHERE   t.MyHashedPassword = t.OriginalPasswordHash;
-------------------------------------------------------------------------------------------

	
	--TempDB Configuration
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT  TOP (1) -1,
			@@SERVERNAME ServerName,
			'Server' Type,
			'TempDB files has different sizes' Message,
			'http://www.confio.com/logicalread/sql-server-tempdb-best-practices-initial-sizing-w01/#.UzEbJfl_tCw' URL,
			'Worning' Severity,
			'Change initial size of tempdb' ACTION
	FROM	sys.master_files MF WITH (NOLOCK) 
			CROSS APPLY (SELECT TOP 1 size,file_id FROM sys.master_files WITH (NOLOCK) WHERE database_id = 2 AND type = 0)iMF
	WHERE	database_id = 2
			AND type = 0
			AND iMF.file_id != MF.file_id
			AND iMF.size != MF.size
	UNION ALL 
	SELECT  TOP (1) -1,
			@@SERVERNAME ServerName,
			'Server' Type,
			'TempDB files are lower then logical CPU count' Message,
			'http://www.confio.com/logicalread/sql-server-tempdb-best-practices-multiple-files-w01/#.UzEbCfl_tCw' URL,
			'Worning' Severity,
			'Use of multiple data files of tempdb' ACTION
	FROM	sys.dm_os_sys_info WITH (NOLOCK) 
			CROSS APPLY (SELECT	COUNT_BIG(1) TempDBcnt FROM	sys.master_files WITH (NOLOCK) WHERE	database_id = 2 AND type = 0) Tmp
	WHERE	cpu_count > Tmp.TempDBcnt

	DECLARE @xp_cmdshell_output TABLE(Output VARCHAR (8000));
	INSERT INTO @xp_cmdshell_output EXEC ('xp_cmdshell "whoami /priv"');

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			'Instant Initialization disabled' Message,
			N'http://www.sqlskills.com/blogs/kimberly/instant-initialization-what-why-and-how/' URL,
			'Worning' Severity,
			'Activate Instant Initialization'  Action 
	WHERE	NOT EXISTS (SELECT * FROM @xp_cmdshell_output WHERE Output LIKE '%SeManageVolumePrivilege%' and Output LIKE '%Enabled%')

	-- Sustained values above 10 suggest further investigation in that area
	-- High Avg Task Counts are often caused by blocking or other resource contention
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			'Avg Task Count ' + CONVERT(varchar(25),AVG(current_tasks_count)) Message,
			'Worning' Severity,
			'High Avg Task Counts are often caused by blocking or other resource contention'  Action 
	FROM    sys.dm_os_schedulers WITH ( NOLOCK )
	WHERE   scheduler_id < 255
	HAVING AVG(current_tasks_count) > 10
	UNION ALL 
	-- High Avg Runnable Task Counts are a good sign of CPU pressure
	SELECT  -1,@@SERVERNAME ServerName,
			'CPU' Type,
			'Avg Runnable Task Count ' + CONVERT(varchar(25),AVG(runnable_tasks_count)) Message,
			'Worning' Severity,
			'High Avg Runnable Task Counts are a good sign of CPU pressure'  Action 
	FROM    sys.dm_os_schedulers WITH ( NOLOCK )
	WHERE   scheduler_id < 255
	HAVING AVG(runnable_tasks_count) > 10
	UNION ALL 
	-- High Avg Pending DiskIO Counts are a sign of disk pressure
	SELECT  -1,@@SERVERNAME ServerName,
			'CPU' Type,
			'Avg Pending DiskIO Count ' + CONVERT(varchar(25),AVG(pending_disk_io_count)) Message,
			'Worning' Severity,
			'High Avg Pending DiskIO Counts are a sign of disk pressure'  Action 
	FROM    sys.dm_os_schedulers WITH ( NOLOCK )
	WHERE   scheduler_id < 255
	HAVING AVG(pending_disk_io_count) > 10
	-- High Avg Pending DiskIO Counts are a sign of disk pressure
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'LinkedServer' Type,
			'The LinkedServer is configured to work with IP address. On DR based IP This will not work automaticly.' Message,
			'Worning' Severity,
			'Change IP connection to Name based'  Action 
	FROM    sys.servers
	WHERE	[dbo].[ufn_Util_clr_RegexIsMatch] (data_source,'^\d*\.\d*\.\d*\.\d*',0) = 1
	OPTION  ( RECOMPILE );
	----------------------------------------  TraceFlags  ----------------------------------------
    DECLARE @TraceStatus TABLE
    (
        TraceFlag VARCHAR(10) COLLATE SQL_Latin1_General_CP1_CI_AS,
        status BIT ,
        Global BIT ,
        Session BIT
    );
    INSERT @TraceStatus EXEC ( ' DBCC TRACESTATUS(-1) WITH NO_INFOMSGS')
	----------------------------------------  TraceFlags  ----------------------------------------
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			TS.Name Message,
			'Minor' Severity,
			'Turn Trace flag on' Action 
	FROM	(SELECT 'Is TF 1118(Immediately allocate an extent (8 pages)) On' Name,'1118' value --http://www.sqlskills.com/blogs/paul/misconceptions-around-tf-1118/
			UNION ALL 
			SELECT 'Is TF 1222(More info about deadlock) On' Name,'1222' value
			UNION ALL 
			SELECT 'Is TF 3226(Suppress the success messages from backups) On' Name,'3226' value
			UNION ALL 
			SELECT 'Is TF 3023(BACKUP WITH CHECKSUM) On' Name,'3023' value --http://www.sqlservercentral.com/blogs/nebraska-sql-from-dba_andy/2014/03/25/backup-checksums-and-trace-flag-3023/
			UNION ALL 
			SELECT 'Is TF 4199 (Turn on all optimizations) On' Name,'4199' value
			UNION ALL 
			SELECT 'Is TF 2453 (Fix optimizer on table variable row est) On' Name,'2453' value WHERE SERVERPROPERTY('ProductVersion') >= '11.0.5058' -- Applay only for 2012 SP2 & above
			) TS
			LEFT JOIN @TraceStatus GTS ON GTS.TraceFlag = TS.value
	WHERE	GTS.TraceFlag IS NULL;
	
	--Error Log file
	DECLARE @NumErrorLogs INT;
	EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',
		N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs',
		@NumErrorLogs OUTPUT;

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  -1,@@SERVERNAME ServerName,
			'Server' Type,
			'Number of Error Logs is -' + CONVERT(VARCHAR(10),ISNULL(@NumErrorLogs, -1))+ '. Change to 30 or more.' Message,
			'Minor' Severity,
			'/*Configure SQL Server Error Logs*/USE [master]
GO
EXEC xp_instance_regwrite N''HKEY_LOCAL_MACHINE'',
    N''Software\Microsoft\MSSQLServer\MSSQLServer'', N''NumErrorLogs'', REG_DWORD,
    30
GO' Action 
	WHERE	ISNULL(@NumErrorLogs, -1) < 30;

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity)
	SELECT  -1,@@SERVERNAME ServerName,
			'JOB' Type,
			'JobName: ' + JobName + ' That run on ' + CONVERT(VARCHAR(25),RunDateTime) + ' took - ' + CONVERT(VARCHAR(25),RunDurationMinutes) + ' minutes' Message,
			'Minor' Severity
	FROM	(SELECT  j.name AS 'JobName' ,
					rdm.RunDateTime,
					rdm.RunDurationMinutes,
					ROW_NUMBER() OVER (PARTITION BY j.name ORDER BY rdm.RunDateTime DESC) RN
			FROM    msdb.dbo.sysjobs j
					INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
					CROSS APPLY (SELECT msdb.dbo.agent_datetime(run_date, run_time) AS 'RunDateTime',( ( h.run_duration / 10000 * 3600 + ( h.run_duration / 100 ) % 100 * 60
						+ run_duration % 100 + 31 ) / 60 ) RunDurationMinutes)rdm
			WHERE   j.enabled = 1  --Only Enabled Jobs
					AND rdm.RunDateTime > DATEADD(DAY,-3,GETDATE())
					AND rdm.RunDurationMinutes > 55)t
	WHERE	T.RN = 1;

	-- Storage
	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT	-1,@@SERVERNAME ServerName,
			'Storage' Type,
			'Reads are averaging longer than ' + CASE Type WHEN 1 THEN '10' WHEN 99 THEN '10' ELSE '20' END + 'ms on drive - ' + [Drive] + CASE Type WHEN 1 THEN '(LOG files)' WHEN 99 THEN '(TempDB)' ELSE '(DATA files)' END + ' - ' + CONVERT(VARCHAR(20),RL.[Read Latency]) Message,
			'http://technet.microsoft.com/en-us/library/aa995945(v=exchg.80).aspx' URL,
			'Major' Severity,
						CASE Type WHEN 1 THEN 
			'Transaction log drives
The drive that hosts the transaction log should have average write latencies below 10 ms. Spikes in write latencies should be under 50ms. Writes to the transaction log are synchronous. This means that, before a thread in the Store.exe process can perform another task, the thread must wait for the write to complete. Having low write latencies for the transaction logs is important to server performance. The average Read latency to the transaction log drives should be below 20 ms. Spikes in read latency should be under 50ms. Database Log Record Stalls per second should be less than 10. Database Log Threads Waiting should be less than 10.
Ordinarily, Exchange servers do not read from the transaction logs. Therefore, the read latencies to that drive do not matter. However, because the transaction log write latencies are so important to Exchange performance, it is recommended that, on large servers, you do not use the drives that host transaction logs for any other purpose. In this case, the rate of reads (as measured by LogicalDisk\Disk Reads/sec) should be minimal compared to the rate of writes (LogicalDisk\Disk Writes/sec). The Exchange Server Analyzer will detect if the ratio of reads to writes on the transaction log drive is greater than 0.10 (more than one read for every ten writes).
If there are more than 0.10 reads for every write, you should identify which application is reading from the transaction log drive, and then prevent this action from occurring.' 
			WHEN 99 THEN 
'TEMP and TMP drives   The latency for the drives that contain the TEMP and TMP directories should have read and write latencies below 10 ms. The maximum value for the read or write latency should be below 50 ms.' 
			ELSE 
			'Database drives
The acceptable latency for the drives that contain Exchange database files ( *edb, and *stm files) are as below (higher values indicate a disk bottleneck):
The maximum value for Logical Disk\Avg. Disk sec/Read on a database drive should be less than 50 ms. (0.050 seconds)
The average value for Logical Disk\Avg. Disk sec/Read on a database drive should be less than 20 ms. (0.020 seconds)' 
			END + '
---------------------------------------------------------------------------------------------------------------------------------------
If you are running a RAID-5 disk array, you may want to change to a RAID-10 disk array to improve the available supported IOPS of the disk subsystem.
To improve the available supported IOPS, consider adding additional disks to your disk system.
' Action
	FROM    ( SELECT    LEFT(mf.physical_name, 2) AS Drive ,CASE WHEN MF.database_id = 2  THEN 99 ELSE MF.type END [type],
						SUM(num_of_reads) AS num_of_reads ,
						SUM(io_stall_read_ms) AS io_stall_read_ms ,
						SUM(num_of_writes) AS num_of_writes ,
						SUM(io_stall_write_ms) AS io_stall_write_ms ,
						SUM(num_of_bytes_read) AS num_of_bytes_read ,
						SUM(num_of_bytes_written) AS num_of_bytes_written ,
						SUM(io_stall) AS io_stall
			  FROM      sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
						INNER JOIN sys.master_files AS mf WITH ( NOLOCK ) ON vfs.database_id = mf.database_id
									AND vfs.file_id = mf.file_id
			  WHERE		MF.database_id NOT IN (1,3,4) -- Master,MSDB,Model
			  GROUP BY  LEFT(mf.physical_name, 2),CASE WHEN MF.database_id = 2  THEN 99 ELSE MF.type END
			) AS tab
			CROSS APPLY (SELECT 
				CASE WHEN num_of_reads = 0 THEN 0 ELSE ( io_stall_read_ms / num_of_reads ) END AS [Read Latency],
				CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE ( io_stall_write_ms / num_of_writes ) END AS [Write Latency] , 
				CASE WHEN ( num_of_reads = 0 AND num_of_writes = 0 ) THEN 0 ELSE ( io_stall / ( num_of_reads + num_of_writes ) ) END AS [Overall Latency] ,
				CASE WHEN num_of_reads = 0 THEN 0 ELSE ( num_of_bytes_read / num_of_reads ) END AS [Avg Bytes/Read] ,
				CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE ( num_of_bytes_written / num_of_writes ) END AS [Avg Bytes/Write] ,
				CASE WHEN ( num_of_reads = 0 AND num_of_writes = 0 ) THEN 0 ELSE ( ( num_of_bytes_read + num_of_bytes_written ) / ( num_of_reads + num_of_writes ) ) END AS [Avg Bytes/Transfer])RL

	WHERE	(tab.type IN (1,99) AND RL.[Read Latency] > 10)
			OR
			(tab.type != 1 AND RL.[Read Latency] > 20)
	UNION ALL 
	SELECT	-1,@@SERVERNAME ServerName,
			'Storage' Type,
			'Writes are averaging longer than ' + CASE Type WHEN 1 THEN '10' WHEN 99 THEN '10' ELSE '20' END + 'ms on drive - ' + [Drive] + CASE Type WHEN 1 THEN '(LOG files)' WHEN 99 THEN '(TempDB)' ELSE '(DATA files)' END + ' - ' + CONVERT(VARCHAR(20),RL.[Write Latency]) Message,
			'http://technet.microsoft.com/en-us/library/aa995945(v=exchg.80).aspx' URL,
			'Major' Severity,
			CASE Type WHEN 1 THEN 
			'Transaction log drives
The drive that hosts the transaction log should have average write latencies below 10 ms. Spikes in write latencies should be under 50ms. Writes to the transaction log are synchronous. This means that, before a thread in the Store.exe process can perform another task, the thread must wait for the write to complete. Having low write latencies for the transaction logs is important to server performance. The average Read latency to the transaction log drives should be below 20 ms. Spikes in read latency should be under 50ms. Database Log Record Stalls per second should be less than 10. Database Log Threads Waiting should be less than 10.
Ordinarily, Exchange servers do not read from the transaction logs. Therefore, the read latencies to that drive do not matter. However, because the transaction log write latencies are so important to Exchange performance, it is recommended that, on large servers, you do not use the drives that host transaction logs for any other purpose. In this case, the rate of reads (as measured by LogicalDisk\Disk Reads/sec) should be minimal compared to the rate of writes (LogicalDisk\Disk Writes/sec). The Exchange Server Analyzer will detect if the ratio of reads to writes on the transaction log drive is greater than 0.10 (more than one read for every ten writes).
If there are more than 0.10 reads for every write, you should identify which application is reading from the transaction log drive, and then prevent this action from occurring.' 
			WHEN 99 THEN 
'TEMP and TMP drives   The latency for the drives that contain the TEMP and TMP directories should have read and write latencies below 10 ms. The maximum value for the read or write latency should be below 50 ms.' 
			ELSE 
			'Database drives
The acceptable latency for the drives that contain Exchange database files ( *edb, and *stm files) are as below (higher values indicate a disk bottleneck):
The maximum value for Logical Disk\Avg. Disk sec/Read on a database drive should be less than 50 ms. (0.050 seconds)
The average value for Logical Disk\Avg. Disk sec/Read on a database drive should be less than 20 ms. (0.020 seconds)' 
			END + '
---------------------------------------------------------------------------------------------------------------------------------------
If you are running a RAID-5 disk array, you may want to change to a RAID-10 disk array to improve the available supported IOPS of the disk subsystem.
To improve the available supported IOPS, consider adding additional disks to your disk system.
' Action
	FROM    ( SELECT    LEFT(mf.physical_name, 2) AS Drive ,CASE WHEN MF.database_id = 2  THEN 99 ELSE MF.type END [type],
						SUM(num_of_reads) AS num_of_reads ,
						SUM(io_stall_read_ms) AS io_stall_read_ms ,
						SUM(num_of_writes) AS num_of_writes ,
						SUM(io_stall_write_ms) AS io_stall_write_ms ,
						SUM(num_of_bytes_read) AS num_of_bytes_read ,
						SUM(num_of_bytes_written) AS num_of_bytes_written ,
						SUM(io_stall) AS io_stall
			  FROM      sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
						INNER JOIN sys.master_files AS mf WITH ( NOLOCK ) ON vfs.database_id = mf.database_id
													AND vfs.file_id = mf.file_id
			  WHERE		MF.database_id NOT IN (1,3,4) -- Master,MSDB,Model
			  GROUP BY  LEFT(mf.physical_name, 2),CASE WHEN MF.database_id = 2  THEN 99 ELSE MF.type END
			) AS tab
			CROSS APPLY (SELECT 
				CASE WHEN num_of_reads = 0 THEN 0 ELSE ( io_stall_read_ms / num_of_reads ) END AS [Read Latency],
				CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE ( io_stall_write_ms / num_of_writes ) END AS [Write Latency] , 
				CASE WHEN ( num_of_reads = 0 AND num_of_writes = 0 ) THEN 0 ELSE ( io_stall / ( num_of_reads + num_of_writes ) ) END AS [Overall Latency] ,
				CASE WHEN num_of_reads = 0 THEN 0 ELSE ( num_of_bytes_read / num_of_reads ) END AS [Avg Bytes/Read] ,
				CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE ( num_of_bytes_written / num_of_writes ) END AS [Avg Bytes/Write] ,
				CASE WHEN ( num_of_reads = 0 AND num_of_writes = 0 ) THEN 0 ELSE ( ( num_of_bytes_read + num_of_bytes_written ) / ( num_of_reads + num_of_writes ) ) END AS [Avg Bytes/Transfer])RL

	WHERE	(tab.type IN (1,99) AND RL.[Write Latency] > 10)
			OR
			(tab.type != 1 AND RL.[Write Latency] > 20)
	OPTION  ( RECOMPILE );

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message, Severity, Action)
	SELECT  DISTINCT
			-1, @@SERVERNAME ServerName,
			'Storage' Type,
			vs.volume_mount_point + ' has ' + CAST(CAST(vs.available_bytes AS FLOAT) / CAST(vs.total_bytes AS FLOAT)  * 100 AS VARCHAR(50)) + '% free space.' Message,
			'Minor' Severity,
			'Check what files located in ' + vs.volume_mount_point Action 
	FROM    sys.master_files AS f WITH ( NOLOCK )
			CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs
	WHERE	CAST(CAST(vs.available_bytes AS FLOAT) / CAST(vs.total_bytes AS FLOAT) AS DECIMAL(18,2)) < 0.1
	OPTION  ( RECOMPILE );

	--Your SQL Data and Log Drives Need a 1024Kb Starting offset, and a 64Kb Block Size
	/*
	so there’s only one disk (Disk #0). You’re only interested in the Partition #0 for each disk, because that’s the partition at the start of the disk (which contains the partition offset). My laptop has a proper starting offset: 1048576 bytes = 1048576/1024 = 1024KB.
	*/
	DECLARE @PS VARCHAR(4000) = 'powershell.exe "get-wmiobject win32_diskpartition | select name, startingoffset | foreach{$_.name+''|''+$_.startingoffset/1024+''*''}"'

	BEGIN TRY 
		INSERT  @output 
		EXEC xp_cmdshell @PS;
	END TRY
	BEGIN CATCH
		--{TODO: }
	END CATCH

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT	-1,@@SERVERNAME ServerName,
			'Storage' Type,
			'"Starting Offset" on ' + RTRIM(LTRIM(SUBSTRING(line, 1, CHARINDEX('|', line) - 1))) + ' is - ' + SO.StartingOffset + 'Kb' Message,
			'http://technet.microsoft.com/en-us/library/cc966412.aspx
http://www.midnightdba.com/Jen/2014/04/decree-set-your-partition-offset-and-block-size-make-sql-server-faster/' URL,
			'Minor' Severity,
			'Ask your SAN guy to change the drive "Starting Offset" to 1024Kb' Action
	FROM    @output
			CROSS APPLY (SELECT TOP 1 RTRIM(LTRIM(SUBSTRING(line, CHARINDEX('|', line) + 1,
									( CHARINDEX('*', line) - 1)
									- CHARINDEX('|', line)))) AS [StartingOffset]) SO
	WHERE	line IS NOT NULL
			AND line LIKE '%Partition #0%'
			AND SO.StartingOffset != '1024'
	ORDER BY 1;
	
	--64kb Block Size
	DECLARE @cmd NVARCHAR(max) = ''
	SELECT	 @cmd +=  '
INSERT  @output 
exec master..xp_cmdshell ''echo 1 > ' + t.physical_name + ':\TestFile.txt''
INSERT  @output 
exec master..xp_cmdshell ''dir ' + t.physical_name + ':\TestFile.txt''

SELECT	@BlockSize = REPLACE(REPLACE(SUBSTRING(line,charINDEX('')'',line)+1,LEN(line)-5),'' '',''''),''bytes'','''')
FROM	@output
WHERE	line LIKE ''%1 File%''

INSERT  @output 
exec master..xp_cmdshell ''del ' + t.physical_name + ':\TestFile.txt''

INSERT	[' + DB_NAME() + '].dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
SELECT	-1,@@SERVERNAME ServerName,
		''Storage'' Type,
		''The block size on drive:' + t.physical_name + ':\ is '' + CONVERT(VARCHAR(25),@BlockSize) + ''kb.'' Message,
		''http://technet.microsoft.com/en-us/library/cc966412.aspx
http://www.midnightdba.com/Jen/2014/04/decree-set-your-partition-offset-and-block-size-make-sql-server-faster/'' URL,
		''Minor'' Severity,
		''Ask your System guy to change the block size from '' + CONVERT(VARCHAR(25),@BlockSize) + ''kb to 64kb FOR all your data and log files on drive:' + t.physical_name + ''' Action
WHERE	@BlockSize < 64;
DELETE FROM @output;
'
	FROM	(SELECT	DISTINCT SUBSTRING(physical_name,1,1) physical_name
    		 FROM	sys.master_files WITH (NOLOCK))t

	SELECT @cmd = '
DECLARE @output TABLE ( line VARCHAR(255) );
DECLARE @BlockSize INT

' + @cmd;
	BEGIN TRY 
		EXECUTE sys.sp_executesql @cmd;
	END TRY
	BEGIN CATCH
	END CATCH
		--Block Size
	SET @sql = 'wmic volume GET Caption, BlockSize'--inserting disk name, total space and free space value in to temporary table
	BEGIN TRY 
		INSERT  @output
		EXEC xp_cmdshell @sql;

		DELETE FROM @output
		WHERE	LINE IS NULL
				OR line IN ('
','BlockSize  Caption                                            
');

		DECLARE @DriveLeter TABLE (DriveLeter CHAR(3) NOT NULL);

		INSERT	@DriveLeter(DriveLeter)
		SELECT	DISTINCT LEFT(MF.physical_name,3) 
		FROM	sys.master_files MF
		WHERE	MF.type = 0;


		--SELECT	DL.DriveLeter, RTRIM(LTRIM(REPLACE(O.line,DL.DriveLeter,'')))[BlockSize]
		--FROM	@DriveLeter DL
		--		LEFT JOIN @output O ON  o.line LIKE '%' + DL.DriveLeter + '%'
		--WHERE	RTRIM(LTRIM(REPLACE(O.line,DL.DriveLeter,''))) NOT LIKE '%65536%';


		INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
		SELECT	-1,@@SERVERNAME ServerName,
				'Storage' Type,
				'The block size on drive:' + DL.DriveLeter + ' is ' + RTRIM(LTRIM(REPLACE(O.line,DL.DriveLeter,''))) + 'kb.' Message,
				'http://technet.microsoft.com/en-us/library/cc966412.aspx
http://www.midnightdba.com/Jen/2014/04/decree-set-your-partition-offset-and-block-size-make-sql-server-faster/' URL,
				'Minor' Severity,
				'Ask your System guy to change the block size from ' + RTRIM(LTRIM(REPLACE(O.line,DL.DriveLeter,''))) + 'kb to 64kb FOR all your data and log files on drive:' + DL.DriveLeter + '' Action
		FROM	@DriveLeter DL
				LEFT JOIN @output O ON  o.line LIKE '%' + DL.DriveLeter + '%'
		WHERE	RTRIM(LTRIM(REPLACE(O.line,DL.DriveLeter,''))) NOT LIKE '%65536%';
	END TRY
	BEGIN CATCH
	
	
	
	END CATCH
	----------------------------------------------
	--cleanUP
	DELETE FROM @output;
	----------------------------------------------
	--All you’re looking for is Bytes Per Cluster. On my laptop, it’s 4096 bytes. Hey, I don’t have dedicated SQL drives on here. 
	--But what you want to see is Bytes Per Cluster : 65536.  Again, that’s 65536 bytes / 1024 = 64KB, 
	--which is what you want for the disks that will hold SQL data and log files.
	DECLARE @svrName VARCHAR(255);
	--DECLARE @sql VARCHAR(400)
	--by default it will take the current server name, we can the set the server name as well
	SET @svrName = @@SERVERNAME
	SET @sql = 'powershell.exe -c "Get-WmiObject -ComputerName '
		+ QUOTENAME(@svrName, '''')
		+ ' -Class Win32_Volume -Filter ''DriveType = 3'' | select name,Label,BlockSize | foreach{$_.name+''|''+$_.label+''^''+$_.BlockSize/1024+''*''}"'
		
	--inserting disk name, total space and free space value in to temporary table
	BEGIN TRY 
		INSERT  @output
		EXEC xp_cmdshell @sql
	END TRY
	BEGIN CATCH
		--{TODO: }
	END CATCH

	DECLARE @DISKS TABLE
		(
			id INT IDENTITY ,
			[DiskName] VARCHAR(10) ,
			[Label] VARCHAR(200),
			[BlockSize] VARCHAR(200)
		);

	INSERT  @DISKS(DiskName, Label, BlockSize)
	SELECT  RTRIM(LTRIM(SUBSTRING(line, 1, CHARINDEX('|', line) - 1))) AS drivename ,
			RTRIM(LTRIM(SUBSTRING(line, CHARINDEX('&', line) + 1,
									( CHARINDEX('^', line) - 1 )
									- CHARINDEX('&', line)))) AS 'Label',
			RTRIM(LTRIM(SUBSTRING(line, CHARINDEX('^', line) + 1,
									( CHARINDEX('*', line) - 1)
									- CHARINDEX('^', line)))) AS [BlockSize]
	FROM    @output
	WHERE   line LIKE '[A-Z][:]%'
	ORDER BY drivename;

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT	-1,@@SERVERNAME ServerName,
			'Storage' Type,
			'"Block Size" on ' + DiskName + ' is - ' + [BlockSize] + 'Kb' Message,
			'http://technet.microsoft.com/en-us/library/cc966412.aspx
http://www.midnightdba.com/Jen/2014/04/decree-set-your-partition-offset-and-block-size-make-sql-server-faster/' URL,
			'Minor' Severity,
			'Ask from you SAN guy to set DATA and Log Drives to change the "Blok Size" to 64Kb Block Size' Action
	FROM    @DISKS
	WHERE	[BlockSize] < 64;
	--------------------------------------------------------
	DECLARE @command VARCHAR(255)

	SET @command = 'dir "%SystemRoot%\system32\config\software"'

	INSERT INTO @output
	EXEC master.dbo.xp_cmdshell @command;

	INSERT	dbo.App_Exeption(MainRunID, DatabaseName, Type, Message,URL, Severity, Action)
	SELECT	-1,@@SERVERNAME ServerName,
			'Server' Type,
			'Serious bug in SQL Server 2012 SP1, due to msiexec process keep running. registry file grow to 2GB' Message,
			'http://connect.microsoft.com/SQLServer/feedback/details/770630/msiexec-exe-processes-keep-running-after-installation-of-sql-server-2012-sp1' URL,
			'Minor' Severity,
			'http://rusanu.com/2013/02/15/registry-bloat-after-sql-server-2012-sp1-installation/' Action
	FROM    @output
			CROSS APPLY (SELECT LTRIM(
					REPLACE(
						SUBSTRING(line, CHARINDEX(')', line) + 1, LEN(line))
					, ',', '')
				) TrimLine) TL
	WHERE   line LIKE '%File(s)%bytes'
			AND CONVERT (INT,CONVERT (INT,SUBSTRING(TL.TrimLine,0,CHARINDEX(' ', TL.TrimLine)))/1048576.0/128) = 2 -- 2GB
			AND SERVERPROPERTY('productversion') > '11.0.3000.0'


	SELECT	DatabaseName [Server\Database Name],  Type, Message, URL, Severity, Action 
	FROM	dbo.App_Exeption
	WHERE	MainRunID = -1
	ORDER BY Type,Severity
/* TODO -- צריך להכניס את הבדיקה הזאת כאשר מצאנו בלוג עדות לכך שיה את מספרי האררורים 
/*
--18272 --3634
The operating system returned the error '3(The system cannot find the path specified.)' while attempting 'DeleteFile' on 'D:\SQL\BACKUP\RestoreCheckpointDB23.CKP'.
During restore restart, an I/O error occurred on checkpoint file 'D:\SQL\BACKUP\RestoreCheckpointDB24.CKP' (operating system error 3(The system cannot find the path specified.)). The statement is proceeding but cannot be restarted. Ensure that a valid storage location exists for the checkpoint file.
*/

DECLARE @instance_name NVARCHAR(200) ,
		@system_instance_name NVARCHAR(200) ,
		@registry_key NVARCHAR(512)

SET @instance_name = COALESCE(CONVERT(NVARCHAR(20), SERVERPROPERTY('InstanceName')),'MSSQLSERVER');
EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\Microsoft SQL Server\Instance Names\SQL',@instance_name, @system_instance_name OUTPUT;
SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\' + @system_instance_name + '\MSSQLServer';
DECLARE @BackupDirectory VARCHAR(100) 
--Default Backup Directory Path Check
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', 
  @key=@registry_key, 
  @value_name='BackupDirectory', 
  @BackupDirectory=@BackupDirectory OUTPUT 
SELECT @BackupDirectory -- CHECK IF THE PATH EXISTS!!
/* --How to Fix
EXEC master..xp_regwrite 
     @rootkey='HKEY_LOCAL_MACHINE', 
     @key=@registry_key, 
     @value_name='BackupDirectory', 
     @type='REG_SZ', 
     @value= -- HERE YOU NEED TO WRITE THE NEW PATH
*/
--Default Log Path Check
DECLARE @DefaultLog VARCHAR(100) 
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', 
  @key=@registry_key, 
  @value_name='DefaultLog', 
  @DefaultLog=@DefaultLog OUTPUT 
SELECT @DefaultLog-- CHECK IF THE PATH EXISTS!!
/* --How to Fix
EXEC master..xp_regwrite 
     @rootkey='HKEY_LOCAL_MACHINE', 
     @key=@registry_key, 
     @value_name='DefaultLog', 
     @type='REG_SZ', 
     @value='L:\SQL\Log'
*/



*/
END