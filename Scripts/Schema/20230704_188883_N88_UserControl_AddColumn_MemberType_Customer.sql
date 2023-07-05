/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230704@Sally
	DB: DBN88-bodb_N88
	Task: 188883 - MPA - Exclude data of Live Streamer
	Step 1:
		Add column MemberType Table Customer
*/
USE bodb_N88
GO

ALTER TABLE dbo.Customer
ADD MemberType INT NOT NULL 
CONSTRAINT  DF_Customer_MemberType DEFAULT (1)
GO