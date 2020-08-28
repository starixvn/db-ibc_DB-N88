/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE N88_SelCurrency
(
	@LicenseeID INT
)
AS
/*
	Created: 20200519@Sol
	Task : N88 - Get list currency
	DB: DBN88-bodb_N88
	
	Revisions:
		- 20200519@Sol: Get list currency [Redmine:#133254]
		- 20200720@Sol: support CNY cur by hardcode (will update after get fixed from TW) [Redmine:#137064]
	
*/
BEGIN
	
	SET NOCOUNT ON;

	SELECT ex.exchangeid AS Currency, 
		CASE ex.exchangeid
			WHEN 20 THEN 'UUS'
			WHEN 51 THEN 'INH'
			WHEN 70 THEN 'MKK'
			WHEN 75 THEN 'PTU'
			WHEN 76 THEN 'PS'
			WHEN 77 THEN 'PTH'
			ELSE ex.Code
		END AS CurrencyName
	FROM dbo.ServerInfo AS ser WITH(NOLOCK)
		CROSS APPLY bodb02.dbo.strsplit(SUBSTRING(ser.CurrencyList, 2, LEN(ser.CurrencyList)-2)  + CASE WHEN ser.LicenseeName = 'N88' THEN ',13' ELSE '' END,',') AS curr
		INNER JOIN bodb02.dbo.Exchange AS ex WITH (NOLOCK) 
			ON CAST(curr.val AS INT) = ex.exchangeid
		INNER JOIN bodb_licensee.dbo.Licensees l WITH(NOLOCK) 
			ON l.LicenseeName = ser.LicenseeName
	WHERE l.LicenseeID = @LicenseeID
	ORDER BY
		CASE ex.exchangeid
			WHEN 20 THEN 'UUS'
			WHEN 51 THEN 'INH'
			WHEN 70 THEN 'MKK'
			WHEN 75 THEN 'PTU'
			WHEN 76 THEN 'PS'
			WHEN 77 THEN 'PTH'
			ELSE ex.Code
		END

END

GO