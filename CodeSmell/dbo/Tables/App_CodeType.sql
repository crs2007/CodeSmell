CREATE TABLE [dbo].[App_CodeType] (
    [ID]          TINYINT      NOT NULL,
    [Description] VARCHAR (50) NOT NULL,
    CONSTRAINT [PK_App_CodeType] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (DATA_COMPRESSION = PAGE)
);


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'Describe the code type to work with a single test', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'App_CodeType';

