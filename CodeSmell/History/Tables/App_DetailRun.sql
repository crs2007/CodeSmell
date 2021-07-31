CREATE TABLE [History].[App_DetailRun] (
    [ID]             INT             IDENTITY (1, 1) NOT NULL,
    [MainRunID]      INT             NOT NULL,
    [ObjectName]     NVARCHAR (255)  NOT NULL,
    [Type]           NVARCHAR (255)  NULL,
    [ColumnName]     NVARCHAR (2000) NULL,
    [ConstraintName] NVARCHAR (2000) NULL,
    [URL]            VARCHAR (512)   NULL,
    [Severity]       [sysname]       NOT NULL,
    [ErrorID]        INT             NULL,
    [Message]        VARCHAR (1000)  NULL,
    CONSTRAINT [PK_App_DetailRun] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_App_DetailRun_App_MainRun] FOREIGN KEY ([MainRunID]) REFERENCES [History].[App_MainRun] ([ID])
);



