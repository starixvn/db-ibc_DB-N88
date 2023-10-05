/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20231003@Sally
	DB: DBN88-bodb_N88
	Task: MPA - Fix inconsistent data in the table CustBonusRollover & CustClosingBalance - [Redmine: #194596]
		- Step 1: Cut off data before fixing inconsistent data
*/
USE bodb_N88
GO
INSERT INTO dbo.SystemSettings (SName, SValue)
VALUES ('CustClosingBalance_CutOffDate', '2023-10-04'),
		('CustBonusRollover_CutOffDate', '2023-10-04')

;
SELECT *
FROM dbo.SystemSettings WITH (NOLOCK)
WHERE SName IN ('CustClosingBalance_CutOffDate','CustBonusRollover_CutOffDate')
