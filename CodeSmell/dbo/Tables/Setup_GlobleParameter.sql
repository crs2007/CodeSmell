CREATE TABLE [dbo].[Setup_GlobleParameter] (
    [ID]    INT            NOT NULL,
    [Name]  NVARCHAR (255) NOT NULL,
    [Value] NVARCHAR (255) NOT NULL,
    CONSTRAINT [PK_Setup_GlobleParameter] PRIMARY KEY CLUSTERED ([ID] ASC)
);

