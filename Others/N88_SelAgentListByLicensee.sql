/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_SelAgentListByLicensee]
	@LicenseeId	INT
AS

/*
	Created: 20200314@Kos
	Task: Get agent list by licensee
	DB: DBLIC.bodb_Licensee
	Original: Lrf_SelCurrencyByLicenseeUser

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		DISTINCT lc.Currency,
		CASE lc.currency
			WHEN 20 THEN 'UUS'
			WHEN 51 THEN 'INH'
			WHEN 70 THEN 'MKK'
			WHEN 75 THEN 'PTU'
			WHEN 76 THEN 'PS'
			WHEN 77 THEN 'PTH'
			ELSE e.Code
		END AS CurrencyName,
		CAST(1 AS BIT) AS IsActive,
		lc.CustID AS AgentId
	FROM dbo.LicenseeCust AS lc WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON lc.currency = e.exchangeid
	WHERE lc.LicenseeID = @LicenseeID
	ORDER BY
		CASE lc.currency
			WHEN 20 THEN 'UUS'
			WHEN 51 THEN 'INH'
			WHEN 70 THEN 'MKK'
			WHEN 75 THEN 'PTU'
			WHEN 76 THEN 'PS'
			WHEN 77 THEN 'PTH'
			ELSE e.Code
		END
END

GO
