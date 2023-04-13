/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230407@Malcolm
	Task: Update setting - [Redmine: #183319]
	DB: DBN88/bodb_N88
*/

/*Run ON DB052, DB053*/

DELETE API_TimeTracker WHERE dataSource = 'CustVerificationReward'

INSERT INTO API_TimeTracker (DataSource , calledTime, KeyValue)
VALUES ('CustVerificationReward', GETDATE(), '2021-12-01 03:57:02')
