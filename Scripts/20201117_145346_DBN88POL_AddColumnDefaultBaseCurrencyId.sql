/*<info serverAlias="DBN88POL-N88_UserControl"></info>*/

/*
	Created: 20201117@Kos
	DB: DBN88POL.N88_UserControl
	Task: Add new column DefaultBaseCurrencyId to table N88_Users [RedmineID: #145346]
*/

USE N88_UserControl
GO

ALTER TABLE N88_Users
ADD DefaultBaseCurrencyId INT

GO