/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_SelLicenseeInfo]
	@LicenseeId	INT
AS

/*
	Created: 20200314@Kos
	Task: Get licensee info
	DB: DBLIC.bodb_Licensee
	Original: Lrf_LicenseeSel

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		l.LicenseeID,
		l.LicenseeName,
		l.IsAllowedMemberComm,
		ISNULL(lc.EnableBA, 0) AS EnableBA
	FROM
		dbo.Licensees AS l WITH (NOLOCK)
		LEFT JOIN LicenseeBAConfig AS lc WITH (NOLOCK) ON lc.LicenseeID = l.LicenseeID
	WHERE l.LicenseeID = @LicenseeId
END
GO
