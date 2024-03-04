/*<info serverAlias="DBN88-bodb_N88_Archive"></info>*/
/*	
	Created: 20240304@Sally
	DB: DBN88-bodb_N88_Archive
	Task: Grant Permission for bodbLicenseeNet account
		
*/
USE bodb_N88_Archive
GO

CREATE USER [bodbLicenseeNet] FOR LOGIN [bodbLicenseeNet] WITH DEFAULT_SCHEMA=[dbo]
GO

GRANT SELECT ON TpBetRecord_bk TO bodbLicenseeNet

