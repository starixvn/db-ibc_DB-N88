/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230424@Malcolm
	Task: Update setting - [Redmine: #186979]
	DB: DBN88/bodb_N88
*/

/*RUN on DB052*/

USE [bodb_N88]
GO

TRUNCATE TABLE API_QueueTest
GO
--Disable job
EXEC msdb.dbo.sp_update_job  
    @job_name = N'bodb_N88: API_QueueTest Process',  
    @enabled = 0 ;  
GO  

