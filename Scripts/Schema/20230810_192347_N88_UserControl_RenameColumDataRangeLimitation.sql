/*<info serverAlias="DBN88POL-N88_UserControl" ></info>*/
/*
	Created: 20230810@Sally
	DB: DBN88POL-N88_UserControl
	Task: 192437- MPA - Remove column DataRangeLimitation
	Step 1: 
		Rename Column DataRangeLimitation before remove it 
				
*/ 
USE N88_UserControl
GO
EXEC SP_RENAME 'N88_Users.DataRangeLimitation', 'DataRangeLimitation_Drop', 'COLUMN'  

GO
;
