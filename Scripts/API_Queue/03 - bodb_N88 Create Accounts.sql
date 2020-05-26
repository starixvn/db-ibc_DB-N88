/*<info serverAlias="DBN88-bodb_N88"></info>*/
USE [bodb_N88]
GO
/*
	Created: 20200520@Percy
	DB: DBN88-bodb_N88
	Task: Create new account
*/

CREATE USER [bodbAdminNet] FOR LOGIN [bodbAdminNet] WITH DEFAULT_SCHEMA=[dbo]
GO

CREATE USER [bodbDownlineNet] FOR LOGIN [bodbDownlineNet] WITH DEFAULT_SCHEMA=[dbo]
GO

CREATE USER [bodbDownlineNetView] FOR LOGIN [bodbDownlineNetView] WITH DEFAULT_SCHEMA=[dbo]
GO

CREATE USER [bodbLicenseeNet] FOR LOGIN [bodbLicenseeNet] WITH DEFAULT_SCHEMA=[dbo]
GO