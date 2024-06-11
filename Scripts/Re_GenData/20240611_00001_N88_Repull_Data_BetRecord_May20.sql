/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240611@Sally
	Task: Repull data Ticket from 20.05.2024
	DB: DBN88/bodb_N88
	- Repull data B2C BetRecord
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO
DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.DataSource  IN ('TpBetRecord','TpReport9W','TpWager9W')
	AND att.CalledTime >='2024-06-10'

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-06-10' AS CalledTime, t.KeyValue
FROM(
	SELECT 'TpBetRecord' as DataSource, '2024-05-20 00:00:00' as KeyValue UNION ALL
	SELECT 'TpReport9W' as DataSource, '2024-05-20 00:00:00' as KeyValue UNION ALL
	SELECT 'TpWager9W' as DataSource, '2024-05-20 00:00:00' as KeyValue 
)t
GO

