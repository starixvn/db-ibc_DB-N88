/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20221011@Malcolm
	Task: Create new table - [Redmine:#177893]
	DB: DBN88/bodb_N88
*/

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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
) ON [ReportData] TEXTIMAGE_ON [ReportData]
GO

CREATE CLUSTERED INDEX [CIX_DataSource] ON [dbo].[API_QueueTest]
(
	[DataSource] ASC,
	[IsFinished] ASC
) ON [ReportData]
GO

ALTER TABLE [dbo].[API_QueueTest] ADD  CONSTRAINT [DF_API_QueueTest_CheckInTime]  DEFAULT (getdate()) FOR [CheckInTime]
GO

ALTER TABLE [dbo].[API_QueueTest] ADD  CONSTRAINT [DF_API_QueueTest_IsFinished]  DEFAULT ((0)) FOR [IsFinished]
GO

CREATE TABLE [dbo].[TpBetRecordTest](
	[TpId] [int] NOT NULL,
	[TransId] [varchar](50) NOT NULL,
	[GameType] [int] NOT NULL,
	[CustId] [varchar](45) NOT NULL,
	[UserName] [varchar](30) NOT NULL,
	[CurrencyId] [int] NOT NULL,
	[SiteId] [int] NOT NULL,
	[TpUserName] [varchar](50) NOT NULL,
	[TransTime] [datetime] NOT NULL,
	[SettledTime] [datetime] NOT NULL,
	[Stake] [decimal](20, 4) NULL,
	[WinlostAmount] [decimal](20, 4) NULL,
	[SettlementType] [tinyint] NOT NULL,
	[TicketStatus] [tinyint] NOT NULL,
	[OriginalState] [varchar](10) NULL,
	[TicketKey] [bigint] NOT NULL,
	[CreateTime] [datetime] NOT NULL,
	[WinlostDate] [smalldatetime] NULL,
	[ValidBet] [decimal](20, 4) NULL,
	[BonusId] [int] NULL,
	[Revenue] [decimal](20, 4) NULL,
	[ProgressiveBet] [decimal](20, 4) NULL,
	[ProgressiveWin] [decimal](20, 4) NULL,
 CONSTRAINT [PK_TpBetRecordTest] PRIMARY KEY CLUSTERED 
(
	[TpId] ASC,
	[TransId] ASC,
	[GameType] ASC
) ON [ReportData]
) ON [ReportData]
GO

CREATE NONCLUSTERED INDEX [IX_CustId] ON [dbo].[TpBetRecordTest]
(
	[CustId] ASC,
	[GameType] ASC,
	[TicketStatus] ASC,
	[SettledTime] ASC
)
INCLUDE([TransTime],[TransId],[CurrencyId],[Stake],[ValidBet],[WinlostAmount],[Revenue],[ProgressiveWin],[ProgressiveBet]) ON [ReportData]
GO

CREATE NONCLUSTERED INDEX [IX_WinlostDate_TicketStatus] ON [dbo].[TpBetRecordTest]
(
	[WinlostDate] ASC,
	[TicketStatus] ASC
)
INCLUDE([Stake],[ValidBet],[WinlostAmount],[Revenue],[CustId],[UserName],[CurrencyId],[SiteId],[TransTime],[SettledTime],[BonusId],[SettlementType],[ProgressiveBet],[ProgressiveWin])  ON [ReportData]
GO

