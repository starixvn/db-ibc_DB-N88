/*<info serverAlias="DBAFFN8G-Affiliate_N8G"></info>*/
/*
	Created: 20251126@Sally
	DB: DBAFFN8G-Affiliate_N8G
	Task: Pull member info for 12B V2  [RedmineId : #244736]

*/

USE Affiliate_N8G
GO

Update c set SValue = '2025-11-24 00:00:00'
FROM dbo.SystemSettings c with (NOLOCK)
where c.SName IN ('MemberInfoLastImportedTime','MemberInfoLastUpdatedTime')
