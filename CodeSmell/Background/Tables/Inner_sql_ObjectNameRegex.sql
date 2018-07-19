CREATE TABLE [Background].[Inner_sql_ObjectNameRegex] (
    [ID]                  INT       NOT NULL,
    [FullObjectName]      [sysname] NOT NULL,
    [SearchRegexMethodID] INT       NOT NULL,
    [ObjectName]          [sysname] NOT NULL,
    CONSTRAINT [PK_Inner_sql_ObjectNameRegex] PRIMARY KEY CLUSTERED ([ID] ASC, [FullObjectName] ASC)
);

