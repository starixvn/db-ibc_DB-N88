
/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20230209@Malcolm
	DB: DBN88-bodb_N88
	Task: Repull data [RedmineID: #244736]
*/
USE [bodb_N88]
GO
/*Run ON DB052, DB053*/
DELETE API_TimeTracker WITH(ROWLOCK)
WHERE DataSource IN ('Customer'
	,'Promotion'
	,'PromotionSpecific'
	,'RebateMLog'
	,'TpBetRecord')

INSERT INTO API_TimeTracker (DataSource , calledTime, KeyValue)
VALUES ('CustVerificationReward', '2025-11-25', '2025-11-24T00:00:00.000')
,('Customer', '2025-11-25', '2025-11-24T00:00:00.000')
,('Promotion', '2025-11-25', '2025-11-24T00:00:00.000')
,('PromotionSpecific', '2025-11-25', '2025-11-24T00:00:00.000')
,('RebateMLog', '2025-11-25', '2025-11-24T00:00:00.000')
,('TpBetRecord', '2025-11-25', '2025-11-24T00:00:00.000')

