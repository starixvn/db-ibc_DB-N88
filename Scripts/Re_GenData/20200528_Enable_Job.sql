/*<info serverAlias="DBN88-msdb" isFunction="0" isNested=""></info>*/
/*	
	Created: 20200528@Sol
	Task: Enable job - [Redmine:#133254]
	DB: DBN88/msdb
*/

USE [msdb]

GO

EXEC msdb.dbo.sp_update_job @job_name = N'bodb_N88: Generate daily data for N88_RptWinloss', 
		@enabled = 1

GO