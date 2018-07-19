CREATE TABLE [dbo].[App_DBVersion] (
    [ID]      INT           NOT NULL,
    [Version] NVARCHAR (25) NOT NULL,
    CONSTRAINT [PK_App_DBVersion] PRIMARY KEY CLUSTERED ([ID] ASC)
);

