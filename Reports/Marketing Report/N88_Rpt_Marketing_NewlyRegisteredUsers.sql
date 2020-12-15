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
		- 20201215@Percy: View detail Signup URL by Credit Site [RedmineID: #146760]
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
		DECLARE @CreditAgentName VARCHAR(30) = '', @MainUrl VARCHAR(200), @DefaultUrl VARCHAR(200)
		DECLARE @MainUrls TABLE (Url VARCHAR(200))
		CREATE TABLE #Affiliate (CustId INT, AffId INT)
		
		IF @SiteId = 1
		BEGIN
			SELECT @MainUrl = 'Nova88.net'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.nova88.com'), ('www.nova88.net'), ('m.nova88.net')
			
			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N88.dbo.MemberInfo WITH (NOLOCK)
			WHERE RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01', @MainUrl = 'Goal123.com'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.goal123.com'), ('m.goal123.com')
			
			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N8G.dbo.MemberInfo WITH (NOLOCK)
			WHERE RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01', @MainUrl = 'Bwing.com', @DefaultUrl = 'www.bwing.com'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.bwing.com'), ('m.bwing.com')
			
			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N8B.dbo.MemberInfo WITH (NOLOCK)
			WHERE RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END

		SELECT
			CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Credit Site'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN @MainUrl
				WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
				ELSE 'None' END AS SignUpSource
			,CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Credit Site'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN @DefaultUrl
				ELSE cg.SignupUrl END AS SignupUrl
			,COUNT(1) AS NewlyRegisterUsers, COUNT(d.CustId) AS Deposit, SUM(ISNULL(d.Amount, 0)) AS FirstDepositAmount
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
			LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
			LEFT JOIN #Affiliate a ON c.CustId = a.CustId
			LEFT JOIN @MainUrls mu ON cg.SignupUrl = mu.Url
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
		GROUP BY
			CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Credit Site'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN @MainUrl
				WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
				ELSE 'None' END
			,CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName = @CreditAgentName THEN 'Credit Site'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN @DefaultUrl
				ELSE cg.SignupUrl END

		DROP TABLE #Affiliate
		DROP TABLE #Exchange
	END
END
GO