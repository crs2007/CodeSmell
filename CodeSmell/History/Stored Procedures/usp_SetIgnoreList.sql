-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [History].[usp_SetIgnoreList]
	@DatabaseName sysname,
	@ErrorIDs dbo.IgnoreList READONLY
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

	
	INSERT History.App_IgnoreList
	        ( ObjectName, DatabaseName, ErrorID )
	SELECT	s.ObjectName,@DBName,s.ErrorID
	FROM	@ErrorIDs s
			LEFT JOIN History.App_IgnoreList IL ON IL.ObjectName = s.ObjectName AND IL.DatabaseName = @DBName AND IL.ErrorID = s.ErrorID
	WHERE	IL.ID IS NULL
	
	
END