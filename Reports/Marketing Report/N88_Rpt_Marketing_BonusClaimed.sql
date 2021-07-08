/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BonusClaimed]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20201029@Percy: Change Bonus User to Bonus Amount [RedmineID: #143879]
		- 20210113@Percy: Add Rebate & Cashback [RedmineID: #148616]
		- 20210401@Percy: [RedmineID: #150876]
			1. Add Bonus Name column
			2. Breakdown by original currency
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	CREATE TABLE #BonusInfo (BonusCode VARCHAR(50), Currency INT, BonusClaimeds INT, BonusAmount MONEY, BasedBonusAmount MONEY, IsCompared BIT)
	CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
				,@CompareFromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
				,@CompareToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))

		-- Get data
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
			
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

			INSERT INTO #BonusInfo (BonusCode, Currency, BonusClaimeds, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT b.BonusCode, b.CurrencyId, SUM(BonusClaimeds) AS BonusClaimeds, SUM(b.BonusAmount) AS BonusAmount, SUM(b.BonusAmount * e.Rate) AS BasedBonusAmount, 0 AS IsCompared
			FROM (
				SELECT b.BonusCode, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) AS ExchangeDate, COUNT(1) AS BonusClaimeds, 
					SUM(b.BonusAmount / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmount
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY b.BonusCode, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.BonusCode, b.CurrencyId

			INSERT INTO #BonusInfo (BonusCode, Currency, BonusClaimeds, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT r.BonusCode, r.CurrencyId, SUM(BonusClaimeds) AS BonusClaimeds, SUM(r.BonusAmount) AS BonusAmount, SUM(r.BonusAmount * e.Rate) AS BasedBonusAmount, 0 AS IsCompared
			FROM (
				SELECT r.BonusCode, r.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) AS ExchangeDate, COUNT(1) AS BonusClaimeds, 
				SUM(r.RedeemAmount / CASE WHEN r.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.RebateMLog r WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
				WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND r.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY r.BonusCode, r.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime))
			) r
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId AND r.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY r.BonusCode, r.CurrencyId
		END

		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
			
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

			INSERT INTO #BonusInfo (BonusCode, Currency, BonusClaimeds, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT b.BonusCode, b.CurrencyId, SUM(BonusClaimeds) AS BonusClaimeds, SUM(b.BonusAmount) AS BonusAmount, SUM(b.BonusAmount * e.Rate) AS BasedBonusAmount, 1 AS IsCompared
			FROM (
				SELECT b.BonusCode, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) AS ExchangeDate, COUNT(1) AS BonusClaimeds, 
				SUM(b.BonusAmount  / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @CompareFromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY b.BonusCode, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.BonusCode, b.CurrencyId

			INSERT INTO #BonusInfo (BonusCode, Currency, BonusClaimeds, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT r.BonusCode, r.CurrencyId, SUM(BonusClaimeds) AS BonusClaimeds, SUM(r.BonusAmount) AS BonusAmount, SUM(r.BonusAmount * e.Rate) AS BasedBonusAmount, 1 AS IsCompared
			FROM (
				SELECT r.BonusCode, r.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) AS ExchangeDate, COUNT(1) AS BonusClaimeds, 
				SUM(r.RedeemAmount  / CASE WHEN r.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.RebateMLog r WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
				WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND r.CreateTime >= @CompareFromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND r.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY r.BonusCode, r.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime))
			) r
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId AND r.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY r.BonusCode, r.CurrencyId
		END

		-- Summary by Currency
		SELECT Currency
			,SUM(CASE WHEN IsCompared = 0 THEN BonusAmount ELSE 0 END)		AS BonusAmountClaimeds
			,SUM(CASE WHEN IsCompared = 0 THEN BasedBonusAmount ELSE 0 END) AS BasedBonusAmountClaimeds
			,SUM(CASE WHEN IsCompared = 1 THEN BonusAmount ELSE 0 END)		AS CompareBonusAmountClaimeds
			,SUM(CASE WHEN IsCompared = 1 THEN BasedBonusAmount ELSE 0 END) AS CompareBasedBonusAmountClaimeds
		FROM #BonusInfo
		GROUP BY Currency

		-- Detail by Bonus Code, Currency
		SELECT b.BonusCode, b.Currency, p.Description AS BonusName, b.BonusClaimeds, b.BonusAmount, b.BasedBonusAmount
		FROM #BonusInfo b
			LEFT JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode
		WHERE b.IsCompared = 0
		ORDER BY CASE WHEN b.BonusCode IS NULL THEN 1 ELSE 0 END, b.BonusCode

		DROP TABLE #BonusInfo
		DROP TABLE #Exchange
	END
END
GO