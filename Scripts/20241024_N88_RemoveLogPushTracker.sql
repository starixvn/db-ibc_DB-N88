/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20241024@Sally
	DB: DBN88-bodb_N88
	Task: Delete log Tracker
*/
USE bodb_N88
GO

DELETE t
FROM dbo.API_PushDataTracker t WITH (ROWLOCK,UPDLOCK)
WHERE PushTrackerId = 1264
AND StatusId = 2