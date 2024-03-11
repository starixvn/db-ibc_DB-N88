/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240311@Sally
	Task: Repull data from 03.03.2024
	DB: DBN88/bodb_N88
	- Delete Push Data Tracker fail
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO

DELETE r
FROM dbo.API_PushDataTracker r WITH (ROWLOCK, UPDLOCK)
WHERE PushTrackerId = 690

