/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20250530@Kelvin
	Task:  - [Redmine: #183319]
	DB: DBN88/bodb_N88
*/

/*Run ON DB052, DB053*/

USE bodb_N88
GO

DROP TABLE IF EXISTS [dbo].[TpBetRecord_Old]
GO
DROP TABLE IF EXISTS [dbo].[TpBetRecordTest]
GO
DROP TABLE IF EXISTS [dbo].[API_QueueTest]
GO
DROP TABLE IF EXISTS [dbo].[DepositInfoTest]