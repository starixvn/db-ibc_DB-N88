/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20231220@Sally
	DB: DBN88-bodb_N88
	Task: MPA - Mapping data type between both sides- [Redmine: #198668]
		- Change DataType  Table BonusCode, TpBetRecord
*/
USE bodb_N88
GO
-- Table BonusInfo
	ALTER TABLE dbo.BonusInfo
	ALTER COLUMN LockedAmount DECIMAL(18,4)

	ALTER TABLE dbo.BonusInfo
	ALTER COLUMN BonusAmount DECIMAL(18,4)

-- Table TpBetRecord
---1. Step create new table 

	CREATE TABLE [dbo].[TpBetRecord_NEW](
		[TpId] [int] NOT NULL,
		[TransId] [varchar](100) NOT NULL,
		[GameType] [int] NOT NULL,
		[CustId] [varchar](45) NOT NULL,
		[UserName] [varchar](30) NOT NULL,
		[CurrencyId] [int] NOT NULL,
		[SiteId] [int] NOT NULL,
		[TpUserName] [varchar](50) NOT NULL,
		[TransTime] [datetime] NOT NULL,
		[SettledTime] [datetime] NOT NULL,
		[Stake] [decimal](20, 6) NOT NULL,
		[WinlostAmount] [decimal](20, 6) NOT NULL,
		[SettlementType] [tinyint] NOT NULL,
		[TicketStatus] [tinyint] NOT NULL,
		[OriginalState] [varchar](10) NULL,
		[TicketKey] [bigint] NOT NULL,
		[CreateTime] [datetime] NOT NULL,
		[WinlostDate] [smalldatetime] NULL,
		[ValidBet] [decimal](20, 6) NULL,
		[BonusId] [int] NULL,
		[Revenue] [decimal](20, 6) NULL,
		[ProgressiveBet] [decimal](20, 6) NULL,
		[ProgressiveWin] [decimal](20, 6) NULL,
	 CONSTRAINT [PK_TpBetRecord_NEW] PRIMARY KEY CLUSTERED 
	(
		[TpId] ASC,
		[TransId] ASC,
		[GameType] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
	) ON [ReportData]
	GO
--2. Insert data from TpBetRecord to TpBetRecord_NEW

 -- Using tool SSIS transfer data

--3. Create nonclustered Index on table TpBetRecord after transfer data into new table

	/****** Object:  Index [IX_CustId]  ******/
	CREATE NONCLUSTERED INDEX [IX_CustId] ON [dbo].[TpBetRecord_NEW]
	(
		[CustId] ASC,
		[GameType] ASC,
		[TicketStatus] ASC,
		[SettledTime] ASC
	)
	INCLUDE([TransTime],[TransId],[CurrencyId],[Stake],[ValidBet],[WinlostAmount],[Revenue],[ProgressiveWin],[ProgressiveBet]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
	GO


	/****** Object:  Index [IX_WinlostDate_TicketStatus] ******/
	CREATE NONCLUSTERED INDEX [IX_WinlostDate_TicketStatus] ON [dbo].[TpBetRecord_NEW]
	(
		[WinlostDate] ASC,
		[TicketStatus] ASC
	)
	INCLUDE([Stake],[ValidBet],[WinlostAmount],[Revenue],[CustId],[UserName],[CurrencyId],[SiteId],[TransTime],[SettledTime],[BonusId],[SettlementType]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
	GO

-- 4. Rename current table into old table

	/** Index **/
	EXEC sp_rename N'bodb_N88.dbo.TpBetRecord.PK_TpBetRecord', N'PK_TpBetRecord_Old', N'INDEX';  	
	GO
	/** Table **/
	EXEC sp_rename 'bodb_N88.dbo.TpBetRecord', 'TpBetRecord_Old'
	GO

-- 5. Modify new table

	/** Index **/
	EXEC sp_rename N'bodb_N88.dbo.TpBetRecord_NEW.PK_TpBetRecord_NEW', N'PK_TpBetRecord', N'INDEX';  	
	GO
	/** Table **/
	EXEC sp_rename 'bodb_N88.dbo.TpBetRecord_NEW', 'TpBetRecord'
	
	GO