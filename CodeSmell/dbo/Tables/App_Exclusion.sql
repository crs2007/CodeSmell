CREATE TABLE [dbo].[App_Exclusion] (
    [ID]           INT       NOT NULL,
    [ErrorID]      INT       NOT NULL,
    [object_name]  [sysname] NOT NULL,
    [DataBaseName] [sysname] NOT NULL,
    CONSTRAINT [PK_App_Exclusion] PRIMARY KEY CLUSTERED ([ID] ASC)
);

