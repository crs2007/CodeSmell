CREATE TABLE [Background].[Inner_sql_DefinitionRegex] (
    [ID]                  INT             NOT NULL,
    [FullObjectName]      [sysname]       NOT NULL,
    [SearchRegexMethodID] INT             NOT NULL,
    [Definition]          NVARCHAR (MAX)  NOT NULL,
    [Regex]               NVARCHAR (1000) NOT NULL,
    [NotIn_RegexPettern]  NVARCHAR (1000) NULL
);


GO
CREATE CLUSTERED INDEX [IX_Inner_sql_DefinitionRegex]
    ON [Background].[Inner_sql_DefinitionRegex]([FullObjectName] ASC);

