CREATE TABLE [dbo].[App_RegexPettern] (
    [ID]    INT             NOT NULL,
    [Regex] NVARCHAR (1000) NOT NULL,
    CONSTRAINT [PK_App_RegexPettern] PRIMARY KEY CLUSTERED ([ID] ASC)
);

