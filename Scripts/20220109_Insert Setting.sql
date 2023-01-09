/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230109@Malcolm
	Task: Add setting [RedmineId: 182738]
	DB: DBN88/bodb_N88
*/

USE bodb_N88
GO

INSERT INTO dbo.SystemSettings (SName, SValue)
VALUES ('UpdatedCustomer_Date', CONVERT(VARCHAR(100), GETDATE(), 120))