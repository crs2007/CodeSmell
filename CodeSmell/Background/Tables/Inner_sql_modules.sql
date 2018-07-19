CREATE TABLE [Background].[Inner_sql_modules] (
    [FullObjectName] [sysname]      NOT NULL,
    [Definition]     NVARCHAR (MAX) NOT NULL,
    [Type]           CHAR (2)       NOT NULL,
    CONSTRAINT [PK_FullObjectName] PRIMARY KEY CLUSTERED ([FullObjectName] ASC)
);

