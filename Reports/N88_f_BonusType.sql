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
*/

RETURN
	SELECT DBTypeId, BonusTypeId, BonusTypeName, DataSource
		,CONVERT(SMALLINT, DENSE_RANK() OVER(ORDER BY CASE BonusTypeId WHEN 0 THEN 1000 WHEN 101 THEN 999 ELSE 0 END, BonusTypeName)) AS OrderId
	FROM (
		VALUES (CONVERT(SMALLINT, 0), CONVERT(SMALLINT, 0), CONVERT(VARCHAR(100), 'Unidentified'), CONVERT(VARCHAR(100), 'BonusInfo'))
		,(1, 1, 'Welcome Bonus', 'BonusInfo'), (2, 2, 'ReDeposit', 'BonusInfo'), (3, 3, 'FreeBet', 'BonusInfo'), (7, 7, 'Cashback', 'BonusInfo')
		,(0, 0, 'Unidentified', 'RebateMLog'), (1, 6, 'Rebate', 'RebateMLog')
		,(101, 101, 'Others', 'AdjustmentInfo') -- Manual Adjustment
		,(102, 102, 'Prize Draw', 'DrawLog')
		,(103, 103, 'VIP Upgrade', 'VIPUpgradeReview')
	) AS t (DBTypeId, BonusTypeId, BonusTypeName, DataSource)
GO