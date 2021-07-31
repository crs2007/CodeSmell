CREATE TABLE [Background].[Inner_sql_modules] (
    [FullObjectName]        [sysname]      NOT NULL,
    [Definition]            NVARCHAR (MAX) NOT NULL,
    [Type]                  CHAR (2)       NOT NULL,
    [Remarks]               NVARCHAR (MAX) NULL,
    [MainRunID]             INT            NOT NULL,
    [DefinitionWithStrings] NVARCHAR (MAX) NULL
);




GO
CREATE CLUSTERED INDEX [CIX_FullObjectName]
    ON [Background].[Inner_sql_modules]([MainRunID] ASC, [FullObjectName] ASC) WITH (DATA_COMPRESSION = PAGE);


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'Store the Definition of the object with the texts\strings. without remarks', @level0type = N'SCHEMA', @level0name = N'Background', @level1type = N'TABLE', @level1name = N'Inner_sql_modules', @level2type = N'COLUMN', @level2name = N'DefinitionWithStrings';


GO
EXECUTE sp_addextendedproperty @name = N'CREATE', @value = N'20210724', @level0type = N'SCHEMA', @level0name = N'Background', @level1type = N'TABLE', @level1name = N'Inner_sql_modules', @level2type = N'COLUMN', @level2name = N'DefinitionWithStrings';

