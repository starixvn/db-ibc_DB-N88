/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20210218@Percy
	DB: DBN88-bodb_N88
	Task: Sum data for TpBetRecord
*/

USE bodb_N88

GO

CREATE TABLE dbo.N88_SumWinloss
(
	CustId			INT
	,UserName		VARCHAR(50)
	,IsTest			BIT
	,Currency		INT
	,SiteId			INT
	,GameType		INT
	,TransTime		DATETIME
	,SettledTime	DATETIME
	,TurnOver		MONEY
	,ValidBet		MONEY
	,Winloss		MONEY
	,BetCount		INT
	,StatusId		TINYINT
) ON PS_N88_SumWinloss_Monthly (SettledTime)

GO

CREATE CLUSTERED INDEX CIX_N88_SumWinloss ON dbo.N88_SumWinloss
(
	SettledTime ASC,
	SiteId ASC,
	CustId ASC
)

GO

CREATE NONCLUSTERED INDEX IX_TransTime ON dbo.N88_SumWinloss
(
	TransTime ASC
)
INCLUDE
(
	GameType, Currency, TurnOver, ValidBet, Winloss, BetCount, StatusId, UserName, IsTest
)

GO