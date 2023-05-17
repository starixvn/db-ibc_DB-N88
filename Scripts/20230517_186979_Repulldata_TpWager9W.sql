/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230517@Sally
	Task: Update setting - [Redmine: #186979]
	DB: DBN88/bodb_N88
*/

/*Run ON DB052, DB053*/

DELETE API_TimeTracker WHERE dataSource = 'TpWager9W'

INSERT INTO API_TimeTracker (DataSource , calledTime, KeyValue)
VALUES ('TpWager9W', GETDATE(), '2020-12-01 00:00:00')