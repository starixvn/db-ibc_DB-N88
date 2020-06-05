/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20200511@Sol
	Task: drop unused column IsTest in N88_Rptwinloss table - [Redmine:#135372]
	DB: DBN88/bodb_N88
*/

USE bodb_N88;

GO 

ALTER TABLE N88_RptWinloss DROP COLUMN IsTest

GO