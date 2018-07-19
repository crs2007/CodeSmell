CREATE TABLE [dbo].[App_Severity] (
    [ID]   INT       IDENTITY (1, 1) NOT NULL,
    [Name] [sysname] NOT NULL,
    CONSTRAINT [PK_App_Severity] PRIMARY KEY CLUSTERED ([ID] ASC)
);

