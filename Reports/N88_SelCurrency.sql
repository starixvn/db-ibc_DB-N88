/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE N88_SelCurrency
AS
/*
	Created: 20200519@Sol
	Task : N88 - Get list currency
	DB: DBEXT-bodb02
	
	Revisions:
		- 20200519@Sol: Get list currency [Redmine:#133254]
	
*/
BEGIN
	
	SET NOCOUNT ON;

	SELECT DISTINCT tpc.CurrencyId, CASE WHEN tpc.CurrencyId = 20 THEN 'UUS' ELSE ex.Code END AS CurrencyCode
	FROM bodb_3rdProduct.dbo.TpCurrency tpc WITH(NOLOCK)
		LEFT JOIN Exchange ex WITH(NOLOCK)
			ON ex.exchangeid = tpc.CurrencyId

END

GO