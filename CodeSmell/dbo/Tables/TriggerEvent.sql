CREATE TABLE [dbo].[TriggerEvent] (
    [ID]          INT          NOT NULL,
    [Name]        VARCHAR (50) NOT NULL,
    [BitmaskFlag] INT          NOT NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_TriggerEvent]
    ON [dbo].[TriggerEvent]([Name] ASC)
    INCLUDE([BitmaskFlag]);


GO
CREATE CLUSTERED INDEX [PK_TriggerEvent]
    ON [dbo].[TriggerEvent]([ID] ASC);

