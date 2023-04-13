/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230301@Malcolm
	Task: Update setting - [Redmine: #185510]
	DB: DBN88/bodb_N88
*/

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
VALUES ('WeeklyBonusInfo', GETDATE(), 0)

