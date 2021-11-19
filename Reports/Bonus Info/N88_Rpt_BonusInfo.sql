/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_BonusInfo]
	@LicenseeId			INT
	,@BonusName			VARCHAR(500) = ''
	,@BonusTypeIds		VARCHAR(MAX) = ''
	,@BonusStatusIds	VARCHAR(MAX) = ''
	,@FromDate			DATE
	,@ToDate			DATE
	,@ClaimedStatusIds	VARCHAR(MAX) = ''
	,@GroupBy			TINYINT
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200105@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200105@Percy: Initialize SP [RedmineID: #146759]
		- 20210125@Percy: Add group by Claimed Date, Bonus Code + Add GGR column [RedmineID: #149268]
		- 20210629@Sol: MPA - Apply Currency permission - [RedmineID: #157588]
		- 20210715@Percy: Exclude Jackpot, Contribition from Win Loss (GGR) [RedmineID: #158438]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]

	Param's Explanation:
		@GroupBy
			.1 = Bonus Code
			.2 = Claimed Date, Bonus Code
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @BonusTypeId INT, @BonusTypeName VARCHAR(100)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @tmpFromDate DATE, @tmpToDate DATE
	CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT, ActualRate FLOAT)

	CREATE TABLE #BonusType (DBTypeId SMALLINT, BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), DataSource VARCHAR(100), IsSelected BIT)
	CREATE TABLE #DepositInfo (Date DATE, CustId INT, Amount MONEY)
	CREATE TABLE #WithdrawalInfo (Date DATE, CustId INT, Amount MONEY)
	CREATE TABLE #BonusInfo (
		Date DATE, BonusCode VARCHAR(50), BonusTypeId SMALLINT, DataSource VARCHAR(100), EventId INT, CustId INT, Status TINYINT, BetCount INT
		,Amount MONEY, GGR MONEY DEFAULT (0), ProgressiveBet MONEY DEFAULT (0), ProgressiveWin MONEY DEFAULT (0)
	)

	BEGIN
		SELECT @BonusName = ISNULL(@BonusName, '')

		INSERT INTO #BonusType (DBTypeId, BonusTypeId, BonusTypeName, DataSource, IsSelected)
		SELECT DBTypeId, BonusTypeId, BonusTypeName, DataSource
			 ,CASE WHEN ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(20), BonusTypeId) + ',%' THEN 1 ELSE 0 END
		FROM dbo.N88_f_BonusType()

		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)

		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate, ActualRate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
		
		-- BonusInfo
		IF EXISTS (SELECT 1 FROM #BonusType WHERE DataSource = 'BonusInfo' AND IsSelected = 1)
		BEGIN
			SET @BonusTypeIds = NULL
			SELECT @BonusTypeIds = COALESCE(@BonusTypeIds + ',', '') + CONVERT(VARCHAR(10), DBTypeId)
			FROM #BonusType WHERE DataSource = 'BonusInfo' AND DBTypeId <> 0

			CREATE TABLE #TpBetRecord (BonusId INT, CustId INT, WinlostAmount MONEY, ProgressiveBet MONEY, ProgressiveWin MONEY)
			INSERT INTO #TpBetRecord (BonusId, CustId, WinlostAmount, ProgressiveBet, ProgressiveWin)
			SELECT t.BonusId, t.CustId, SUM(t.WinlostAmount * e.ActualRate), SUM(t.ProgressiveBet * e.ActualRate), SUM(t.ProgressiveWin * e.ActualRate)
			FROM (
				SELECT BonusId, CustId, Currency, CONVERT(DATE, DATEADD(HOUR, -4, SettledTime)) AS ExchangeDate -- GMT-4
					,SUM(CASE
							WHEN GameType IN (41, 42) THEN ISNULL(Revenue, 0)
							ELSE ISNULL(Winloss, 0) - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0) END
					) AS WinlostAmount
					,SUM(ISNULL(ProgressiveBet, 0)) AS ProgressiveBet
					,SUM(ISNULL(ProgressiveWin, 0)) AS ProgressiveWin
				FROM dbo.N88_SumWinloss WITH (NOLOCK)
				WHERE SettledTime >= @FromDateTimeGMT AND SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND BonusId > 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), Currency) + ',%'
				GROUP BY BonusId, CustId, Currency, CONVERT(DATE, DATEADD(HOUR, -4, SettledTime))
				UNION SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL -- run this query first
			) t
				INNER JOIN #Exchange e ON t.Currency = e.ExchangeId AND t.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY t.BonusId, t.CustId

			INSERT INTO #BonusInfo (Date, BonusCode, BonusTypeId, CustId, Status, DataSource, BetCount, Amount, GGR, ProgressiveBet, ProgressiveWin)
			SELECT b.Date, b.BonusCode, bt.BonusTypeId, b.CustId, b.Status, 'BonusInfo'
				, SUM(b.BetCount), SUM(b.Amount * e.Rate), SUM(b.GGR), SUM(b.ProgressiveBet), SUM(b.ProgressiveWin)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.CreateTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) AS ExchangeDate
					,b.BonusCode, b.CustId, b.CurrencyId, b.Status
					,CONVERT(SMALLINT, CASE WHEN ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.PromotionType) + ',%' THEN b.PromotionType ELSE 0 END) AS DBTypeId
					,COUNT(1) AS BetCount, SUM(b.BonusAmount) AS Amount
					,-SUM(ISNULL(tb.WinlostAmount, 0)) AS GGR, SUM(ISNULL(tb.ProgressiveBet, 0)) AS ProgressiveBet, SUM(ISNULL(tb.ProgressiveWin, 0)) AS ProgressiveWin
				FROM dbo.BonusInfo b WITH (NOLOCK)
					OUTER APPLY (
						SELECT SUM(tb.WinlostAmount) AS WinlostAmount, SUM(tb.ProgressiveBet) AS ProgressiveBet, SUM(tb.ProgressiveWin) AS ProgressiveWin
						FROM #TpBetRecord tb
						WHERE b.CustId = tb.CustId AND b.BonusId = tb.BonusId
					) tb
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND ',' + @ClaimedStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.Status) + ',%'
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime))
					,b.BonusCode, b.CustId, b.CurrencyId, b.Status
					,CONVERT(SMALLINT, CASE WHEN ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.PromotionType) + ',%' THEN b.PromotionType ELSE 0 END)
				UNION SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL -- run this query first
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
				INNER JOIN #BonusType bt ON b.DBTypeId = bt.DBTypeId AND bt.DataSource = 'BonusInfo' AND bt.IsSelected = 1
			GROUP BY b.Date, b.BonusCode, bt.BonusTypeId, b.CustId, b.Status

			DROP TABLE #TpBetRecord
		END
		
		-- RebateMLog
		IF EXISTS (SELECT 1 FROM #BonusType WHERE DataSource = 'RebateMLog' AND IsSelected = 1)
		BEGIN
			SET @BonusTypeIds = NULL
			SELECT @BonusTypeIds = COALESCE(@BonusTypeIds + ',', '') + CONVERT(VARCHAR(10), DBTypeId)
			FROM #BonusType WHERE DataSource = 'RebateMLog' AND DBTypeId <> 0
			
			INSERT INTO #BonusInfo (Date, BonusCode, BonusTypeId, CustId, DataSource, BetCount, Amount)
			SELECT r.Date, r.BonusCode, bt.BonusTypeId, r.CustId, 'RebateMLog', SUM(r.BetCount), SUM(r.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,BonusCode, CustId, CurrencyId
					,CONVERT(SMALLINT, CASE WHEN ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), RebateType) + ',%' THEN RebateType ELSE 0 END) AS DBTypeId
					,COUNT(1) AS BetCount, SUM(RedeemAmount) AS Amount
				FROM dbo.RebateMLog WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,BonusCode, CustId, CurrencyId
					,CONVERT(SMALLINT, CASE WHEN ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), RebateType) + ',%' THEN RebateType ELSE 0 END)
				UNION SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL -- run this query first
			) r
				INNER JOIN #BonusType bt ON r.DBTypeId = bt.DBTypeId AND bt.DataSource = 'RebateMLog' AND bt.IsSelected = 1
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId AND r.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY r.Date, r.BonusCode, bt.BonusTypeId, r.CustId
		END

		-- DrawLog
		SET @BonusTypeId = NULL
		SELECT TOP 1 @BonusTypeId = BonusTypeId FROM #BonusType WHERE DataSource = 'DrawLog' AND IsSelected = 1
		
		IF @BonusTypeId IS NOT NULL
		BEGIN
			INSERT INTO #BonusInfo (Date, EventId, BonusTypeId, CustId, DataSource, BetCount, Amount)
			SELECT d.Date, d.EventId, @BonusTypeId, d.CustId, 'DrawLog', SUM(d.BetCount), SUM(d.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, DrawTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, DrawTime)) AS ExchangeDate
					,CustId, CurrencyId, EventId
					,COUNT(1) AS BetCount
					,SUM(Amount) AS Amount
				FROM dbo.DrawLog WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND DrawTime >= @FromDateTimeGMT AND DrawTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, DrawTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, DrawTime))
					,CustId, CurrencyId, EventId
			) d
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.Date, d.EventId, d.CustId
		END

		-- AdjustmentInfo
		SET @BonusTypeId = NULL
		SELECT TOP 1 @BonusTypeId = BonusTypeId, @BonusTypeName = BonusTypeName FROM #BonusType WHERE DataSource = 'AdjustmentInfo' AND IsSelected = 1
		
		IF @BonusName = '' OR @BonusTypeId IS NOT NULL
		BEGIN
			INSERT INTO #BonusInfo (Date, BonusCode, BonusTypeId, CustId, DataSource, BetCount, Amount)
			SELECT a.Date, @BonusTypeName, @BonusTypeId, a.CustId, 'AdjustmentInfo', SUM(a.BetCount), SUM(a.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,CustId, CurrencyId
					,COUNT(1) AS BetCount
					,SUM(Amount * CASE
									WHEN AdjustType IN (1, 3) THEN 1 -- Credit, Increase bonus
									WHEN AdjustType IN (2, 4) THEN -1 -- Debit, Decrease bonus
									ELSE 0 END) AS Amount
				FROM dbo.AdjustmentInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
					AND Status = 2 -- Approved
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CustId, CurrencyId
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.Date, a.CustId
		END

		-- LogAdminAdjustWallet
		SET @BonusTypeId = NULL
		SELECT TOP 1 @BonusTypeId = BonusTypeId, @BonusTypeName = BonusTypeName FROM #BonusType WHERE DataSource = 'LogAdminAdjustWallet' AND IsSelected = 1
		
		IF @BonusName = '' OR @BonusTypeId IS NOT NULL
		BEGIN
			INSERT INTO #BonusInfo (Date, BonusCode, BonusTypeId, CustId, DataSource, BetCount, Amount)
			SELECT a.Date, @BonusTypeName, @BonusTypeId, a.CustId, 'LogAdminAdjustWallet', SUM(a.BetCount), SUM(a.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,CustId, CurrencyId
					,COUNT(1) AS BetCount
					,SUM(Amount * CASE
									WHEN Direction = 1 THEN 1 -- 3rd Add
									WHEN Direction = 2 THEN -1 -- 3rd Minus
									ELSE 0 END) AS Amount
				FROM dbo.LogAdminAdjustWallet WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
					AND Status = 0 -- Approved
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CustId, CurrencyId
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.Date, a.CustId
		END

		-- VIPUpgradeReview
		SET @BonusTypeId = NULL
		SELECT TOP 1 @BonusTypeId = BonusTypeId, @BonusTypeName = BonusTypeName FROM #BonusType WHERE DataSource = 'VIPUpgradeReview' AND IsSelected = 1
		
		IF @BonusName = '' OR @BonusTypeId IS NOT NULL
		BEGIN
			INSERT INTO #BonusInfo (Date, BonusCode, BonusTypeId, CustId, DataSource, BetCount, Amount)
			SELECT v.Date, @BonusTypeName, @BonusTypeId, v.CustId, 'VIPUpgradeReview', SUM(v.BetCount), SUM(v.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, SettleTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, SettleTime)) AS ExchangeDate
					,CustId, CurrencyId
					,COUNT(1) AS BetCount
					,SUM(UpgradeAmount) AS Amount
				FROM dbo.VipUpgradeReview WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND SettleTime >= @FromDateTimeGMT AND SettleTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
					AND Status = 4 -- Settled
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, SettleTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, SettleTime))
					,CustId, CurrencyId
			) v
				INNER JOIN #Exchange e ON v.CurrencyId = e.ExchangeId AND v.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY v.Date, v.CustId
		END

		-- Deposit, Withdrawal
		BEGIN
			INSERT INTO #DepositInfo (Date, CustId, Amount)
			SELECT CASE WHEN @GroupBy = 1 THEN CONVERT(DATE, @FromDate) ELSE d.Date END, d.CustId, SUM(d.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,CustId, CurrencyId
					,SUM(Amount) AS Amount
				FROM dbo.DepositInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND Status = 3 -- Approved
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CustId, CurrencyId
				UNION SELECT NULL, NULL, NULL, NULL, NULL -- run this query first
			) d
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY CASE WHEN @GroupBy = 1 THEN CONVERT(DATE, @FromDate) ELSE d.Date END, d.CustId

			INSERT INTO #WithdrawalInfo (Date, CustId, Amount)
			SELECT CASE WHEN @GroupBy = 1 THEN CONVERT(DATE, @FromDate) ELSE w.Date END, w.CustId, SUM(w.Amount * e.Rate)
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS Date
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,CustId, CurrencyId, SUM(Amount) AS Amount
				FROM dbo.WithdrawalInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND Status = 6 -- Approved
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CustId, CurrencyId
				UNION SELECT NULL, NULL, NULL, NULL, NULL -- run this query first
			) w
				INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY CASE WHEN @GroupBy = 1 THEN CONVERT(DATE, @FromDate) ELSE w.Date END, w.CustId
		END

		-- Filter data
		CREATE NONCLUSTERED INDEX IX_CustId_BonusCode ON #BonusInfo (CustId, BonusCode)

		CREATE TABLE #tmpResult (
			CustId INT, BonusCode VARCHAR(50), BonusName VARCHAR(100), BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), BonusStatus TINYINT
			,StartDate DATETIME, EndDate DATETIME, Date DATE, Running INT, Canceled INT, Fulfill INT, OtherPlatform INT
			,Amount MONEY, GGR MONEY, ProgressiveBet MONEY, ProgressiveWin MONEY
		)
		INSERT INTO #tmpResult (
			CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, BonusStatus, StartDate, EndDate, Date
			,Running, Canceled, Fulfill, OtherPlatform, Amount, GGR, ProgressiveBet, ProgressiveWin
		)
		SELECT b.CustId
			,CASE WHEN b.EventId IS NOT NULL THEN e.EventName ELSE b.BonusCode END AS BonusCode
			,CASE WHEN b.EventId IS NOT NULL THEN e.EventName ELSE p.Description END AS BonusName
			,b.BonusTypeId, bt.BonusTypeName, p.Status
			,DATEADD(HOUR, @TimeZone, ISNULL(p.StartDate, e.StartTime))
			,DATEADD(HOUR, @TimeZone, ISNULL(p.EndDate, e.EndTime))
			,CASE WHEN @GroupBy = 1 THEN CONVERT(DATE, @FromDate) ELSE b.Date END AS Date
			,SUM(CASE WHEN b.Status = 1 THEN b.BetCount ELSE 0 END) AS Running
			,SUM(CASE WHEN b.Status = 2 THEN b.BetCount ELSE 0 END) AS Canceled
			,SUM(CASE WHEN b.Status = 4 THEN b.BetCount ELSE 0 END) AS Fulfill
			,SUM(CASE WHEN b.Status = 5 THEN b.BetCount ELSE 0 END) AS OtherPlatform
			,SUM(b.Amount) AS Amount
			,SUM(b.GGR) AS GGR
			,SUM(b.ProgressiveBet) AS ProgressiveBet
			,SUM(b.ProgressiveWin) AS ProgressiveWin
		FROM #BonusInfo b
			INNER JOIN #BonusType bt ON b.BonusTypeId = bt.BonusTypeId AND b.DataSource = bt.DataSource AND bt.IsSelected = 1
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			LEFT JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode AND p.SiteId = @SiteId
														AND (p.Description LIKE '%' + @BonusName + '%' OR p.BonusCode LIKE '%' + @BonusName + '%')
														AND b.EventId IS NULL
			LEFT JOIN dbo.EventDraw e WITH (NOLOCK) ON b.EventId = e.EventId AND e.SiteId = @SiteId
														AND e.EventName LIKE '%' + @BonusName + '%'
		WHERE c.IsTest = 0
			AND (@BonusName = '' OR b.BonusCode LIKE '%' + @BonusName + '%' OR p.BonusCode IS NOT NULL OR e.EventId IS NOT NULL)
			AND (p.Status IS NULL OR ',' + @BonusStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), p.Status) + ',%')
		GROUP BY b.CustId
			,CASE WHEN b.EventId IS NOT NULL THEN e.EventName ELSE b.BonusCode END
			,CASE WHEN b.EventId IS NOT NULL THEN e.EventName ELSE p.Description END
			,b.BonusTypeId, bt.BonusTypeName, p.Status
			,DATEADD(HOUR, @TimeZone, ISNULL(p.StartDate, e.StartTime))
			,DATEADD(HOUR, @TimeZone, ISNULL(p.EndDate, e.EndTime))
			,CASE WHEN @GroupBy = 1 THEN CONVERT(DATE, @FromDate) ELSE b.Date END

		DELETE #DepositInfo WHERE CustId NOT IN (SELECT CustId FROM #tmpResult)
		DELETE #WithdrawalInfo WHERE CustId NOT IN (SELECT CustId FROM #tmpResult)
	END

	-- Return detail
	SELECT
		CONVERT(DATE, ISNULL(ISNULL(r.Date, d.Date), w.Date)) AS Date
		,ISNULL(r.BonusName, '') AS BonusName
		,ISNULL(r.BonusCode, '') AS BonusCode
		,r.BonusTypeId, r.BonusTypeName, r.BonusStatus, r.StartDate, r.EndDate
		,SUM(r.Running) AS Running
		,SUM(r.Canceled) AS Canceled
		,SUM(r.Fulfill) AS Fulfill
		,SUM(r.OtherPlatform) AS OtherPlatform
		,COUNT(DISTINCT r.CustId) AS TotalClaimants
		,SUM(r.Amount) AS TotalClaimedAmount
		,SUM(r.GGR) AS GGR
		,SUM(r.ProgressiveBet) AS ProgressiveBet
		,SUM(r.ProgressiveWin) AS ProgressiveWin
		,SUM(ISNULL(d.Amount, 0)) AS TotalDeposit
		,SUM(ISNULL(w.Amount, 0)) AS TotalWithdrawal
	FROM #tmpResult r
		FULL OUTER JOIN #DepositInfo d ON r.CustId = d.CustId AND r.Date = d.Date
		FULL OUTER JOIN #WithdrawalInfo w ON r.CustId = w.CustId AND r.Date = w.Date
	GROUP BY
		CONVERT(DATE, ISNULL(ISNULL(r.Date, d.Date), w.Date))
		,ISNULL(r.BonusName, '')
		,ISNULL(r.BonusCode, '')
		,r.BonusTypeId, r.BonusTypeName, r.BonusStatus, r.StartDate, r.EndDate
	ORDER BY Date, BonusName

	-- Return total
	SELECT Running, Canceled, Fulfill, OtherPlatform, TotalClaimants, TotalClaimedAmount, GGR, ProgressiveBet, ProgressiveWin, TotalDeposit, TotalWithdrawal
	FROM (
		SELECT SUM(Running) AS Running, SUM(Canceled) AS Canceled, SUM(Fulfill) AS Fulfill, SUM(OtherPlatform) AS OtherPlatform, COUNT(DISTINCT CustId) AS TotalClaimants
			,SUM(Amount) AS TotalClaimedAmount, SUM(GGR) AS GGR, SUM(ProgressiveBet) AS ProgressiveBet, SUM(ProgressiveWin) AS ProgressiveWin
		FROM #tmpResult
	) b
		OUTER APPLY (SELECT SUM(Amount) AS TotalDeposit FROM #DepositInfo) d
		OUTER APPLY (SELECT SUM(Amount) AS TotalWithdrawal FROM #WithdrawalInfo) w

	DROP TABLE #BonusInfo
	DROP TABLE #BonusType
	DROP TABLE #DepositInfo
	DROP TABLE #Exchange
	DROP TABLE #tmpResult
	DROP TABLE #WithdrawalInfo
END
GO