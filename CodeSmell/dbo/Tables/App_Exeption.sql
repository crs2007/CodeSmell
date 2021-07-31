CREATE TABLE [dbo].[App_Exeption] (
    [MainRunID]      INT             NOT NULL,
    [DatabaseName]   [sysname]       NOT NULL,
    [ObjectName]     NVARCHAR (255)  NULL,
    [Type]           NVARCHAR (255)  NULL,
    [ColumnName]     NVARCHAR (2000) NULL,
    [ConstraintName] NVARCHAR (2000) NULL,
    [Message]        NVARCHAR (2000) NULL,
    [URL]            VARCHAR (512)   NULL,
    [Severity]       [sysname]       NULL,
    [ErrorID]        INT             NULL
);


GO
CREATE CLUSTERED INDEX [CIX_App_Exeption]
    ON [dbo].[App_Exeption]([MainRunID] ASC) WITH (PAD_INDEX = ON, DATA_COMPRESSION = PAGE);


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'List of Running exeptions', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'App_Exeption';

