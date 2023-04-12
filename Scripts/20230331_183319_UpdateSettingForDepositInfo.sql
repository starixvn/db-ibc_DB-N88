/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230331@Malcolm
	Task: Update setting - [Redmine: #183319]
	DB: DBN88/bodb_N88
*/

/*Run On DB052 and DB053*/
DELETE API_TimeTracker WITH(ROWLOCK, UPDLOCK) 
WHERE DataSource = 'DepositInfo'

INSERT INTO API_TimeTracker (DataSource, CalledTime, KeyValue)
VALUES ('DepositInfo', GETDATE(), '{"Id":4650005,"UpdateTime":"2023-03-01 00:00:01"}')
