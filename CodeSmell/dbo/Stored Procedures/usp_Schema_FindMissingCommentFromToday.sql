-- =============================================
-- Author:		Sharon
-- Create date: 26/07/2021
-- Update date: 
-- Description:	Find Missing Comment From Today.
-- =============================================
CREATE PROCEDURE dbo.usp_Schema_FindMissingCommentFromToday
	@DatabaseName sysname,
	@Message NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectID INT = NULL,
	@CheckID INT = NULL,
	@LoginName sysname = NULL,
	@RunningID INT = NULL
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
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),'You must enter valid local database name insted - ' + ISNULL(N' insted - ' + QUOTENAME(@DatabaseName),N'') ,HOST_NAME(),@LoginName,GETDATE(),@RunningID;  
		RETURN -1;
	END

	DECLARE @Dates					TABLE ([Date] NVARCHAR(25));
	DECLARE @Year					VARCHAR(4),
			@Month					VARCHAR(2),
			@NewMonth				CHAR(2),
			@day					VARCHAR(2),
			@NewDay					CHAR(2),
			@MonthExpend			BIT = 0,
			@DayExpend				BIT = 0;

				
	BEGIN TRY
		
				SELECT	@Year = DATEPART(YEAR,GETDATE()),
						@Month = DATEPART(MONTH,GETDATE()),
						@day = DATEPART(DAY,GETDATE());


				IF  DATEPART(MONTH,GETDATE()) < 10
				BEGIN
					SET @MonthExpend = 1;
					SELECT @NewMonth = '0' + CONVERT(CHAR(1),@Month)
				END
				IF  DATEPART(DAY,GETDATE()) < 10
				BEGIN
					SET @DayExpend = 1;
					SELECT @NewDay = '0' + CONVERT(CHAR(1),@day);	
				END

				INSERT @Dates(Date)
				SELECT @Year + '-' + @Month + '-' + @day [Date]
				UNION 
				SELECT @Year + '/' + @Month + '/' + @day
				UNION 
				SELECT @Year  + @Month + @day
				UNION 
				SELECT @day + '-' + @Month + '-' + @Year
				UNION 
				SELECT @day + '/' + @Month + '/' + @Year
				UNION 
				SELECT @day  + @Month + @Year


				UNION 
				SELECT @Year + '-' + @Month + '-' + @NewDay WHERE @DayExpend = 1
				UNION 
				SELECT @Year + '/' + @Month + '/' + @NewDay WHERE @DayExpend = 1
				UNION 
				SELECT @Year  + @Month + @NewDay WHERE @DayExpend = 1
				UNION 
				SELECT @NewDay + '-' + @Month + '-' + @Year WHERE @DayExpend = 1
				UNION 
				SELECT @NewDay + '/' + @Month + '/' + @Year WHERE @DayExpend = 1
				UNION 
				SELECT @NewDay  + @Month + @Year WHERE @DayExpend = 1


				UNION 
				SELECT @Year + '-' + @NewMonth + '-' + @day WHERE @MonthExpend = 1
				UNION 
				SELECT @Year + '/' + @NewMonth + '/' + @day WHERE @MonthExpend = 1
				UNION 
				SELECT @Year  + @NewMonth + @day WHERE @MonthExpend = 1
				UNION 
				SELECT @day + '-' + @NewMonth + '-' + @Year WHERE @MonthExpend = 1
				UNION 
				SELECT @day + '/' + @NewMonth + '/' + @Year WHERE @MonthExpend = 1
				UNION 
				SELECT @day  + @NewMonth + @Year WHERE @MonthExpend = 1

				UNION 
				SELECT @Year + '-' + @NewMonth + '-' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @Year + '/' + @NewMonth + '/' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @Year  + @NewMonth + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @NewDay + '-' + @NewMonth + '-' + @Year WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @NewDay + '/' + @NewMonth + '/' + @Year WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @NewDay  + @NewMonth + @Year WHERE @MonthExpend = 1 AND @DayExpend = 1

				UNION 
				SELECT @Year + '-' + @Month + '-' + @day [Date]
				UNION 
				SELECT @Year + '/' + @Month + '/' + @day
				UNION 
				SELECT @Year  + @Month + @day
				UNION 
				SELECT @day + '-' + @Month + '-' + @Year
				UNION 
				SELECT @day + '/' + @Month + '/' + @Year
				UNION 
				SELECT @day  + @Month + @Year


				UNION 
				SELECT RIGHT(RIGHT(@Year,2),2) + '-' + @Month + '-' + @NewDay WHERE @DayExpend = 1
				UNION 
				SELECT RIGHT(@Year,2) + '/' + @Month + '/' + @NewDay WHERE @DayExpend = 1
				UNION 
				SELECT RIGHT(@Year,2)  + @Month + @NewDay WHERE @DayExpend = 1
				UNION 
				SELECT @NewDay + '-' + @Month + '-' + RIGHT(@Year,2) WHERE @DayExpend = 1
				UNION 
				SELECT @NewDay + '/' + @Month + '/' + RIGHT(@Year,2) WHERE @DayExpend = 1
				UNION 
				SELECT @NewDay  + @Month + RIGHT(@Year,2) WHERE @DayExpend = 1


				UNION 
				SELECT RIGHT(@Year,2) + '-' + @NewMonth + '-' + @day WHERE @MonthExpend = 1
				UNION 
				SELECT RIGHT(@Year,2) + '/' + @NewMonth + '/' + @day WHERE @MonthExpend = 1
				UNION 
				SELECT RIGHT(@Year,2)  + @NewMonth + @day WHERE @MonthExpend = 1
				UNION 
				SELECT @day + '-' + @NewMonth + '-' + RIGHT(@Year,2) WHERE @MonthExpend = 1
				UNION 
				SELECT @day + '/' + @NewMonth + '/' + RIGHT(@Year,2) WHERE @MonthExpend = 1
				UNION 
				SELECT @day  + @NewMonth + RIGHT(@Year,2) WHERE @MonthExpend = 1

				UNION 
				SELECT RIGHT(@Year,2) + '-' + @NewMonth + '-' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT RIGHT(@Year,2) + '/' + @NewMonth + '/' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT RIGHT(@Year,2)  + @NewMonth + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @NewDay + '-' + @NewMonth + '-' + RIGHT(@Year,2) WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @NewDay + '/' + @NewMonth + '/' + RIGHT(@Year,2) WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION 
				SELECT @NewDay  + @NewMonth + RIGHT(@Year,2) WHERE @MonthExpend = 1 AND @DayExpend = 1
				UNION
				SELECT	TRY_CONVERT(varchar(25),GETDATE(),Number)
				FROM	(VALUES(110),(111),(112),(101),(102),(103),(104),(105),(106),(107)) v(Number);
				INSERT	dbo.App_Exeption(MainRunID, DatabaseName, ObjectName, Type, ColumnName, ConstraintName, Message, URL, Severity, ErrorID)
				SELECT	TOP (1) @RunningID,
						@DatabaseName DatabaseName,
						P.FullObjectName,
						'Procedure' Type,
						NULL ColumnName,
						NULL ConstraintName,
						@Message Message,
						@URL_Reference URL,
						@SeverityName,
						@CheckID
				FROM	Background.Inner_sql_modules P
				WHERE	P.type = 'P'
						AND P.MainRunID = @RunningID
						AND NOT EXISTS (SELECT TOP (1) 1 
									FROM	@Dates D
											CROSS JOIN Background.Inner_sql_modules PP
									WHERE   PP.type = 'P'
											AND PP.MainRunID = @RunningID
											AND PP.Remarks LIKE '%' + D.Date + '%');
	END TRY
	BEGIN CATCH
		INSERT dbo.Mng_ApplicationErrorLog(ProcedureName, ErrorMessage, HostName, LoginName, ExecutionTime, MainRunID)
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),@LoginName,GETDATE(),@RunningID; 
		RETURN -1;
	END CATCH
END