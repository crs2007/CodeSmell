CREATE TABLE [dbo].[App_Error] (
    [ID]                INT            NOT NULL,
    [Name]              NVARCHAR (255) NOT NULL,
    [Massege]           VARCHAR (512)  NULL,
    [IsActive]          BIT            NOT NULL,
    [URL_Reference]     VARCHAR (512)  NULL,
    [IsCheckOnProcName] BIT            NOT NULL,
    [SubjectGroupID]    INT            NULL,
    [DBVersionID]       INT            NOT NULL,
    [SeverityID]        INT            NULL,
    CONSTRAINT [PK_App_Error] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_App_Error_App_Severity] FOREIGN KEY ([SeverityID]) REFERENCES [dbo].[App_Severity] ([ID])
);

