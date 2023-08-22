/*<info serverAlias="DBN88POL-N88_UserControl" ></info>*/
/*
	Created: 20230821@Sally
	DB: DBN88POL-N88_UserControl
	Task: 192437- MPA - Remove column DataRangeLimitation
	Step 2: 
		Rename Column DataRangeLimitation
				
*/ 
USE N88_UserControl
GO
 
ALTER TABLE dbo.N88_Users
DROP COLUMN IF EXISTS DataRangeLimitation_Drop
