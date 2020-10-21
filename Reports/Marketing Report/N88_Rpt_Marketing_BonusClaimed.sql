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

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	DECLARE @BonusClaimeds INT, @CompareBonusClaimeds INT

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

		-- Total
		SELECT @BonusClaimeds = COUNT(1)
		FROM (
			SELECT b.CustId, b.BonusCode
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			WHERE b.WinlostDate BETWEEN @FDate AND @TDate
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND c.IsTest = 0
			GROUP BY b.CustId, b.BonusCode
		) b

		SELECT @CompareBonusClaimeds = COUNT(1)
		FROM (
			SELECT b.CustId, b.BonusCode
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			WHERE b.WinlostDate BETWEEN DATEADD(DAY, -1, @CompareFromDate) AND DATEADD(DAY, 1, @CompareToDate)
				AND b.CreateTime >= @CompareFromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND c.IsTest = 0
			GROUP BY b.CustId, b.BonusCode
		) b

		SELECT @BonusClaimeds AS BonusClaimeds, @CompareBonusClaimeds AS CompareBonusClaimeds

		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')

		-- Detail by Campaign
		CREATE TABLE #BonusInfo (CustId INT, CurrencyId INT, WinlostDate DATE, BonusCode VARCHAR(50), Amount MONEY)
		INSERT INTO #BonusInfo (CustId, CurrencyId, WinlostDate, BonusCode, Amount)
		SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), BonusCode, SUM(BonusAmount)
		FROM dbo.BonusInfo WITH (NOLOCK)
		WHERE WinlostDate BETWEEN @FDate AND @TDate
			AND SiteId = @SiteId
			AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
		GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), BonusCode

		SELECT b.BonusCode, COUNT(DISTINCT b.CustId) AS BonusClaimeds, SUM(b.Amount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmount
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN #BonusInfo b ON c.CustId = b.CustId
			INNER JOIN #Exchange e ON b.WinlostDate BETWEEN e.FromDate AND e.ToDate AND b.CurrencyId = e.ExchangeId
		WHERE c.IsTest = 0
		GROUP BY b.BonusCode
		ORDER BY b.BonusCode

		DROP TABLE #Exchange
		DROP TABLE #BonusInfo
	END
END
GO