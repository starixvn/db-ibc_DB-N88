/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230301@Malcolm
	Task: Create ReferralLog table - [Redmine: #183930]
	DB: DBN88/bodb_N88
*/

CREATE TABLE dbo.ReferralLog
(
	SQ					INT NOT NULL
	,CustId				INT NOT NULL
	,CurrencyId			TINYINT NULL
	,UserName			VARCHAR(30) NULL
	,SiteId				INT NULL
	,ReferralFreeCredit DECIMAL(18,4)
	,AgentId			INT NULL
	,ReferralAmount		DECIMAL(18,4) NULL
	,Memo				VARCHAR(200) NULL
	,RelId				BIGINT NULL
	,CreateTime			DATETIME NULL
	,RewardStatus		TINYINT NULL
	,WinlostDate		AS (CONVERT([date],[CreateTime],(0)))
	,CONSTRAINT PK_ReferralLog PRIMARY KEY NONCLUSTERED 
	(	
		SQ
	)
)
GO

CREATE CLUSTERED INDEX CIX_ReferralLog ON dbo.ReferralLog (WinlostDate)
GO


