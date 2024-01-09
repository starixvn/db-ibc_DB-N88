/*<info serverAlias="DBN88-bodb_N88_Archive"></info>*/
/*	
	Created: 20231220@Sally
	DB: DBN88-bodb_N88_Archive
	Task: MPA - Mapping data type between both sides- [Redmine: #198668]
		- Change DataType Table TpBetRecord_bk
*/
USE bodb_N88_Archive
GO

-- Table TpBetRecord_bk
---1. Step create new table 
	
	CREATE TABLE [dbo].[TpBetRecord_bk_NEW](
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
	 CONSTRAINT [PK_TpBetRecord_bk_2_NEW] PRIMARY KEY NONCLUSTERED 
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

	/****** Object:  Index [IX_CustId_2]  ******/
	CREATE NONCLUSTERED INDEX [IX_CustId_2] ON [dbo].[TpBetRecord_bk_NEW]
	(
		[CustId] ASC,
		[GameType] ASC,
		[TicketStatus] ASC,
		[SettledTime] ASC
	)
	INCLUDE([TransTime],[TransId],[CurrencyId],[Stake],[ValidBet],[WinlostAmount],[Revenue],[ProgressiveWin],[ProgressiveBet]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
	GO


	/****** Object:  Index [CIX_WinlostDate_bk_2]******/
	CREATE CLUSTERED INDEX [CIX_WinlostDate_bk_2] ON [dbo].[TpBetRecord_bk_NEW]
	(
		[WinlostDate] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ReportData]
	GO

-- 4. Rename current table into old table

	/** Index **/
	EXEC sp_rename N'bodb_N88_Archive.dbo.TpBetRecord_bk.PK_TpBetRecord_bk_2', N'PK_TpBetRecord_bk_2_Old', N'INDEX';  	

	/** Table **/
	EXEC sp_rename 'bodb_N88_Archive.dbo.TpBetRecord_bk', 'TpBetRecord_bk_Old'
	GO

-- 5. Modify new table

	/** Index **/
	EXEC sp_rename N'bodb_N88_Archive.dbo.TpBetRecord_bk_NEW.PK_TpBetRecord_bk_2_NEW', N'PK_TpBetRecord_bk_2', N'INDEX';  	
	GO
	/** Table **/
	EXEC sp_rename 'bodb_N88_Archive.dbo.TpBetRecord_bk_NEW', 'TpBetRecord_bk'
	
	GO

