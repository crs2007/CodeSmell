CREATE TABLE [History].[App_MainRun] (
    [ID]           INT       IDENTITY (1, 1) NOT NULL,
    [ExecuteDate]  DATETIME  NOT NULL,
    [DatabaseName] [sysname] NOT NULL,
    [ServerName]   [sysname] NOT NULL,
    [StartDate]    DATE      NULL,
    [EndDate]      DATE      NULL,
    CONSTRAINT [PK_App_MainRun] PRIMARY KEY CLUSTERED ([ID] ASC)
);

