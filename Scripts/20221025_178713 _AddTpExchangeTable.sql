/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*
	Created: 20221025@Malcolm
	Task: Add new table [Redmine: #178713]
	DB: DBN88-bodb_N88
*/

CREATE TABLE dbo.TpExchange
(
	TpExchangeId INT
	,ExchangeId INT
	,CONSTRAINT [PK_TpExchange] PRIMARY KEY NONCLUSTERED 
	(
		TpExchangeId
	)
) ON [ReportData]


INSERT INTO dbo.TpExchange (TpExchangeId, ExchangeId)
VALUES (74, 97)