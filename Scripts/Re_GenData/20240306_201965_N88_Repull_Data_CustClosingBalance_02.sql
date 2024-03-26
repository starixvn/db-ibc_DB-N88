/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240305@Sally
	Task: Repull data from 03.03.2024
	DB: DBN88/bodb_N88
	- Repull data B2C CustClosingBalance
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO
DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.DataSource ='CustClosingBalance'
AND att.CalledTime >='2024-03-02 23:48:00'

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-03-05' AS CalledTime, t.KeyValue
FROM(
	SELECT 'CustClosingBalance' as DataSource, '2024-03-02T00:00:00.000' as KeyValue
)t
