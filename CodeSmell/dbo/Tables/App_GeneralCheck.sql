CREATE TABLE [dbo].[App_GeneralCheck] (
    [ID]               INT            NOT NULL,
    [Name]             NVARCHAR (255) NOT NULL,
    [Massege]          VARCHAR (1000) NULL,
    [IsActive]         BIT            NOT NULL,
    [URL_Reference]    VARCHAR (512)  NULL,
    [SubjectGroupID]   INT            NULL,
    [DBVersionID]      INT            NOT NULL,
    [SeverityID]       INT            NULL,
    [IsOnSingleObject] BIT            CONSTRAINT [DF_App_GeneralCheck_IsOnSingleObject] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_App_GeneralCheck] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_App_GeneralCheck_App_Severity] FOREIGN KEY ([SeverityID]) REFERENCES [dbo].[App_Severity] ([ID])
);

