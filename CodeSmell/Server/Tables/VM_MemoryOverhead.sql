CREATE TABLE [Server].[VM_MemoryOverhead] (
    [VM_Memory_MB_From] INT        NOT NULL,
    [VM_Memory_MB_Till] INT        NOT NULL,
    [vCPU]              INT        NOT NULL,
    [Memory_MB]         FLOAT (53) NOT NULL
);

