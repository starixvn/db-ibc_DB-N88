/*<info serverAlias="DBN88-bodb_N88" ></info>*/
/*
	Created: 20230809@Sally
	DB: DBN88-bodb_N88
	Task: B2C - Aff - Insert data into B2C DB after approve Affiliate [Redmine: #192191]
		- Create table stored Push data tracking
		
*/  
USE [bodb_N88]
GO

CREATE TABLE [dbo].[API_PushDataTracker](
	[PushTrackerId] [bigint] IDENTITY(1,1) NOT NULL,
	[CheckInTime] [datetime] NULL,
	[FinishedTime] [datetime] NULL,
	[StatusId] [tinyint] NULL,
	[PushDataType] [smallint] NULL,
	[PushDataInfo] [NVARCHAR](MAX) NULL
 CONSTRAINT [PK_API_PushDataTracker] PRIMARY KEY NONCLUSTERED 
(
	[PushTrackerId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
) ON [ReportData] TEXTIMAGE_ON [ReportData]
GO

ALTER TABLE [dbo].[API_PushDataTracker] ADD  CONSTRAINT [DF_API_PushDataTracker_CheckInTime]  DEFAULT (GETDATE()) FOR [CheckInTime]
GO
ALTER TABLE [dbo].[API_PushDataTracker] ADD  CONSTRAINT [DF_API_PushDataTracker_StatusId]  DEFAULT ((0)) FOR [StatusId]
GO
ALTER TABLE [dbo].[API_PushDataTracker] ADD  CONSTRAINT [DF_API_PushDataTracker_DataTrackerType]  DEFAULT ((1)) FOR [PushDataType]
GO

CREATE CLUSTERED INDEX CIX_PushDataTracker_PushDataType ON dbo.API_PushDataTracker (PushDataType ASC, StatusId ASC)  
WITH (PAD_INDEX = OFF, FILLFACTOR = 100, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [ReportData] ;


