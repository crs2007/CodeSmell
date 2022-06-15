CREATE VIEW [dbo].[vw_GeneralCheck] AS
	SELECT	GC.[ID],
		GC.[Name],
		[IsActive],
		[URL_Reference],
		[SubjectGroupID],
		SG.Subject			  [SubjectGroup],
		[DBVersionID],
		DBV.Version			  [SinceDBVersion],
		[SeverityID],
		S.Name				  [Severity],
		[IsOnSingleObject],
		[IsOnSingleObjectOnly],
		[IsPhysicalObject],
		[Message],
		[TriggerEvent_Bitmask]
FROM	[dbo].[App_GeneralCheck]		GC
		INNER JOIN dbo.App_DBVersion	DBV ON DBV.ID = GC.[DBVersionID]
		INNER JOIN dbo.App_Severity		S ON S.ID = GC.SeverityID
		INNER JOIN dbo.App_SubjectGroup SG ON GC.SubjectGroupID = SG.ID
WHERE	IsActive = 1;	-- Active Only