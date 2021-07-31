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




GO
CREATE NONCLUSTERED INDEX [IX_Mng_ApplicationErrorLog_ExecutionTime]
    ON [dbo].[Mng_ApplicationErrorLog]([ExecutionTime] ASC);


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'Cleaning', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Mng_ApplicationErrorLog', @level2type = N'INDEX', @level2name = N'IX_Mng_ApplicationErrorLog_ExecutionTime';


GO
EXECUTE sp_addextendedproperty @name = N'CREATE', @value = N'20210704', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'Mng_ApplicationErrorLog', @level2type = N'INDEX', @level2name = N'IX_Mng_ApplicationErrorLog_ExecutionTime';

