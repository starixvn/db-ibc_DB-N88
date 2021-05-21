/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20210506@Kos
	Task: Create index for TpBetRecord table [Redmine: #139333]
	DB: DBN88/bodb_N88
*/

USE bodb_N88

GO

DROP INDEX [IX_CustId] ON [dbo].[TpBetRecord]

GO

CREATE NONCLUSTERED INDEX [IX_CustId] ON [dbo].[TpBetRecord]
(
	[CustId] ASC,
	[TicketStatus] ASC
)
INCLUDE 
(
	[SettledTime],
	[TransTime],
	[SiteId],
	[CurrencyId],
	[Stake],
	[WinlostAmount],
	[Revenue]
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [ReportData]
GO
