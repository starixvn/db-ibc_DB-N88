/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BonusClaimed_Detail]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@SortbyId			TINYINT = 1
	,@IsSortAsc			BIT = 1
	,@PageIndex			INT = 1
	,@PageSize			INT = 50
	,@NRows				INT = 0 OUTPUT
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info - View detail

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20201215@Percy: Fix sort on Deposit & Withdrawal Amount [RedmineID: #146760]
		- 20210113@Percy: Add Rebate & Cashback [RedmineID: #148616]
		- 20210401@Percy: [RedmineID: #150876]
			1. Add Currency, Signup Url, Bonus Name columns
			2. Breakdown by original currency
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]

	Param's Explanation:
		@SortbyId:
			. 1 = Campaign
			. 2 = Username
			. 3 = Currency
			. 4 = Registered Date
			. 5 = Signup URL
			. 6 = Aff Code
			. 7 = Total Deposit Amount
			. 8 = Total Withdrawal Amount
			. 9 = Total Bonus Amount Claimed
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME, @BonusTypeName VARCHAR(100)
	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	DECLARE @BonusType TABLE (DBTypeId SMALLINT, BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), DataSource VARCHAR(100))

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		INSERT INTO @BonusType (DBTypeId, BonusTypeId, BonusTypeName, DataSource)
		SELECT DBTypeId, BonusTypeId, BonusTypeName, DataSource
		FROM dbo.N88_f_BonusType()

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		DECLARE @RowStart INT, @RowEnd INT
		SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

		-- Detail by Campaign, User
		DECLARE @DefaultSignupUrl VARCHAR(200), @APPSignupUrl VARCHAR(200)
		DECLARE @CreditAgentName VARCHAR(30) = ''
		CREATE TABLE #Affiliate (CustId INT, AffCode VARCHAR(20))

		IF @SiteId = 1
		BEGIN
			SELECT @APPSignupUrl = 'app.n17881788.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N88.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N88.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01', @APPSignupUrl = 'app.goal123.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01', @APPSignupUrl = 'app.bwing.com', @DefaultSignupUrl = 'www.bwing.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N8B.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8B.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END

		-- Get Bonus data
		BEGIN
			-- BonusInfo
			CREATE TABLE #BonusInfo (CustId INT, BonusCode VARCHAR(50), Amount MONEY)
			INSERT INTO #BonusInfo (CustId, BonusCode, Amount)
			SELECT b.CustId, b.BonusCode, SUM(b.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, BonusCode, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(BonusAmount) AS Amount
				FROM dbo.BonusInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, BonusCode, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.CustId, b.BonusCode

			-- RebateMLog
			INSERT INTO #BonusInfo (CustId, BonusCode, Amount)
			SELECT b.CustId, b.BonusCode, SUM(b.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, BonusCode, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(RedeemAmount) AS Amount
				FROM dbo.RebateMLog WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, BonusCode, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.CustId, b.BonusCode

			-- DrawLog
			INSERT INTO #BonusInfo (CustId, BonusCode, Amount)
			SELECT b.CustId, ed.EventName, SUM(b.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, EventId, CONVERT(DATE, DATEADD(HOUR, -4, DrawTime)) AS ExchangeDate, SUM(Amount) AS Amount
				FROM dbo.DrawLog d WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND DrawTime >= @FromDateTimeGMT AND DrawTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, EventId, CONVERT(DATE, DATEADD(HOUR, -4, DrawTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
				INNER JOIN dbo.EventDraw ed WITH (NOLOCK) ON b.EventId = ed.EventId AND ed.SiteId = @SiteId
			GROUP BY b.CustId, ed.EventName

			-- AdjustmentInfo
			SET @BonusTypeName = NULL
			SELECT TOP 1 @BonusTypeName = BonusTypeName FROM @BonusType WHERE DataSource = 'AdjustmentInfo'

			INSERT INTO #BonusInfo (CustId, BonusCode, Amount)
			SELECT b.CustId, @BonusTypeName, SUM(b.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(Amount * CASE
									WHEN AdjustType IN (1, 4) THEN -1 -- Debit, Decrease bonus
									WHEN AdjustType IN (2, 3) THEN 1 -- Credit, Increase bonus
									ELSE 0 END) AS Amount
				FROM dbo.AdjustmentInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
					AND Status = 2 -- Approved
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.CustId

			-- VipUpgradeReview
			SET @BonusTypeName = NULL
			SELECT TOP 1 @BonusTypeName = BonusTypeName FROM @BonusType WHERE DataSource = 'VipUpgradeReview'

			INSERT INTO #BonusInfo (CustId, BonusCode, Amount)
			SELECT b.CustId, @BonusTypeName, SUM(b.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, SettleTime)) AS ExchangeDate, SUM(UpgradeAmount) AS Amount
				FROM dbo.VipUpgradeReview WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND SettleTime >= @FromDateTimeGMT AND SettleTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
					AND Status = 4 -- Settled
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, SettleTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.CustId
		END

		-- Deposit, Withdrawal
		BEGIN
			CREATE TABLE #DepositInfo (CustId INT, Amount MONEY)
			INSERT INTO #DepositInfo (CustId, Amount)
			SELECT d.CustId, SUM(d.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(Amount) AS Amount
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND SiteId = @SiteId
					AND Status = 3 -- Approved
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) d
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.CustId

			CREATE TABLE #WithdrawalInfo (CustId INT, Amount MONEY)
			INSERT INTO #WithdrawalInfo (CustId, Amount)
			SELECT w.CustId, SUM(w.Amount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(Amount) AS Amount
				FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND SiteId = @SiteId
					AND Status = 6 -- Approved
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) w
				INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY w.CustId
		END

		SELECT @NRows = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN (SELECT CustId, BonusCode FROM #BonusInfo GROUP BY CustId, BonusCode) b ON c.CustId = b.CustId
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT RowId, BonusCode, Username, Currency, RegTime, SignupUrl, AffCode, TotalDepositAmount, TotalWithdrawalAmount, TotalBonusAmount
		FROM (
			SELECT BonusCode, Username, Currency, DATEADD(HOUR, @TimeZone, RegTime) AS RegTime, SignupUrl, AffCode, TotalDepositAmount, TotalWithdrawalAmount, TotalBonusAmount
				,ROW_NUMBER() OVER(ORDER BY
						 CASE WHEN BonusCode IS NULL THEN 1 ELSE 0 END
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN BonusCode END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN BonusCode END DESC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN Username END ASC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN Username END DESC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN Currency END ASC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN Currency END DESC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN RegTime END ASC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN RegTime END DESC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN SignupUrl END ASC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN SignupUrl END DESC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN AffCode END ASC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN AffCode END DESC
						,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN TotalDepositAmount END ASC
						,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN TotalDepositAmount END DESC
						,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN TotalWithdrawalAmount END ASC
						,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN TotalWithdrawalAmount END DESC
						,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 1 THEN TotalBonusAmount END ASC
						,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 0 THEN TotalBonusAmount END DESC
						,Username) AS RowId
			FROM (
				SELECT b.BonusCode, c.UserName, c.RegTime
					,CASE
						WHEN e.ExchangeId = 51 THEN 'INH'
						WHEN e.ExchangeId = 20 THEN 'UUS'
						ELSE e.Code END AS Currency
					,CASE
						WHEN a.CustId IS NOT NULL THEN cg.SignupUrl
						WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
						WHEN c.SiteId = 1 AND ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
						WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3 THEN @DefaultSignupUrl
						WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
						ELSE cg.SignupUrl END AS SignupUrl
					,a.AffCode
					,ISNULL(d.Amount, 0) AS TotalDepositAmount
					,ISNULL(w.Amount, 0) AS TotalWithdrawalAmount
					,ISNULL(b.Amount, 0) AS TotalBonusAmount
				FROM dbo.Customer c WITH (NOLOCK)
					INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
					INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON c.CurrencyId = e.ExchangeId
					LEFT JOIN #Affiliate a ON c.CustId = a.CustId
					LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
					INNER JOIN (
						SELECT CustId, BonusCode, SUM(Amount) AS Amount
						FROM #BonusInfo GROUP BY CustId, BonusCode
					) b ON b.CustId = c.CustId
					LEFT JOIN #DepositInfo d ON d.CustId = c.CustId
					LEFT JOIN #WithdrawalInfo w ON w.CustId = c.CustId
				WHERE c.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			) r
		) t
		WHERE RowId BETWEEN @RowStart AND @RowEnd

		DROP TABLE #Affiliate
		DROP TABLE #BonusInfo
		DROP TABLE #DepositInfo
		DROP TABLE #Exchange
		DROP TABLE #WithdrawalInfo
	END
END
GO