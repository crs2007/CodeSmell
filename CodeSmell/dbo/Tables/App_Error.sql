CREATE TABLE [dbo].[App_Error] (
    [ID]                INT            NOT NULL,
    [Name]              NVARCHAR (255) NOT NULL,
    [IsActive]          BIT            NOT NULL,
    [URL_Reference]     VARCHAR (512)  NULL,
    [IsCheckOnProcName] BIT            NOT NULL,
    [SubjectGroupID]    INT            NULL,
    [DBVersionID]       INT            NOT NULL,
    [SeverityID]        INT            NULL,
    [Message]           VARCHAR (1000) NULL,
    CONSTRAINT [PK_App_Error] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_App_Error_App_DBVersion] FOREIGN KEY ([DBVersionID]) REFERENCES [dbo].[App_DBVersion] ([ID]),
    CONSTRAINT [FK_App_Error_App_Severity] FOREIGN KEY ([SeverityID]) REFERENCES [dbo].[App_Severity] ([ID]),
    CONSTRAINT [FK_App_Error_App_SubjectGroup] FOREIGN KEY ([SubjectGroupID]) REFERENCES [dbo].[App_SubjectGroup] ([ID])
);





