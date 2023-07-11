/*<info serverAlias="DBN88LOG-bodb_N88LOG"></info>*/

/*
	Created: 20230706@Hogan
	DB: DBN88LOG.bodb_N88LOG
	Task: Add new Action update user setting [RedmineID: #189299]
*/

USE bodb_N88LOG
GO

INSERT INTO dbo.N88Log_Action(ActionId,ActionTypeId,SPName,ActionName,Items,SubItems)
VALUES (500, 6, 'N88_Setting_UpdateByUser', 'Update data limit to user', '<root><xml path="r" /><row item="UserId" alias="u" /></root>', '<root><xml path="r/z" /><row item="SettingKey" alias="k" /><row item="SettingValue" alias="v" /></root>')

GO
