/*<info serverAlias="DBAFFN88-Affiliate_N88,DBAFFN8B-Affiliate_N8B,DBAFFN8G-Affiliate_N8G"></info>*/
/*
	Created: 20201228@Percy
	DB:
		DBAFFN88-Affiliate_N88
		DBAFFN8B-Affiliate_N8B
		DBAFFN8G-Affiliate_N8G
	Task: MPA Report - Grant select permission to bodbLicenseeNet account

	use Affiliate_N88
	go
	use Affiliate_N8B
	go
	use Affiliate_N8G
	go
*/

create user [bodbLicenseeNet] for login [bodbLicenseeNet] with default_schema=[dbo]
go
grant select on dbo.MemberInfo to [bodbLicenseeNet] as [dbo]
go
grant select on dbo.AffInfo to [bodbLicenseeNet] as [dbo]
go