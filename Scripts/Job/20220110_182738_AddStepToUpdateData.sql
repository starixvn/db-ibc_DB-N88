/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20220110@Malcolm
	DB: DBN88-bodb_N88
	Task: Create job to update TpsystemUsername [RedmineId : 182738]

*/
USE msdb
GO
EXEC sp_add_jobstep
	@cmdexec_success_code=0, 
	@on_success_action=1, 
	@on_success_step_id=0, 
	@on_fail_action=2,
	@on_fail_step_id=0, 
	@retry_attempts=0, 
	@retry_interval=0, 
    @job_name = N'bodb_N88: Generate daily data',
    @step_name = N'Update TpSystemUsername in Customer table',
    @subsystem = N'TSQL',
    @command = N'EXEC dbo.Task_Customer_Upd',
	@database_name=N'bodb_N88', 
    @flags=0
GO


EXEC dbo.sp_update_jobstep  
    @job_name = N'bodb_N88: Generate daily data',  
    @step_id = 2,  
	@on_success_action = 3,
    @on_success_step_id = 0 ;  
GO  

EXEC dbo.sp_update_jobstep  
    @job_name = N'bodb_N88: Generate daily data',  
    @step_id = 1,  
	@on_fail_action = 2;
GO  


