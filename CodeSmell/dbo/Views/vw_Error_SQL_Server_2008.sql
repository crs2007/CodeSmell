


CREATE VIEW [dbo].[vw_Error_SQL_Server_2008] AS
	SELECT	E.ID ,
			E.Name ,
			E.Massege ,
			E.URL_Reference ,
			E.IsCheckOnProcName,
			RP.Regex,
			v.Version
	FROM	dbo.App_Error E
			INNER JOIN dbo.App_CL_ErrVerPet CL ON E.ID = CL.ErrorID
			INNER JOIN dbo.App_DBVersion V ON e.DBVersionID = V.ID
			INNER JOIN dbo.App_RegexPettern RP ON RP.ID = CL.RegexPetternID
	WHERE	V.ID <= 10
			AND E.IsActive = 1
	UNION ALL 
	SELECT	ID ,
	        Name ,
	        Massege ,
	        URL_Reference ,
	        NULL IsCheckOnProcName,
			NULL Regex,
			'ALL' Version
	FROM	[dbo].[App_GeneralCheck]
	WHERE	IsActive = 1