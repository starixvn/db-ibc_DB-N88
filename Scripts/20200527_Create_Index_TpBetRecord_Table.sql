/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20200527@Sol
	Task: Create index for Tpbetrecord table - [Redmine:#133254]
	DB: DBN88/bodb_N88
*/

USE bodb_N88

GO

CREATE NONCLUSTERED INDEX IX_WinlostDate_TicketStatus ON dbo.TpBetRecord (WinlostDate, TicketStatus)
	INCLUDE (Stake,WinlostAmount,CustId,UserName,CurrencyId,SiteId,TransTime,SettledTime)
		ON [ReportData]
GO