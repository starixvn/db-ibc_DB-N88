/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BonusClaimed]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @BonusAmountClaimeds MONEY, @CompareBonusAmountClaimeds MONEY
	CREATE TABLE #BonusInfo (BonusCode VARCHAR(50), BonusClaimeds INT, BonusAmount MONEY)
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
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')

			INSERT INTO #BonusInfo (BonusCode, BonusClaimeds, BonusAmount)
			SELECT b.BonusCode, COUNT(DISTINCT b.CustId) AS BonusClaimeds, SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmount
			FROM (
				SELECT b.BonusCode, b.CustId, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(b.BonusAmount) AS BonusAmount
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
				GROUP BY b.BonusCode, b.CustId, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.BonusCode

			SELECT @BonusAmountClaimeds = SUM(BonusAmount) FROM #BonusInfo
		END

		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
			
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')

			SELECT @CompareBonusAmountClaimeds = SUM(BonusAmount)
			FROM (
				SELECT b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(b.BonusAmount) AS BonusAmount
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @CompareFromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
				GROUP BY b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		END

		SELECT @BonusAmountClaimeds AS BonusAmountClaimeds, @CompareBonusAmountClaimeds AS CompareBonusAmountClaimeds

		SELECT BonusCode, BonusClaimeds, BonusAmount
		FROM #BonusInfo
		ORDER BY BonusCode

		DROP TABLE #Exchange
		DROP TABLE #BonusInfo
	END
END
GO