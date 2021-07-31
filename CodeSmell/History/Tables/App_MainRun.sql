CREATE TABLE [History].[App_MainRun] (
    [ID]           INT            IDENTITY (1, 1) NOT NULL,
    [ExecuteDate]  DATETIME       NOT NULL,
    [DatabaseName] [sysname]      NOT NULL,
    [ServerName]   [sysname]      NOT NULL,
    [StartDate]    DATE           NULL,
    [EndDate]      DATE           NULL,
    [IsSingleSP]   BIT            CONSTRAINT [DF_App_MainRun_IsSingleSP] DEFAULT ((0)) NOT NULL,
    [UserName]     [sysname]      NULL,
    [ObjectName]   NVARCHAR (512) NULL,
    CONSTRAINT [PK_App_MainRun] PRIMARY KEY CLUSTERED ([ID] ASC)
);




GO
CREATE NONCLUSTERED INDEX [IX_App_MainRun_NC_NU_DatabaseName#ExecuteDate]
    ON [History].[App_MainRun]([DatabaseName] ASC, [ExecuteDate] ASC)
    INCLUDE([UserName], [ObjectName]) WITH (DATA_COMPRESSION = PAGE);


GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'index is used  by the sp usp_App_RunCheck to get all similar objects compiled in the las 30 days', @level0type = N'SCHEMA', @level0name = N'History', @level1type = N'TABLE', @level1name = N'App_MainRun', @level2type = N'INDEX', @level2name = N'IX_App_MainRun_NC_NU_DatabaseName#ExecuteDate';


GO
EXECUTE sp_addextendedproperty @name = N'CREATE', @value = N'20200717', @level0type = N'SCHEMA', @level0name = N'History', @level1type = N'TABLE', @level1name = N'App_MainRun', @level2type = N'INDEX', @level2name = N'IX_App_MainRun_NC_NU_DatabaseName#ExecuteDate';

