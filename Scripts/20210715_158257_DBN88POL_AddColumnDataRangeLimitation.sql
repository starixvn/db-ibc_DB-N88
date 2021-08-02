/*<info serverAlias="DBN88POL-N88_UserControl"></info>*/

/*
	Created: 20210715@Hogan
	DB: DBN88POL.N88_UserControl
	Task: Add new column DataRangeLimitation to table N88_Users [RedmineID: #158257]
*/

USE N88_UserControl
GO

ALTER TABLE N88_Users
ADD DataRangeLimitation INT

GO