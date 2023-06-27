/*<info serverAlias="DBN88POL-N88_UserControl" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230620@Sally
	DB: DBN88-bodb_N88
	Task: 189299 - MPA - Report on top/bottom X player
	Step 3: 
		DROP Column DataRangeLimitation 
				
*/ 
USE N88_UserControl
GO

ALTER TABLE dbo.N88_Users
DROP COLUMN IF EXISTS DataRangeLimitation 
GO
;
