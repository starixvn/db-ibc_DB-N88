/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_BonusType_Sel]
AS

/*
	Created: 20211028@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Get Bonus Type List

	Revisions:
		- 20211028@Percy: Initialize SP [RedmineID: #161048]
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT BonusTypeId, BonusTypeName, OrderId
	FROM dbo.N88_f_BonusType()
	ORDER BY OrderId
END
GO