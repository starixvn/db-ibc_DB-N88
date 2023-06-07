/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230522@Sally
	DB: DBN88-bodb_N88
	Task: Affiliate - Handling BDT/ USD (72) currency  [RedmineID: #188429]
	Step 1 : Config mapping currency 72
*/
---1. Insert mapping currency 72 
INSERT INTO dbo.TpExchange (
	TpExchangeId,
	ExchangeId
)
SELECT T.TpExchangeId
	,T.ExchangeId
FROM (
	SELECT 72 AS TpExchangeId, 3 AS  ExchangeId
	UNION ALL
	SELECT 3 AS TpExchangeId, 3 AS  ExchangeId
)T
	LEFT JOIN dbo.TpExchange TP WITH (NOLOCK) ON T.ExchangeId = TP.ExchangeId
											AND T.TpExchangeId = TP.TpExchangeId
	WHERE TP.ExchangeId IS NULL
GO

---2.  Checking Data inserted 
SELECT TOP 10 *
FROM TpExchange WITH (NOLOCK)
