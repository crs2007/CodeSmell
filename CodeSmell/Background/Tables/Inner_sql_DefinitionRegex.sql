CREATE TABLE [Background].[Inner_sql_DefinitionRegex] (
    [ID]                  INT             NOT NULL,
    [FullObjectName]      [sysname]       NOT NULL,
    [SearchRegexMethodID] INT             NOT NULL,
    [Regex]               NVARCHAR (1000) NOT NULL,
    [NotIn_RegexPettern]  NVARCHAR (1000) NULL,
    [MainRunID]           INT             NOT NULL,
    [CodeTypeID]          TINYINT         NULL
);




GO
CREATE CLUSTERED INDEX [CIX_Inner_sql_DefinitionRegex]
    ON [Background].[Inner_sql_DefinitionRegex]([MainRunID] ASC) WITH (DATA_COMPRESSION = PAGE);


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'CodeType for Clean\With texts\Only remarks', @level0type = N'SCHEMA', @level0name = N'Background', @level1type = N'TABLE', @level1name = N'Inner_sql_DefinitionRegex', @level2type = N'COLUMN', @level2name = N'CodeTypeID';


GO
EXECUTE sp_addextendedproperty @name = N'CREATE', @value = N'20210711', @level0type = N'SCHEMA', @level0name = N'Background', @level1type = N'TABLE', @level1name = N'Inner_sql_DefinitionRegex', @level2type = N'COLUMN', @level2name = N'CodeTypeID';

