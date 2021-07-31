CREATE TABLE [Background].[Inner_sql_ObjectNameRegex] (
    [ID]                  INT       NOT NULL,
    [FullObjectName]      [sysname] NOT NULL,
    [SearchRegexMethodID] INT       NOT NULL,
    [ObjectName]          [sysname] NOT NULL,
    [MainRunID]           INT       NOT NULL
);




GO
CREATE CLUSTERED INDEX [CIX_Inner_sql_ObjectNameRegex]
    ON [Background].[Inner_sql_ObjectNameRegex]([MainRunID] ASC) WITH (DATA_COMPRESSION = PAGE);

