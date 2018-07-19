CREATE TABLE [History].[App_IgnoreList] (
    [ID]           INT            IDENTITY (1, 1) NOT NULL,
    [ObjectName]   NVARCHAR (255) NOT NULL,
    [DatabaseName] [sysname]      NOT NULL,
    [ErrorID]      INT            NOT NULL,
    CONSTRAINT [PK_App_IgnoreList] PRIMARY KEY CLUSTERED ([ID] ASC)
);

