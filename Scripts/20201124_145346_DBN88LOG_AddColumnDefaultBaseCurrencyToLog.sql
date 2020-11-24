/*<info serverAlias="DBN88LOG-bodb_N88LOG"></info>*/

/*
	Created: 20201124@Hogan
	DB: DBN88LOG.bodb_N88LOG
	Task: Add column DefaultBaseCurrency to log [RedmineID: #145346]
*/

USE bodb_N88LOG
GO

UPDATE N88Log_Action WITH (ROWLOCK, UPDLOCK)
SET Items = REPLACE(Items,'</root>', '<row item="DefaultBaseCurrency" alias="bcc" /></root>')
WHERE SPName = 'N88_User_Update' OR SPName = 'N88_User_Insert'

GO