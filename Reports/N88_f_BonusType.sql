/*<info serverAlias="DBN88-bodb_N88" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
USE bodb_N88
GO

ALTER FUNCTION [dbo].[N88_f_BonusType]()
RETURNS TABLE
AS

/*
	Created: 20211028@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Get Bonus Type List

	Revisions:
		- 20211028@Percy: Initialize function [RedmineID: #161048]
		- 20211118@Percy: Add DataSource: LogAdminAdjustWallet [RedmineID: #161048]
		- 20211216@Percy: Add new type: Retention Free Bet [RedmineID: #166196]
		- 20220311@Percy: Add new type: Manual Bonus [RedmineID: #169823]
		- 20220325@Percy: Add new type: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Add new type: Referral [RedmineID: #170390]
*/

RETURN
	SELECT DBTypeId, BonusTypeId, BonusTypeName, DataSource
		,CONVERT(SMALLINT, DENSE_RANK() OVER(ORDER BY CASE BonusTypeId WHEN 0 THEN 1000 WHEN 101 THEN 999 ELSE 0 END, BonusTypeName)) AS OrderId
	FROM (
		VALUES (CONVERT(SMALLINT, 0), CONVERT(SMALLINT, 0), CONVERT(VARCHAR(100), 'Unidentified'), CONVERT(VARCHAR(100), 'BonusInfo'))
		,(1, 1, 'Welcome Bonus', 'BonusInfo')
		,(2, 2, 'ReDeposit', 'BonusInfo')
		,(3, 3, 'FreeBet', 'BonusInfo')
		,(7, 7, 'Cashback', 'BonusInfo')
		,(8, 8, 'Manual Bonus', 'BonusInfo')
		,(9, 9, 'Retention Free Bet', 'BonusInfo')
		,(0, 0, 'Unidentified', 'RebateMLog')
		,(1, 6, 'Rebate', 'RebateMLog')
		,(1, 101, 'Others', 'AdjustmentInfo') -- Credit
		,(2, 101, 'Others', 'AdjustmentInfo') -- Debit
		,(3, 101, 'Others', 'AdjustmentInfo') -- Increase bonus
		,(4, 101, 'Others', 'AdjustmentInfo') -- Decrease bonus
		,(1, 101, 'Others', 'LogAdminAdjustWallet') -- 3rd Add
		,(2, 101, 'Others', 'LogAdminAdjustWallet') -- 3rd Minus
		,(0, 102, 'Prize Draw', 'DrawLog')
		,(0, 103, 'VIP Upgrade', 'VIPUpgradeReview')
		,(1, 104, 'Verification Reward', 'CustVerificationReward') -- Phone Reward
		,(2, 104, 'Verification Reward', 'CustVerificationReward') -- Email Reward
		,(0, 105, 'Referral', 'ReferralMLog')
	) AS t (DBTypeId, BonusTypeId, BonusTypeName, DataSource)
GO