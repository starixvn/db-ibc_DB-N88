/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE [bodb_N88]
GO
/*
	Created: 20230412@Malcolm
	DB: DBN88-bodb_N88
	Task: Create new table [RedmineID: #183319]
	Run ON DB053
*/

-- Only Run DB053 (don't run ON DB052)

USE bodb_N88;
GO

CREATE TABLE [dbo].[API_QueueTest](
	[QueueId] [bigint] IDENTITY(1,1) NOT NULL,
	[CheckInTime] [datetime] NULL,
	[FinishedTime] [datetime] NULL,
	[IsFinished] [bit] NULL,
	[XmlData] [xml] NULL,
	[DataSource] [varchar](200) NULL,
	[LogDesc] [varchar](2000) NULL,
 CONSTRAINT [PK_API_QueueTest] PRIMARY KEY NONCLUSTERED 
(
	[QueueId] ASC
) ON [ReportData]
) ON [ReportData] TEXTIMAGE_ON [ReportData]
GO

CREATE CLUSTERED INDEX [CIX_DataSource] ON [dbo].[API_QueueTest]
(
	[DataSource] ASC,
	[IsFinished] ASC
) ON [ReportData]
GO

CREATE TABLE [dbo].[SystemSettingsTest](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SName] [varchar](50) NOT NULL,
	[SValue] [varchar](200) NULL,
 CONSTRAINT [PK_SystemSettingsTest] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
) ON [SettingData]
) ON [SettingData]
GO

INSERT INTO dbo.SystemSettingsTest([SName], [SValue])
VALUES ('BatchSize', '50')



