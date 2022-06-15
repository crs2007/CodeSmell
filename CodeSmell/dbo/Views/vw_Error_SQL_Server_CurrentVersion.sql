CREATE VIEW [dbo].[vw_Error_SQL_Server_CurrentVersion] AS
	SELECT	E.ID,
			CONCAT('CS',CONCAT(REPLICATE('0',7 - LEN(E.ID)),E.ID))[CatalogNumber],
			SG.Subject + ' - ' + E.Name Type,
            E.Message ,
            TRY_CONVERT(XML,E.URL_Reference) URL,
            E.IsCheckOnProcName,
            RP.Regex,
            CONCAT(SRM.Name,'(',SRM.ID,')') SearchRegexMethod,
            CONCAT(S.Name,'(',S.ID,')') Severity,
            NIRP.Regex NotIn_RegexPettern,
			V.Version,
			CT.Description CodeTypeSearch
	FROM	dbo.App_Error E
			INNER JOIN dbo.App_CL_ErrVerPet CL ON E.ID = CL.ErrorID
			INNER JOIN dbo.App_DBVersion V ON E.DBVersionID = V.ID
			INNER JOIN dbo.App_RegexPettern RP ON RP.ID = CL.RegexPetternID
            INNER JOIN dbo.App_SubjectGroup SG ON SG.ID = E.SubjectGroupID
			INNER JOIN dbo.App_Severity S ON S.ID = E.SeverityID
			INNER JOIN dbo.App_enum_SearchRegexMethod SRM ON SRM.ID = CL.SearchRegexMethodID
            LEFT JOIN  dbo.App_RegexPettern NIRP ON NIRP.ID = CL.[NotIn_RegexPetternID]
			LEFT JOIN dbo.App_CodeType CT ON CT.ID = CL.CodeTypeID
	WHERE	V.ID <= @@MicrosoftVersion / 0x1000000
			AND E.IsActive = 1
	UNION ALL 
	SELECT	GC.ID,
			CONCAT('CS',GC.ID)[CatalogNumber],
	        SG.Subject + ' - ' + GC.Name Type,
	        GC.Message ,
            TRY_CONVERT(XML,GC.URL_Reference) URL,
	        0 IsCheckOnProcName,
			'N\R' Regex,
			'N\R' SearchRegexMethod,
            CONCAT(S.Name,'(',S.ID,')') Severity,
            'N\R' NotIn_RegexPettern,
			V.Version,
			'N\R' CodeTypeSearch
	FROM	[dbo].[App_GeneralCheck] GC
			INNER JOIN dbo.App_DBVersion V ON GC.DBVersionID = V.ID
            INNER JOIN dbo.App_SubjectGroup SG ON SG.ID = GC.SubjectGroupID
			INNER JOIN dbo.App_Severity S ON S.ID = GC.SeverityID
	WHERE	GC.IsActive = 1
			AND V.ID <= @@MicrosoftVersion / 0x1000000