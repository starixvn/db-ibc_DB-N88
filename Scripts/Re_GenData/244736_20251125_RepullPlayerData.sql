/*<info serverAlias="DBAFFN88-Affiliate_N88"></info>*/
/*
	Created: 20251126@Sally
	DB: DBAFFN88-Affiliate_N88
	Task: Pull member info for 12B V2  [RedmineId : #244736]

*/

USE Affiliate_N88
GO

Update c set SValue = '2025-11-24 00:00:00'
FROM dbo.SystemSettings c with (NOLOCK)
where c.SName IN ('MemberInfoLastImportedTime','MemberInfoLastUpdatedTime')
