-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE History.usp_GetLastRunningDetail
	@DatabaseName sysname
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @DBName sysname;
	-- Local DB Only
	SELECT  @DBName = name
	FROM    sys.databases WITH(NOLOCK)
	WHERE	name = @DatabaseName;

	IF @@ROWCOUNT = 0 
	BEGIN
		RAISERROR ('You must enter valid local database name',16,1);
		RETURN - 1;
	END

	DECLARE @MainRunID INT;
	SELECT	TOP 1 @MainRunID = ID
	FROM	History.App_MainRun
	WHERE	DatabaseName = @DBName
	ORDER BY ID DESC;

	SELECT	DISTINCT DR.ObjectName ,MR.DatabaseName,
                                 DR.Type ,
                                 DR.ColumnName ,
                                 DR.ConstraintName ,
                                 DR.Massege ,
                                 DR.URL ,
                                 DR.Severity,
								 DR.ErrorID--,IL.*
	FROM	History.App_MainRun MR
			INNER JOIN History.App_DetailRun DR ON DR.MainRunID = MR.ID
			LEFT JOIN History.App_IgnoreList IL ON IL.DatabaseName = MR.DatabaseName AND IL.ErrorID = DR.ErrorID AND IL.ObjectName = DR.ObjectName
	WHERE	MR.ID = @MainRunID
			AND il.ID IS NULL
END