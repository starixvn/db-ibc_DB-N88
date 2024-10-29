/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20241029@Sally
	Task: Repull data VipUpgradeReview from Aug
	DB: DBN88/bodb_N88
	- Repull data B2C BetRecord
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO
DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.DataSource  IN ('VipUpgradeReview')
	AND att.CalledTime >='2024-10-28'

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-10-28' AS CalledTime, t.KeyValue
FROM(
	SELECT 'VipUpgradeReview' as DataSource, '08/1/2024 12:00:00 AM' as KeyValue
)t
GO

