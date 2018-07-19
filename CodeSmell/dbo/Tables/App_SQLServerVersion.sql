CREATE TABLE [dbo].[App_SQLServerVersion] (
    [VersionNumber] VARCHAR (25)  NOT NULL,
    [Name]          VARCHAR (255) NOT NULL,
    [ReleaseDate]   DATE          NULL,
    CONSTRAINT [PK_App_SQLServerVersion] PRIMARY KEY CLUSTERED ([VersionNumber] ASC)
);

