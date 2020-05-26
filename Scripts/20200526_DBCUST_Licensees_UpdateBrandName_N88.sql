/*<info serverAlias="DBCUST-bodb_Licensee"></info>*/
/*
	Created: 2020526@Percy
	DB: DBCUST-bodb_Licensee
	Task: Update BrandName of N88 licensee [RedmineID: #134780]
*/

USE bodb_Licensee
GO

UPDATE dbo.Licensees WITH (ROWLOCK)
SET BrandName = 'Nova88'
WHERE LicenseeName = 'N88'