/*<info serverAlias="DBN88LOG-bodb_N88LOG"></info>*/

/*
	Created: 20201124@Hogan
	DB: DBN88LOG.bodb_N88LOG
	Task: Add column DefaultBaseCurrency to log [RedmineID: #145346]
*/

USE bodb_N88LOG
GO

UPDATE N88Log_Action WITH (ROWLOCK, UPDLOCK)
SET Items = '<root><xml path="r" /><row item="Username" alias="u" /><row item="UserId" alias="ui" /><row item="GroupId" alias="gi" /><row item="GroupName" alias="g" /><row item="FirstName" alias="f" /><row item="LastName" alias="l" /><row item="Email" alias="e" /><row item="IsLicenseeUser" alias="il" /><row item="SourceSiteId" alias="si" /><row item="SourceSiteName" alias="sn" /><row item="DefaultBaseCurrencyId" alias="bc" /><row item="DefaultBaseCurrencyCode" alias="bcc" /></root>'
WHERE ActionId = 100

GO

UPDATE N88Log_Action WITH (ROWLOCK, UPDLOCK)
SET Items = '<root><xml path="r" /><row item="Username" alias="u" /><row item="UserId" alias="ui" /><row item="GroupId" alias="gi" /><row item="GroupName" alias="g" /><row item="FirstName" alias="f" /><row item="LastName" alias="l" /><row item="Email" alias="e" /><row item="DefaultBaseCurrencyId" alias="bc" /><row item="DefaultBaseCurrencyCode" alias="bcc" /></root>'
WHERE ActionId = 200

GO

UPDATE N88Log_Action WITH (ROWLOCK, UPDLOCK)
SET SPName = 'N88_User_AddToGroup'
WHERE ActionId = 107

GO