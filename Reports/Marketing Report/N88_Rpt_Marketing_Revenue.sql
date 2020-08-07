/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Revenue]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@ProductIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200713@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - AVG Revenue

	Revisions:
		- 20200713@Percy: Initialize SP [RedmineID: #137395]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @TotalUsers INT, @TotalPaidUsers INT

	BEGIN
		SELECT @FromDate = CONVERT(DATE, @FromDate), @ToDate = CONVERT(DATE, @ToDate)

		-- Data on GMT+0 --> convert timezone
		SELECT @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		SELECT @TotalUsers = COUNT(1), @TotalPaidUsers = COUNT(d.CustId)
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN dbo.DepositInfo d WITH (NOLOCK)
				ON		c.CustId = d.CustId
					AND c.SiteId = d.SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3
		WHERE c.IsTest = 0
			AND c.RegTime <= @ToDateTimeGMT

		CREATE TABLE #Products (ProductId INT)
		INSERT INTO #Products (ProductId)
		SELECT DISTINCT val FROM bodb02.dbo.f_StringSplit(@ProductIds, ',')

		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FromDate, @ToDate, @DisplayCurrency, '')

		SELECT
			p.ProductId
			,CASE WHEN @TotalUsers = 0 THEN 0 ELSE ISNULL(1.0 * Turnover / @TotalUsers, 0) END AS Turnover
			,CASE WHEN @TotalPaidUsers = 0 THEN 0 ELSE ISNULL(1.0 * Turnover / @TotalPaidUsers, 0) END AS PaidUser_Turnover
		FROM #Products p
			LEFT JOIN (
				SELECT ProductId, SUM(Turnover) AS Turnover
				FROM (
					SELECT r.CustId, r.GameType AS ProductId, SUM(Turnover * e.Rate) AS Turnover
					FROM dbo.N88_RptWinloss r WITH (NOLOCK)
						INNER JOIN #Exchange e ON r.WinlostDateGMT BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
					WHERE r.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
						AND r.WinlostDateGMT BETWEEN @FromDate AND @ToDate
						AND r.TimeZone = @TimeZone
						AND r.LicenseeId = @LicenseeId
						AND EXISTS (SELECT 1 FROM #Products p WHERE r.GameType = p.ProductId)
					GROUP BY r.CustId, r.GameType
				) t
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON t.CustId = c.CustId
				WHERE c.IsTest = 0
				GROUP BY ProductId
			) r ON p.ProductId = r.ProductId
		ORDER BY p.ProductId

		DROP TABLE #Exchange
		DROP TABLE #Products
	END
END
GO