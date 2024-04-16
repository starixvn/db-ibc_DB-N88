/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240416@Sally
	Task: Repull data CustRegInfo from 19.03.2024
	DB: DBN88/bodb_N88
	- Repull CustRegInfo data B2C from 19 Mar 2024
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO

DELETE att
FROM dbo.API_TimeTracker att WITH (ROWLOCK, UPDLOCK)
WHERE att.CalledTime >='2024-04-14'
AND att.DataSource = 'CustRegInfo'

INSERT INTO dbo.API_TimeTracker (DataSource, CalledTime, KeyValue)
SELECT 'CustRegInfo' AS DataSource, '2024-04-15' AS CalledTime, '3/19/2024 8:00:00'  AS KeyValue
GO
