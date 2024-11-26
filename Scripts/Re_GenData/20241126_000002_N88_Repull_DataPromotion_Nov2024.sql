/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20241126@Sally
	Task: Repull data Prommotion from Nov
	DB: DBN88/bodb_N88
	- Repull data B2C Prommotion
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO
DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.DataSource  IN ('Promotion')
	AND att.CalledTime >='2024-11-25'

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-11-25' AS CalledTime, t.KeyValue
FROM(
	SELECT 'Promotion' as DataSource, '11/01/2024 00:00:00 AM' as KeyValue
)t
GO

