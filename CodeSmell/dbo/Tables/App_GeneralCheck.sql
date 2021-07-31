CREATE TABLE [dbo].[App_GeneralCheck] (
    [ID]                   INT            NOT NULL,
    [Name]                 NVARCHAR (255) NOT NULL,
    [IsActive]             BIT            NOT NULL,
    [URL_Reference]        VARCHAR (512)  NULL,
    [SubjectGroupID]       INT            NULL,
    [DBVersionID]          INT            NOT NULL,
    [SeverityID]           INT            NULL,
    [IsOnSingleObject]     BIT            CONSTRAINT [DF_App_GeneralCheck_IsOnSingleObject] DEFAULT ((0)) NOT NULL,
    [IsOnSingleObjectOnly] BIT            CONSTRAINT [DF_App_GeneralCheck_IsOnSingleObjectOnly] DEFAULT ((0)) NOT NULL,
    [IsPhysicalObject]     BIT            CONSTRAINT [DF_App_GeneralCheck_IsPhysicalObject] DEFAULT ((0)) NOT NULL,
    [Message]              VARCHAR (1000) NULL,
    CONSTRAINT [PK_App_GeneralCheck] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_App_GeneralCheck_App_Severity] FOREIGN KEY ([SeverityID]) REFERENCES [dbo].[App_Severity] ([ID])
);



