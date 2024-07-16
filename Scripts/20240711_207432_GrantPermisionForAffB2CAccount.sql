/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20240711@Sally
	Task: Exclude data Aff accounts test
	DB: DBN88/bodb_N88
	- Grant permission SELECT on table Customer for 'wsv_afinet' Account
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO

CREATE USER [wsv_afinet] FOR LOGIN [wsv_afinet] WITH DEFAULT_SCHEMA=[dbo]
GO

GRANT SELECT ON [dbo].[Customer] TO [wsv_afinet]
GO
