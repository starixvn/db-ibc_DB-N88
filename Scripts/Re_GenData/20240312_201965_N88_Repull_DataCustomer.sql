/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240312@Sally
	Task: Repull data Customer
	DB: DBN88/bodb_N88
	- Repull data B2C
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO

DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.CalledTime >='2024-03-09 00:00:00'
AND att.DataSource IN ('Customer' )

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT t.DataSource, '2024-03-10' AS CalledTime, t.KeyValue
FROM (
	SELECT 'Customer' as DataSource, '3/3/2024 3:13:47' as KeyValue
)t
GO