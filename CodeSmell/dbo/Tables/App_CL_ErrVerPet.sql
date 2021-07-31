CREATE TABLE [dbo].[App_CL_ErrVerPet] (
    [ID]                   INT     NOT NULL,
    [RegexPetternID]       INT     NOT NULL,
    [ErrorID]              INT     NOT NULL,
    [SearchRegexMethodID]  INT     CONSTRAINT [DF_App_CL_ErrVerPet_SearchRegexMethodID] DEFAULT ((1)) NOT NULL,
    [NotIn_RegexPetternID] INT     NULL,
    [TriggerEvent_Bitmask] INT     NULL,
    [CodeTypeID]           TINYINT CONSTRAINT [DF_App_CL_ErrVerPet_CodeTypeID] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_App_CL_ErrVerPet] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_App_CL_ErrVerPet_App_CodeType] FOREIGN KEY ([CodeTypeID]) REFERENCES [dbo].[App_CodeType] ([ID]),
    CONSTRAINT [FK_App_CL_ErrVerPet_App_enum_SearchRegexMethod] FOREIGN KEY ([SearchRegexMethodID]) REFERENCES [dbo].[App_enum_SearchRegexMethod] ([ID]),
    CONSTRAINT [FK_App_CL_ErrVerPet_App_Error] FOREIGN KEY ([ErrorID]) REFERENCES [dbo].[App_Error] ([ID]),
    CONSTRAINT [FK_App_CL_ErrVerPet_App_RegexPettern] FOREIGN KEY ([RegexPetternID]) REFERENCES [dbo].[App_RegexPettern] ([ID]),
    CONSTRAINT [FK_App_CL_ErrVerPet_App_RegexPettern_NotIn] FOREIGN KEY ([NotIn_RegexPetternID]) REFERENCES [dbo].[App_RegexPettern] ([ID])
);




GO
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'CodeType for Clean\With texts\Only remarks', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'App_CL_ErrVerPet', @level2type = N'COLUMN', @level2name = N'CodeTypeID';


GO
EXECUTE sp_addextendedproperty @name = N'CREATE', @value = N'20210711', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'App_CL_ErrVerPet', @level2type = N'COLUMN', @level2name = N'CodeTypeID';

