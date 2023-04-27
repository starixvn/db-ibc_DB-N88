/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230407@Malcolm
	Task: Update setting - [Redmine: #183319]
	DB: DBN88/bodb_N88
*/

/*Run ON DB052, DB053*/


UPDATE API_QueueTest
SET IsFinished =0, LogDesc = null, FinishedTime = NULL

