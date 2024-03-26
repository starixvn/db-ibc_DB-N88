/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240305@Sally
	Task: Repull data from 03.03.2024
	DB: DBN88/bodb_N88
	- Repull data B2C
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO

DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.CalledTime >='2024-03-02 23:48:00'

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-03-05' AS CalledTime, t.KeyValue
FROM (
	SELECT 'AdjustmentInfo' as DataSource, '52772' as KeyValue UNION ALL
	SELECT 'BonusInfo' as DataSource, '1156096' as KeyValue UNION ALL
	SELECT 'CustBonusRollover' as DataSource, '1156097' as KeyValue UNION ALL
	SELECT 'Customer' as DataSource, '3/3/2024 3:13:47' as KeyValue UNION ALL
	SELECT 'CustRegInfo' as DataSource, '3/2/2024 3:13:00' as KeyValue UNION ALL
	SELECT 'CustVerificationReward' as DataSource, '3/3/2024 3:29:35' as KeyValue UNION ALL
	SELECT 'DepositInfo' as DataSource, '{"Id":7752803,"UpdateTime":"2024-03-03T03:34:33"}' as KeyValue UNION ALL
	SELECT 'DrawLog' as DataSource, '1757498' as KeyValue UNION ALL
	SELECT 'EventDraw' as DataSource, '17' as KeyValue UNION ALL
	SELECT 'LogAdminAdjustWallet' as DataSource, '141' as KeyValue UNION ALL
	SELECT 'Promotion' as DataSource, '3/2/2024 22:00:00' as KeyValue UNION ALL
	SELECT 'PromotionSpecific' as DataSource, '3/3/2024 2:00:00' as KeyValue UNION ALL
	SELECT 'RebateMLog' as DataSource, '3/3/2024 2:30:00' as KeyValue UNION ALL
	SELECT 'ReferralLog' as DataSource, '52924' as KeyValue UNION ALL
	SELECT 'ReferralMLog' as DataSource, '48128' as KeyValue UNION ALL
	SELECT 'TpBetRecord' as DataSource, '3/3/2024 3:30:00' as KeyValue UNION ALL
	SELECT 'TpReport9W' as DataSource, '3/2/2024 23:02:43' as KeyValue UNION ALL
	SELECT 'TpWager9W' as DataSource, '3/2/2024 23:14:29' as KeyValue UNION ALL
	SELECT 'WithdrawalInfo' as DataSource, '3/3/2024 3:38:00' as KeyValue UNION ALL
	SELECT 'TpTransferInfo' as DataSource, '14091150' as KeyValue UNION ALL
	SELECT 'VipUpgradeReview' as DataSource, '3/1/2024 0:00:00' as KeyValue UNION ALL
	SELECT 'WeeklyBonusInfo' as DataSource, '{"Date":"2024-02-26T00:00:00-04:00","PageIndex":0}' as KeyValue
)t
GO

DELETE r
FROM dbo.API_PushDataTracker r WITH (ROWLOCK, UPDLOCK)
WHERE PushTrackerId = 676
