/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240308@Sally
	Task: Repull data from 01.03.2024
	DB: DBN88/bodb_N88
	- Repull data B2C
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO

DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.CalledTime >='2024-03-06 00:00:00'
AND  att.DataSource IN ('BonusInfo','Customer','DepositInfo','TpBetRecord','WithdrawalInfo','CustClosingBalance')

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-03-08' AS CalledTime, t.KeyValue
FROM (

	SELECT 'BonusInfo' as DataSource, '1156096' as KeyValue UNION ALL
	SELECT 'Customer' as DataSource, '2024-03-01 00:00:00' as KeyValue UNION ALL
	SELECT 'DepositInfo' as DataSource, '{"Id":7752803,"UpdateTime":"2024-03-01T00:00:00"}' as KeyValue UNION ALL
	SELECT 'TpBetRecord' as DataSource, '2024-03-01 00:00:00' as KeyValue UNION ALL
	SELECT 'WithdrawalInfo' as DataSource, '2024-03-01 00:00:00' as KeyValue UNION ALL
	SELECT 'CustClosingBalance' as DataSource, '2024-03-01T00:00:00.000' as KeyValue

)t
GO
