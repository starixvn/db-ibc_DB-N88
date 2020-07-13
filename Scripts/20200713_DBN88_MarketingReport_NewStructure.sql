/*<info serverAlias="DBN88-bodb_N88"></info>*/

/*
	Created: 20200713@Percy
	DB: DBN88-bodb_N88
	Task: Novacash Licensee
		1. New tables: DepositInfo and TpTransferInfo
		2. New index on N88_RptWinloss (TransDate column)
*/

USE bodb_N88
GO

-- 1. DepositInfo
CREATE TABLE dbo.DepositInfo
(
	DepositId int
	,TransId varchar(30)
	,DepositType tinyint
	,CustId int
	,UserName varchar(30)
	,CurrencyId tinyint
	,SiteId int
	,DepositInfo nvarchar(max)
	,Amount decimal(18,4)
	,ActualDeposit decimal(18,4)
	,CreateTime datetime
	,TPCreateTime datetime
	,CallbackTime datetime
	,FirstDeposit bit
	,ThirdId varchar(100)
	,RefId varchar(100)
	,DepositTime datetime
	,Memo varchar(100)
	,PostScript varchar(45)
	,Comment varchar(500)
	,Status tinyint
	,WinlostDate AS CAST (CreateTime AS date)
	,CONSTRAINT PK_DepositInfo PRIMARY KEY NONCLUSTERED
	(
		DepositId
	) ON [ReportData]
) ON [ReportData]
GO
CREATE CLUSTERED INDEX CIX_DepositInfo ON dbo.DepositInfo (WinlostDate) ON [ReportData]
GO


-- 2. TpTransferInfo
CREATE TABLE dbo.TpTransferInfo
(
	TransferId int not null
	,TransId varchar(30)
	,TpId int
	,CustId int
	,UserName varchar(30)
	,SiteId int
	,Direction tinyint
	,Amount decimal(18,2)
	,Memo varchar(100)
	,Status tinyint
	,CreateTime datetime
	,ThirdId varchar(50)
	,WinlostDate AS CAST (CreateTime AS date)
	,CONSTRAINT PK_TpTransferInfo PRIMARY KEY NONCLUSTERED
	(
		TransferId
	) ON [ReportData]
) ON [ReportData]
GO
CREATE CLUSTERED INDEX CIX_TpTransferInfo ON dbo.TpTransferInfo (WinlostDate) ON [ReportData]
GO


-- 3. N88_RptWinloss
CREATE NONCLUSTERED INDEX IX_TransDate ON dbo.N88_RptWinloss (TransDate, TimeZone, TransDateGMT)
	INCLUDE (GameType, Currency, TurnOver, Winloss, BetCount, LicenseeID, StatusID)
	ON ps_N88_rptWinloss_monthly (TransDate)
GO