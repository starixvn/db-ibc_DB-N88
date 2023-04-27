/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230424@Malcolm
	Task: Update setting - [Redmine: #186979]
	DB: DBN88/bodb_N88
*/

/*DB053*/

USE [bodb_N88]
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

ALTER TABLE [dbo].[API_QueueTest] ADD  CONSTRAINT [DF_API_QueueTest_CheckInTime]  DEFAULT (getdate()) FOR [CheckInTime]
GO

ALTER TABLE [dbo].[API_QueueTest] ADD  CONSTRAINT [DF_API_QueueTest_IsFinished]  DEFAULT ((0)) FOR [IsFinished]
GO

CREATE CLUSTERED INDEX [CIX_DataSource] ON [dbo].[API_QueueTest]
(
	[DataSource] ASC,
	[IsFinished] ASC
) ON [ReportData]
GO
