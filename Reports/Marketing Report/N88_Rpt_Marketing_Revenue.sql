/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Revenue]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@ProductIds		VARCHAR(MAX)
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200713@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - AVG Revenue

	Revisions:
		- 20200713@Percy: Initialize SP [RedmineID: #137395]
		- 20200818@Percy: Support special date range [RedmineID: #137395]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230705@Sally: Exclude data of Live Streamer [RedmineId: #189299]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME, @TpCurrencyIds VARCHAR(MAX)
	DECLARE @TotalUsers INT, @TotalPaidUsers INT
	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	BEGIN
		SELECT @TpCurrencyIds = 
		(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(tp.TpExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = t.value
		)

		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		SELECT @TotalUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.IsTest = 0
			AND c.SiteId = @SiteId
			AND c.MemberType <> 3 -- Exclude Live Streamer
			AND c.RegTime <= DATEADD(DAY, 1, @ToDateTimeGMT)
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT @TotalPaidUsers = COUNT(d.CustId)
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN dbo.DepositInfo d WITH (NOLOCK)
				ON		c.CustId = d.CustId
					AND c.SiteId = d.SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3
		WHERE c.IsTest = 0
			AND c.SiteId = @SiteId
			AND c.MemberType <> 3 -- Exclude Live Streamer
			AND d.WinlostDate <= DATEADD(DAY, 1, @ToDate)
			AND d.CreateTime <= DATEADD(DAY, 1, @ToDateTimeGMT)
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		CREATE TABLE #Products (ProductId INT)
		INSERT INTO #Products (ProductId)
		SELECT DISTINCT val FROM bodb02.dbo.f_StringSplit(@ProductIds, ',')

		CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT)
		INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), Rate 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		;WITH rs AS
		(
			SELECT r.CustId, r.GameType AS ProductId, Turnover , r.Currency,
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
			WHERE 
				r.SettledTime >= @FromDateTimeGMT AND r.SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND r.SiteId = @SiteId
				AND EXISTS (SELECT 1 FROM #Products p WHERE r.GameType = p.ProductId)
		)
		SELECT
			p.ProductId
			,CASE WHEN @TotalUsers = 0 THEN 0 ELSE ISNULL(1.0 * Turnover / @TotalUsers, 0) END AS Turnover
			,CASE WHEN @TotalPaidUsers = 0 THEN 0 ELSE ISNULL(1.0 * Turnover / @TotalPaidUsers, 0) END AS PaidUser_Turnover
		FROM #Products p
			LEFT JOIN (
				SELECT ProductId, SUM(Turnover) AS Turnover
				FROM (
					SELECT r.CustId, r.ProductId, SUM(Turnover * e.Rate) AS Turnover
					FROM rs AS r
						INNER JOIN #TpExchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.TpExchangeId
					GROUP BY r.CustId, r.ProductId
				) t
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON t.CustId = c.CustId
				WHERE c.IsTest = 0
					AND c.MemberType <> 3 -- Exclude Live Streamer
				GROUP BY ProductId
			) r ON p.ProductId = r.ProductId
		ORDER BY p.ProductId

		DROP TABLE #TpExchange
		DROP TABLE #Products
	END
END
GO