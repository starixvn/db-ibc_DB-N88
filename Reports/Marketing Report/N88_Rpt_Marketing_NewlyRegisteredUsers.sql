/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_NewlyRegisteredUsers]
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
	Task: MPA - Marketing Report - Newly Registered Users

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #137395]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @NewlyRegisterUsers INT, @CompareNewlyRegisterUsers INT

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
		SELECT @NewlyRegisterUsers = COUNT(1)
		FROM dbo.Customer WITH (NOLOCK)
		WHERE RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND SiteId = @SiteId
			AND IsTest = 0

		SELECT @CompareNewlyRegisterUsers = COUNT(1)
		FROM dbo.Customer WITH (NOLOCK)
		WHERE RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
			AND SiteId = @SiteId
			AND IsTest = 0

		SELECT @NewlyRegisterUsers AS NewlyRegisterUsers
				,@CompareNewlyRegisterUsers AS CompareNewlyRegisterUsers

		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')

		-- Detail by Campaign
		SELECT b.BonusCode, COUNT(1) AS NewlyRegisterUsers, COUNT(d.CustId) AS Deposit, SUM(ISNULL(d.Amount, 0)) AS FirstDepositAmount
		FROM dbo.Customer c WITH (NOLOCK)
			OUTER APPLY
			(
				SELECT b.CustId, b.BonusCode
				FROM dbo.BonusInfo b WITH (NOLOCK)
				WHERE c.CustId = b.CustId
					AND b.WinlostDate BETWEEN @FDate AND @TDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			) b
			OUTER APPLY
			(
				SELECT d.CustId, d.Amount * e.Rate AS Amount
				FROM dbo.DepositInfo d WITH (NOLOCK)
					INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
						AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
				WHERE c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
					AND d.WinlostDate BETWEEN @FDate AND @TDate
					AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			) d
		WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.SiteId = @SiteId
			AND c.IsTest = 0
		GROUP BY b.BonusCode

		-- Detail by Signup URL
		DECLARE @DefaultSignupUrl VARCHAR(200)
		SELECT  @DefaultSignupUrl = CASE @SiteId
										WHEN 3 THEN 'www.bwing.com'
										END

		SELECT CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END AS SignupUrl
			,COUNT(1) AS NewlyRegisterUsers, COUNT(d.CustId) AS Deposit, SUM(ISNULL(d.Amount, 0)) AS FirstDepositAmount
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
			OUTER APPLY
			(
				SELECT d.CustId, d.Amount * e.Rate AS Amount
				FROM dbo.DepositInfo d WITH (NOLOCK)
					INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
						AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
				WHERE c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
					AND d.WinlostDate BETWEEN @FDate AND @TDate
					AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			) d
		WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.SiteId = @SiteId
			AND c.IsTest = 0
		GROUP BY CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END

		DROP TABLE #Exchange
	END
END
GO