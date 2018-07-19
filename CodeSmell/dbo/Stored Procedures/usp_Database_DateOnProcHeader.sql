-- =============================================
-- Author:		Sharon
-- Create date: 12/06/2013
-- Update date: 24/08/2014 @ObjectID INT
-- Description:	Finding Unused SP when SQL Server is up at list for capel of days.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Database_DateOnProcHeader]
	@DatabaseName sysname,
	@Massege NVARCHAR(1000),
	@URL_Reference VARCHAR(512),
	@SeverityName sysname,
	@ObjectName sysname,
	@ObjectDeff NVARCHAR(max)
AS
BEGIN
	SET NOCOUNT ON;
	IF @ObjectDeff IS NULL
		RETURN -1;
	DECLARE @Year VARCHAR(4),
			@Month VARCHAR(2),
			@NewMonth CHAR(2),
			@day VARCHAR(2),
			@NewDay CHAR(2),
			@MonthExpend BIT = 0,
			@DayExpend BIT = 0 ;
	SELECT	@Year = DATEPART(YEAR,GETDATE()),
			@Month = DATEPART(MONTH,GETDATE()),
			@day = DATEPART(DAY,GETDATE());

	BEGIN TRY

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
		DECLARE @Dates TABLE ([Date] NVARCHAR(25))
		INSERT @Dates
		SELECT @Year + '-' + @Month + '-' + @day [Date]
		UNION ALL 
		SELECT @Year + '/' + @Month + '/' + @day
		UNION ALL 
		SELECT @Year  + @Month + @day
		UNION ALL 
		SELECT @day + '-' + @Month + '-' + @Year
		UNION ALL 
		SELECT @day + '/' + @Month + '/' + @Year
		UNION ALL 
		SELECT @day  + @Month + @Year


		UNION ALL 
		SELECT @Year + '-' + @Month + '-' + @NewDay WHERE @DayExpend = 1
		UNION ALL 
		SELECT @Year + '/' + @Month + '/' + @NewDay WHERE @DayExpend = 1
		UNION ALL 
		SELECT @Year  + @Month + @NewDay WHERE @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '-' + @Month + '-' + @Year WHERE @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '/' + @Month + '/' + @Year WHERE @DayExpend = 1
		UNION ALL 
		SELECT @NewDay  + @Month + @Year WHERE @DayExpend = 1


		UNION ALL 
		SELECT @Year + '-' + @NewMonth + '-' + @day WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @Year + '/' + @NewMonth + '/' + @day WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @Year  + @NewMonth + @day WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @day + '-' + @NewMonth + '-' + @Year WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @day + '/' + @NewMonth + '/' + @Year WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @day  + @NewMonth + @Year WHERE @MonthExpend = 1

		UNION ALL 
		SELECT @Year + '-' + @NewMonth + '-' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @Year + '/' + @NewMonth + '/' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @Year  + @NewMonth + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '-' + @NewMonth + '-' + @Year WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '/' + @NewMonth + '/' + @Year WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @NewDay  + @NewMonth + @Year WHERE @MonthExpend = 1 AND @DayExpend = 1

		UNION ALL 
		SELECT @Year + '-' + @Month + '-' + @day [Date]
		UNION ALL 
		SELECT @Year + '/' + @Month + '/' + @day
		UNION ALL 
		SELECT @Year  + @Month + @day
		UNION ALL 
		SELECT @day + '-' + @Month + '-' + @Year
		UNION ALL 
		SELECT @day + '/' + @Month + '/' + @Year
		UNION ALL 
		SELECT @day  + @Month + @Year


		UNION ALL 
		SELECT RIGHT(RIGHT(@Year,2),2) + '-' + @Month + '-' + @NewDay WHERE @DayExpend = 1
		UNION ALL 
		SELECT RIGHT(@Year,2) + '/' + @Month + '/' + @NewDay WHERE @DayExpend = 1
		UNION ALL 
		SELECT RIGHT(@Year,2)  + @Month + @NewDay WHERE @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '-' + @Month + '-' + RIGHT(@Year,2) WHERE @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '/' + @Month + '/' + RIGHT(@Year,2) WHERE @DayExpend = 1
		UNION ALL 
		SELECT @NewDay  + @Month + RIGHT(@Year,2) WHERE @DayExpend = 1


		UNION ALL 
		SELECT RIGHT(@Year,2) + '-' + @NewMonth + '-' + @day WHERE @MonthExpend = 1
		UNION ALL 
		SELECT RIGHT(@Year,2) + '/' + @NewMonth + '/' + @day WHERE @MonthExpend = 1
		UNION ALL 
		SELECT RIGHT(@Year,2)  + @NewMonth + @day WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @day + '-' + @NewMonth + '-' + RIGHT(@Year,2) WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @day + '/' + @NewMonth + '/' + RIGHT(@Year,2) WHERE @MonthExpend = 1
		UNION ALL 
		SELECT @day  + @NewMonth + RIGHT(@Year,2) WHERE @MonthExpend = 1

		UNION ALL 
		SELECT RIGHT(@Year,2) + '-' + @NewMonth + '-' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT RIGHT(@Year,2) + '/' + @NewMonth + '/' + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT RIGHT(@Year,2)  + @NewMonth + @NewDay WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '-' + @NewMonth + '-' + RIGHT(@Year,2) WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @NewDay + '/' + @NewMonth + '/' + RIGHT(@Year,2) WHERE @MonthExpend = 1 AND @DayExpend = 1
		UNION ALL 
		SELECT @NewDay  + @NewMonth + RIGHT(@Year,2) WHERE @MonthExpend = 1 AND @DayExpend = 1

		SELECT @ObjectDeff = LEFT(@ObjectDeff,CHARINDEX(LEFT(RTRIM(LTRIM(REPLACE(REPLACE(
				[dbo].[ufn_Util_CLR_RegexReplace](@ObjectDeff,'(--.*)|(((/\*)+?[\w\W]+?(\*/)+))','',0)  
				, CHAR(10), ''), CHAR(13), ' '))),12),@ObjectDeff));

		IF OBJECT_ID('tempdb..#Exeption') IS NOT NULL
		INSERT	#Exeption
		SELECT	TOP 1 
				@DatabaseName DatabaseName,
				@ObjectName,
				'Procedure' Type,
				NULL ColumnName,
				NULL ConstraintName,
				@Massege Massege,
				@URL_Reference URL,
				@SeverityName
		WHERE	NOT EXISTS (SELECT TOP 1 1 
							FROM	@Dates D
									CROSS JOIN (SELECT @ObjectDeff Def) ADef
							WHERE	ADef.def LIKE '%' + D.Date + '%')
		ELSE
		SELECT	TOP 1 
				@DatabaseName DatabaseName,
				@ObjectName,
				'Procedure' Type,
				NULL ColumnName,
				NULL ConstraintName,
				@Massege Massege,
				@URL_Reference URL,
				@SeverityName
		WHERE	NOT EXISTS (SELECT TOP 1 1 
							FROM	@Dates D
									CROSS JOIN (SELECT @ObjectDeff Def) ADef
							WHERE	ADef.def LIKE '%' + D.Date + '%')
	END TRY
	BEGIN CATCH
		INSERT #Mng_ApplicationErrorLog
		SELECT OBJECT_NAME(@@PROCID),ERROR_MESSAGE(), HOST_NAME(),USER_NAME();
		RETURN;
	END CATCH
END