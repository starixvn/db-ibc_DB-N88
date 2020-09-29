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

	DECLARE @BonusUsers INT, @CompareBonusUsers INT

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
		SELECT @BonusUsers = COUNT(DISTINCT b.CustId)
		FROM dbo.BonusInfo b WITH (NOLOCK)
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
		WHERE b.WinlostDate BETWEEN @FDate AND @TDate
			AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND b.SiteId = @SiteId
			AND c.IsTest = 0

		SELECT @CompareBonusUsers = COUNT(DISTINCT b.CustId)
		FROM dbo.BonusInfo b WITH (NOLOCK)
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
		WHERE b.WinlostDate BETWEEN DATEADD(DAY, -1, @CompareFromDate) AND DATEADD(DAY, 1, @CompareToDate)
			AND b.CreateTime >= @CompareFromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
			AND b.SiteId = @SiteId
			AND c.IsTest = 0

		SELECT @BonusUsers AS BonusUsers, @CompareBonusUsers AS CompareBonusUsers

		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')

		-- Detail by Campaign
		SELECT b.BonusCode, COUNT(DISTINCT b.CustId) AS BonusUsers, SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmount
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN dbo.BonusInfo b WITH (NOLOCK) ON c.CustId = b.CustId
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
				AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
		WHERE b.WinlostDate BETWEEN @FDate AND @TDate
			AND b.SiteId = @SiteId
			AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.IsTest = 0
		GROUP BY b.BonusCode
		ORDER BY b.BonusCode

		-- Total
		SELECT COUNT(DISTINCT b.CustId) AS TotalBonusUsers, SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS TotalBonusAmount
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN dbo.BonusInfo b WITH (NOLOCK) ON c.CustId = b.CustId
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
				AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
		WHERE b.WinlostDate BETWEEN @FDate AND @TDate
			AND b.SiteId = @SiteId
			AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.IsTest = 0

		DROP TABLE #Exchange
	END
END
GO