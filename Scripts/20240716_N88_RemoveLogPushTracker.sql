/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*
	Created: 20240716@Sally
	DB: DBN88-bodb_N88
	Task: Delete log Tracker
*/
USE bodb_N88
GO

DELETE t
FROM dbo.API_PushDataTracker T WITH (ROWLOCK,UPDLOCK)
WHERE PushTrackerId = 1180
