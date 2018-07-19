CREATE TABLE [dbo].[App_SubjectGroup] (
    [ID]      INT          IDENTITY (1, 1) NOT NULL,
    [Subject] VARCHAR (50) NOT NULL,
    CONSTRAINT [PK_App_SubjectGroup] PRIMARY KEY CLUSTERED ([ID] ASC)
);

