/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230407@Malcolm
	Task: Update setting - [Redmine: #183319]
	DB: DBN88/bodb_N88
*/

/*Run ON DB052, DB053*/

declare @scheduleid int 
select @scheduleid = ss.schedule_id
from msdb.dbo.sysjobs sj
	inner join msdb.dbo.sysjobschedules sjs ON sjs.job_id = sj.job_id
	INNER JOIN msdb.dbo.sysschedules ss ON ss.schedule_id = sjs.schedule_id
WHERE SJ.name = 'bodb_N88: Repull Missing Data' and ss.name = '30 minutes'

EXEC msdb.dbo.sp_update_schedule 
	@schedule_id = @scheduleid,
    @new_name = N'15 minutes',
    @freq_subday_interval=15
	
	
INSERT INTO API_TimeTracker (datasource, CalledTime, keyvalue)
VALUES ('PromotionTest', GETDATE(), '01/01/2010 2:00:00 PM')
,('PromotionSpecificTest', GETDATE(), '01/01/2010 2:00:00 PM')
,('RebateMLogTest', GETDATE(), '01/01/2010 10:00:00 AM')

