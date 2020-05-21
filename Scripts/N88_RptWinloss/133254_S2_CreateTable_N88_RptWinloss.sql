/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20200511@Sol
	Task: Get match that settled without ticket - [Redmine:#133254]
	DB: DBN88/bodb_N88
*/

USE bodb_N88;

GO 

CREATE TABLE [dbo].N88_RptWinloss(
	WinlostDate	DATE NOT NULL,
	CustId	INT NOT NULL,
	GameType	INT NOT NULL,
	Currency	INT NOT NULL,
	TurnOver	MONEY NULL,
	Winloss	MONEY NULL,
	BetCount	INT NULL,
	LicenseeID	INT NOT NULL,
	StatusID	TINYINT NOT NULL,
	UserName	VARCHAR(30) NOT NULL,
	WinlostDateGMT	DATE NOT NULL,
	[TimeZone]	SMALLINT NOT NULL,
	TransDate DATE NOT NULL,
	TransDateGMT DATE NOT NULL,
	IsTest BIT NOT NULL
) ON ps_N88_rptWinloss_monthly(WinlostDate)

GO

CREATE CLUSTERED INDEX CIX_N88_RptWinloss ON [dbo].[N88_RptWinloss]
(
	[WinlostDate] ASC,
	[TimeZone] ASC,
	[WinlostDateGMT] ASC,
	[CustId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO