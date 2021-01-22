/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Deposit]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20201215@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Deposit

	Revisions:
		- 20201215@Percy: Initialize SP [RedmineID: #146760]
		- 20201229@Sol: change text from "Credit Site" to "Bong88/Viva88" - [RedmineID: #147542]
		- 20210113@Percy: Add 'APP' signup url [RedmineID: #148616]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @DepositAmount MONEY, @CompareDepositAmount MONEY

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

		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
		
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')

			SELECT @CompareDepositAmount = SUM(d.Amount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			FROM dbo.DepositInfo d WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND d.CreateTime >= @CompareFromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				AND d.SiteId = @SiteId
				AND d.Status = 3
				AND c.IsTest = 0
		END
		
		-- Get data
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
		
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')

			SELECT @DepositAmount = SUM(d.Amount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			FROM dbo.DepositInfo d WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND d.SiteId = @SiteId
				AND d.Status = 3
				AND c.IsTest = 0
		END

		-- Detail by Signup URL
		DECLARE @CreditAgentName VARCHAR(30) = '', @MainUrl VARCHAR(200), @DefaultUrl VARCHAR(200), @APPSignupUrl VARCHAR(200)
		DECLARE @MainUrls TABLE (Url VARCHAR(200))
		CREATE TABLE #Affiliate (CustId INT, AffId INT)
		
		IF @SiteId = 1
		BEGIN
			SELECT @MainUrl = 'Nova88.net', @APPSignupUrl = 'app.nova88.net'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.nova88.com'), ('www.nova88.net'), ('m.nova88.net')
			
			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N88.dbo.MemberInfo WITH (NOLOCK)
			WHERE RegisteredDate <= DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01', @MainUrl = 'Goal123.com', @APPSignupUrl = 'app.goal123.com'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.goal123.com'), ('m.goal123.com')
			
			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N8G.dbo.MemberInfo WITH (NOLOCK)
			WHERE RegisteredDate <= DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01', @MainUrl = 'Bwing.com', @APPSignupUrl = 'app.bwing.com', @DefaultUrl = 'www.bwing.com'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.bwing.com'), ('m.bwing.com')
			
			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N8B.dbo.MemberInfo WITH (NOLOCK)
			WHERE RegisteredDate <= DATEADD(DAY, 1, @ToDate)
		END

		CREATE TABLE #DepositInfo (CustId INT, DepositAmount MONEY, FirstDepositAmount MONEY)

		;WITH CTE_DepositInfo AS (
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(Amount) AS DepositAmount
				,SUM(CASE WHEN FirstDeposit = 1 THEN Amount ELSE 0 END) AS FirstDepositAmount
			FROM dbo.DepositInfo WITH (NOLOCK)
			WHERE CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND Status = 3
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		)
		INSERT INTO #DepositInfo (CustId, DepositAmount, FirstDepositAmount)
		SELECT CustId
			,SUM(DepositAmount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			,SUM(FirstDepositAmount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
		FROM CTE_DepositInfo d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY CustId

		SELECT @DepositAmount AS DepositAmount, @CompareDepositAmount AS CompareDepositAmount

		SELECT
			CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN @MainUrl
				WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
				WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
				ELSE 'None' END AS SignUpSource
			,CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN @DefaultUrl
				WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
				ELSE cg.SignupUrl END AS SignupUrl
			,SUM(d.FirstDepositAmount) AS FirstDepositAmount
			,SUM(d.DepositAmount) AS DepositAmount
		FROM #DepositInfo d
			INNER JOIN dbo.Customer c with (nolock) on d.CustId = c.CustId
			INNER JOIN dbo.Customer ag with (nolock) on c.AgentId = ag.CustId
			LEFT JOIN dbo.CustRegInfo cg with (nolock) on c.CustId = cg.CustId
			LEFT JOIN #Affiliate a ON d.CustId = a.CustId
			LEFT JOIN @MainUrls mu ON cg.SignupUrl = mu.Url
		WHERE c.SiteId = @SiteId AND c.IsTest = 0
		GROUP BY
			CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN @MainUrl
				WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
				WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
				ELSE 'None' END
			,CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN @DefaultUrl
				WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
				ELSE cg.SignupUrl END

		DROP TABLE #Affiliate
		DROP TABLE #DepositInfo
		DROP TABLE #Exchange
	END
END
GO