# CodeSmell
A system to control a SQL Server developers team to a basic code review. 
The system is designed to follow the DBA developer to assist in writing better code. it tries to enforce a clean code(without a smell).

## Couple ways to run the code:
* Execute for a specific database in the server.
* Execute per alter\create of code object(procedure, function, trigger).
* Execute per alter\create of the table.
* Execute for server hard coded defiend checks(EXECUTE [CodeSmell].[Server].[usp_App_RunCheck];)

### Prerequisite:
* clr enabled(Setup will turn it on for you, for supporting regular expresions search)
 
### How To Install:
* Build the solution with Visual Studio - Deploy it to your server.
* Insert the data with Script.PostDeployment_DATA.sql file.
* Run [Setup].[usp_StatUp] - Change owner to sa, TRUSTWORTHY on, clr enabled on, create a job of retantion on the server.
* Choose your solution. for activation on any creat\alter of object - create server triggers - [Setup].[usp_CreateServerTrigger]

### Execute for a specific database in the server:
```sql
DECLARE @O_SQLCMDError NVARCHAR(2048);
EXECUTE [CodeSmell].[dbo].[usp_App_RunCheck] @I_DataBaseName = 'WideWorldImporters',       
                                 @I_StartDate = '19000101',    
                                 @I_EndDate = '20300101',          
                                 @I_ObjectName = NULL,             
                                 @I_Detail = 1,                    
                                 @I_Part1 = 1,                     
                                 @I_CollectProcDefinition = 1,     
                                 @I_CollectProcName = 1,           
                                 @I_Code = NULL,                   
                                 @I_Debug = 0,                     
                                 @I_LoginName = NULL,              
                                 @O_SQLCMDError = @O_SQLCMDError OUTPUT;
IF @O_SQLCMDError IS NOT NULL SELECT @O_SQLCMDError [@O_SQLCMDError];
```
### Execute for server hard coded defiend checks:
```sql
EXECUTE [CodeSmell].[Server].[usp_App_RunCheck];
```

### Execute per alter\create of code object(procedure, function, trigger):
```sql
DECLARE @I_DataBaseName sysname = DB_NAME();
DECLARE @I_ObjectName sysname = 'dbo.USP_GetNormalTableByID';
DECLARE @I_Code NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(@I_ObjectName));
DECLARE @I_LoginName sysname;
DECLARE @O_SQLCMDError NVARCHAR(2048);
DECLARE @I_EventType VARCHAR(50);

EXECUTE [CodeSmell].[dbo].[usp_App_RunValidationCheckOnSP] 
   @I_DataBaseName
  ,@I_ObjectName
  ,@I_Code
  ,@I_LoginName
  ,@O_SQLCMDError OUTPUT
  ,@I_EventType;
IF @O_SQLCMDError IS NOT NULL SELECT @O_SQLCMDError [@O_SQLCMDError];
```
It could be easily combined to server trigger by activating - [CodeSmell].[Setup].[usp_CreateServerTrigger]
```sql
EXECUTE [CodeSmell].[Setup].[usp_CreateServerTrigger];
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [str_CodeSmell_ObjectChange] 	
	ON ALL SERVER FOR CREATE_PROCEDURE, ALTER_PROCEDURE, CREATE_TRIGGER, ALTER_TRIGGER, CREATE_FUNCTION, ALTER_FUNCTION
AS
BEGIN
	SET NOCOUNT ON;
	SET ANSI_WARNINGS ON;
	SET XACT_ABORT ON;
	IF SESSION_CONTEXT(N'IgnoreCodeSmell') = N'1'
	BEGIN
		PRINT('Ignoring Code Smell');
		RETURN;
	END

	DECLARE @Alert			VARCHAR(1000) = '### Server Trigger str_CodeSmell_ObjectChange',
			@ObjectName		sysname,
			@DatabaseName	sysname,
			@Code			NVARCHAR(MAX),
			@LoginName		sysname,
			@O_SQLCMDError	NVARCHAR(2048),
			@EventType		VARCHAR(50);
	BEGIN TRY
		IF EXISTS(
			SELECT TOP (1) 1 FROM [CodeSmell].[dbo].Setup_Players P WHERE APP_NAME() = P.APP_NAME AND HOST_NAME() LIKE P.HOST_NAME
			)
		BEGIN
			;WITH EventCTE AS
			(
				SELECT	EVENTDATA()		ED
			),
			ObjectCTE AS
			(
				SELECT	x.value('DatabaseName[1]',	'sysname')		DatabaseName,
						CONCAT(x.value('SchemaName[1]', 'sysname')	, '.', x.value('ObjectName[1]', 'sysname')) ObjectName,
						x.value('TSQLCommand[1]', 'nvarchar(MAX)') Command, 
						x.value('LoginName[1]', 'varchar(256)') LoginName,
						x.value('EventType[1]',	 'varchar(50)')EventType
				FROM	EventCTE
						CROSS APPLY ED.nodes('EVENT_INSTANCE[1]') T(x)		
			)			
			SELECT	@DatabaseName	= DatabaseName,
					@ObjectName		= ObjectName,
					@Code			= Command,
					@LoginName		= LoginName,
					@EventType		= EventType
			FROM	ObjectCTE;
			IF LEN(@Code) > 105
			BEGIN
				EXEC [CodeSmell].[dbo].[usp_App_RunValidationCheckOnSP] @DatabaseName, @ObjectName, @Code, @LoginName, @O_SQLCMDError OUTPUT,@EventType;
				IF @O_SQLCMDError IS NOT NULL
				BEGIN
					RAISERROR (@O_SQLCMDError, 16, 1);
				END
			END
		END										 														 
	END TRY
	BEGIN CATCH	
		IF ERROR_NUMBER() = 50000
		BEGIN
			SET @Alert = ERROR_MESSAGE();
			THROW 50000,@Alert,1;
		END
		ELSE
		BEGIN
			SET @Alert = CONCAT(@Alert, ' failed: ', ERROR_MESSAGE(), ' (line: ', ERROR_LINE(), ')');
			PRINT @Alert;
		END
	END CATCH			 				 
END;
GO
ENABLE TRIGGER [str_CodeSmell_ObjectChange] ON ALL SERVER
GO
```
### Execute per alter\create of table:
Could be easily combined to server trigger by activating - [CodeSmell].[Setup].[usp_CreateServerTrigger]
```sql
DECLARE @I_DataBaseName sysname = DB_NAME()
DECLARE @I_ObjectName sysname = 'dbo.USP_GetNormalTableByID'
DECLARE @I_StartDate DATE = GETDATE();
DECLARE @I_EndDate DATE = GETDATE();

EXEC [CodeSmell].[dbo].[usp_App_RunCheck_Object] @I_DataBaseName = @I_DataBaseName,
												 @I_StartDate = @I_StartDate,
												 @I_EndDate = @I_EndDate,
												 @I_ObjectName = @I_ObjectName,
												 @I_Debug = 0;
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [str_CodeSmell_PObjectChange] ON ALL SERVER FOR CREATE_TABLE
AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS ON			 			 		
	DECLARE @Alert			VARCHAR(1000) = '### Server Trigger str_CodeSmell_PObjectChange',
			@ObjectName		sysname,
			@DatabaseName	sysname,
			@Code			NVARCHAR(MAX),
			@Date			DATE = GETDATE();
	BEGIN TRY
		IF EXISTS(
			SELECT TOP (1) 1 FROM [CodeSmell].[dbo].Setup_Players P WHERE APP_NAME() = P.APP_NAME AND HOST_NAME() LIKE P.HOST_NAME
			)
		BEGIN
			;WITH EventCTE AS
			(
				SELECT	EVENTDATA()		ED
			),
			ObjectCTE AS
			(
				SELECT	x.value('DatabaseName[1]',	'sysname')		DatabaseName,
						CONCAT(x.value('SchemaName[1]', 'sysname')	, '.', x.value('ObjectName[1]', 'sysname')) ObjectName,
						x.value('TSQLCommand[1]', 'nvarchar(MAX)') Command
				FROM	EventCTE
						CROSS APPLY ED.nodes('EVENT_INSTANCE[1]') T(x)		
			)			

			SELECT	@DatabaseName	= DatabaseName,
					@ObjectName		= ObjectName,
					@Code			= Command
			FROM	ObjectCTE;

			IF LEN(@Code) > 10
			BEGIN
				EXEC [CodeSmell].[dbo].[usp_App_RunCheck_Object] @DatabaseName, @Date,@Date, @ObjectName, 0;
			END
				
		END

																 														 
	END TRY
	BEGIN CATCH			
		SET @Alert = CONCAT(@Alert, ' failed: ', ERROR_MESSAGE(), ' (line: ', ERROR_LINE(), ')')
		PRINT @Alert
	END CATCH			 				 
END;
GO
ENABLE TRIGGER [str_CodeSmell_PObjectChange] ON ALL SERVER
GO
```

### Flow:
* SQL Server Triggers – to activate the process
- **str_CodeSmell_ObjectChange**: at any - CREATE_PROCEDURE, ALTER_PROCEDURE, CREATE_TRIGGER, ALTER_TRIGGER, CREATE_FUNCTION, ALTER_FUNCTION - Call to: **dbo.usp_App_RunValidationCheckOnSP**
- **str_CodeSmell_PObjectChange**: at any -  CREATE_TABLE - Call to: **dbo.usp_App_RunCheck_Object**
- Who to track: **dbo.Setup_Players** (All users at the table), not check for all others
- What Application to track: SSMS, etc.
* Ignore if: SESSION_CONTEXT(N'IgnoreCodeSmell') = N'1'
* **dbo.usp_App_RunCheck_Object** - For check, relevant checks based on pre-defined SPs on the new table - Collect all relevant SP names from App_GeneralCheck where IsPhysicalObject = 1
* **dbo.usp_App_RunValidationCheckOnSP** → dbo.usp_App_RunCheck - For check relevant checks based on pre-defined SPs on the Code Object
- Strip the code out of remarks first and than stip out of text(for ignore out of dynamic SQL)- Get Definition without remarks into -> Background.Inner_sql_modules(Background.usp_INNER_PopulateTable) or Code inside of the SP.
- Part 1 - Collect all relevant SP names from App_GeneralCheck where IsPhysicalObject = 0. (Could be controlled from the SP input by a flag to turn On\Off)
- Part 2: Collect Regex possible checks On Modules
-- Checks - based on regular expressions - 
```sql
SELECT * FROM [CodeSmell].[dbo].[vw_Error_SQL_Server_CurrentVersion]
```
* Part 3: Collect Procedure name + Regex checks + 
- Find RegEx match
- Find mismatch by RegEx only
- Hardcoded checks - 
-- check if the object was changed or a new version was created in the last 30 days by another person
-- comment of today's date with a description of your changes in this procedure.
-- Do not enter the database name in the code (It's not triggered on the 3rd part name out of the current DB scoped)

### Disclaimer
This code and information are provided "AS IS" without warranty of any kind, either expressed or implied, including but not limited to the implied warranties or merchantability and/or fitness for a particular purpose.  

### Warranty
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### License
This script is free to download and use for personal, educational, and internal corporate purposes, provided that this header is preserved. 
Redistribution or sale of this script, in whole or in part, is prohibited without the author's express written consent.
