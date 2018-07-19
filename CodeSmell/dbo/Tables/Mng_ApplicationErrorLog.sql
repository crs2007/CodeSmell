CREATE TABLE [dbo].[Mng_ApplicationErrorLog] (
    [ID]            INT             IDENTITY (1, 1) NOT NULL,
    [ProcedureName] [sysname]       NOT NULL,
    [ErrorMessage]  NVARCHAR (4000) NOT NULL,
    [HostName]      [sysname]       NULL,
    [LoginName]     [sysname]       NULL,
    [ExecutionTime] DATETIME        NOT NULL,
    [MainRunID]     INT             NULL,
    CONSTRAINT [PK_Mng_ApplicationError] PRIMARY KEY CLUSTERED ([ID] ASC)
);

