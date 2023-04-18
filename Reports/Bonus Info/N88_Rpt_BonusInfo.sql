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
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Integrate new bonus: Referral & Rebuild Bonus Structure [RedmineID: #171245]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230327@Malcolm: Add Group by Month [RedmineId: #185268]

	Param's Explanation:
		@GroupBy
			.1 = Bonus Code
			.2 = Claimed Date, Bonus Code
			.3 = Claimed Month, Bonus Code
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @BonusTypeId INT, @BonusTypeName VARCHAR(100), @TpCurrencyIds VARCHAR(MAX)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @tmpFromDate DATE, @tmpToDate DATE

	CREATE TABLE #BonusType (DBTypeId SMALLINT, BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), DataSource VARCHAR(100), IsSelected BIT)
	CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT, MulipleBy FLOAT)
	CREATE TABLE #DepositInfo (Date DATE, CustId INT, Amount MONEY)
	CREATE TABLE #WithdrawalInfo (Date DATE, CustId INT, Amount MONEY)
	CREATE TABLE #BonusInfo (
		Date DATE, BonusCode VARCHAR(100), BonusName VARCHAR(300), BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), StartTime DATETIME, EndTime DATETIME, PStatus TINYINT
		,CustId INT, Status TINYINT, BetCount INT, Amount MONEY, GGR MONEY DEFAULT (0), ProgressiveBet MONEY DEFAULT (0), ProgressiveWin MONEY DEFAULT (0)
	)

	BEGIN
		SELECT @TpCurrencyIds = 
		(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(tp.TpExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = t.value
		)
		
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

		INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate, MulipleBy)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), Rate, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
		
		-- BonusInfo (include GGR)
		IF EXISTS (SELECT 1 FROM #BonusType WHERE DataSource = 'BonusInfo' AND IsSelected = 1)
		BEGIN
			SET @BonusTypeIds = NULL
			SELECT @BonusTypeIds = COALESCE(@BonusTypeIds + ',', '') + CONVERT(VARCHAR(10), DBTypeId)
			FROM #BonusType WHERE DataSource = 'BonusInfo' AND DBTypeId <> 0

			CREATE TABLE #N88_SumWinloss (BonusId INT, CustId INT, WinlostAmount MONEY, ProgressiveBet MONEY, ProgressiveWin MONEY)
			INSERT INTO #N88_SumWinloss (BonusId, CustId, WinlostAmount, ProgressiveBet, ProgressiveWin)
			SELECT t.BonusId, t.CustId, SUM(t.WinlostAmount * e.Rate), SUM(t.ProgressiveBet * e.Rate), SUM(t.ProgressiveWin * e.Rate)
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
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), Currency) + ',%'
				GROUP BY BonusId, CustId, Currency, CONVERT(DATE, DATEADD(HOUR, -4, SettledTime))
				UNION SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL -- run this query first
			) t
				INNER JOIN #TpExchange e ON t.Currency = e.TpExchangeId AND t.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY t.BonusId, t.CustId
			
			INSERT INTO #BonusInfo (Date, BonusCode, BonusName, BonusTypeId, BonusTypeName, StartTime, EndTime, PStatus, CustId, Status
				,BetCount, Amount, GGR, ProgressiveBet, ProgressiveWin)
			SELECT b.Date, b.BonusCode, p.Description AS BonusName, bt.BonusTypeId, bt.BonusTypeName, DATEADD(HOUR, @TimeZone, p.StartDate), DATEADD(HOUR, @TimeZone, p.EndDate), p.Status, b.CustId, b.Status
				,SUM(b.BetCount), SUM(b.Amount * e.Rate / e.MulipleBy), SUM(b.GGR), SUM(b.ProgressiveBet), SUM(b.ProgressiveWin)
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
						FROM #N88_SumWinloss tb
						WHERE b.CustId = tb.CustId AND b.BonusId = tb.BonusId
					) tb
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND ',' + @ClaimedStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.Status) + ',%'
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime))
					,b.BonusCode, b.CustId, b.CurrencyId, b.Status
					,CONVERT(SMALLINT, CASE WHEN ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.PromotionType) + ',%' THEN b.PromotionType ELSE 0 END)
				UNION SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL -- run this query first
			) b
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId AND c.IsTest = 0
				INNER JOIN #TpExchange e ON b.CurrencyId = e.TpExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
				INNER JOIN #BonusType bt ON b.DBTypeId = bt.DBTypeId AND bt.DataSource = 'BonusInfo' AND bt.IsSelected = 1
				INNER JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode
			WHERE ',' + @BonusStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(5), p.Status) + ',%'
			GROUP BY b.Date, b.BonusCode, p.Description, bt.BonusTypeId, bt.BonusTypeName, DATEADD(HOUR, @TimeZone, p.StartDate), DATEADD(HOUR, @TimeZone, p.EndDate), p.Status, b.CustId, b.Status

			DROP TABLE #N88_SumWinloss
		END

		-- Other Bonus
		IF EXISTS (SELECT 1 FROM #BonusType WHERE DataSource <> 'BonusInfo' AND IsSelected = 1)
		BEGIN
			CREATE TABLE #tmpBonus (BonusDate DATE, DataSource VARCHAR(128), BonusType SMALLINT, BonusCode VARCHAR(100), BonusName VARCHAR(300), BonusStatus TINYINT, CustId INT, CurrencyId INT, BetCount INT, BonusAmount MONEY, BasedBonusAmount MONEY)
			INSERT INTO #tmpBonus (BonusDate, DataSource, BonusType, BonusCode, BonusName, BonusStatus, CustId, CurrencyId, BetCount, BonusAmount, BasedBonusAmount)
			EXEC dbo.N88_CustBonusSummary_Sel
				@SiteId = @SiteId
				,@FromDate = @FromDate
				,@ToDate = @ToDate
				,@CurrencyIds = @CurrencyIds
				,@DisplayCurrency = @DisplayCurrency
				,@TimeZone = @TimeZone
				,@GetByDate = 1

			INSERT INTO #BonusInfo (Date, BonusCode, BonusName, BonusTypeId, BonusTypeName, StartTime, EndTime, PStatus, CustId, BetCount, Amount)
			SELECT b.BonusDate, b.BonusCode, ISNULL(e.EventName, p.Description), bt.BonusTypeId, bt.BonusTypeName, DATEADD(HOUR, @TimeZone, ISNULL(e.StartTime, p.StartDate)), DATEADD(HOUR, @TimeZone, ISNULL(e.EndTime, p.EndDate)), p.Status, b.CustId, SUM(b.BetCount), SUM(b.BasedBonusAmount)
			FROM #tmpBonus b
				INNER JOIN #BonusType bt ON ISNULL(b.BonusType, 0) = bt.DBTypeId AND b.DataSource = bt.DataSource AND bt.IsSelected = 1
				LEFT JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode AND b.DataSource = 'RebateMLog' AND ',' + @BonusStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(5), p.Status) + ',%'
				LEFT JOIN dbo.EventDraw e WITH (NOLOCK) ON b.DataSource = 'DrawLog' AND b.BonusName = e.EventName AND e.SiteId = @SiteId
			WHERE (
				b.DataSource NOT IN ('BonusInfo', 'RebateMLog', 'DrawLog')
				OR (b.DataSource = 'RebateMLog' AND b.BonusCode = 'VipRebate') -- VIP Rebate
				OR p.BonusCode IS NOT NULL
				OR e.EventName IS NOT NULL
			)
			GROUP BY b.BonusDate, b.BonusCode, ISNULL(e.EventName, p.Description), bt.BonusTypeId, bt.BonusTypeName, DATEADD(HOUR, @TimeZone, ISNULL(e.StartTime, p.StartDate)), DATEADD(HOUR, @TimeZone, ISNULL(e.EndTime, p.EndDate)), p.Status, b.CustId

			DROP TABLE #tmpBonus
		END

		-- Deposit, Withdrawal
		BEGIN
			INSERT INTO #DepositInfo (Date, CustId, Amount)
			SELECT CASE @GroupBy WHEN 1 THEN CONVERT(DATE, @FromDate)
								 WHEN 2 THEN d.Date 
				   ELSE FORMAT(d.Date, 'yyyy-MM-01') END
				   ,d.CustId
				   ,SUM(d.Amount * e.Rate / e.MulipleBy)
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
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CustId, CurrencyId
				UNION SELECT NULL, NULL, NULL, NULL, NULL -- run this query first
			) d
				INNER JOIN #TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY CASE @GroupBy WHEN 1 THEN CONVERT(DATE, @FromDate) 
								   WHEN 2 THEN d.Date 
					 ELSE FORMAT(d.Date, 'yyyy-MM-01') END, d.CustId

			INSERT INTO #WithdrawalInfo (Date, CustId, Amount)
			SELECT CASE @GroupBy WHEN 1 THEN CONVERT(DATE, @FromDate) 
								 WHEN 2 THEN w.Date 
				   ELSE FORMAT(w.Date, 'yyyy-MM-01') END
				   ,w.CustId
				   ,SUM(w.Amount * e.Rate / e.MulipleBy)
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
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CustId, CurrencyId
				UNION SELECT NULL, NULL, NULL, NULL, NULL -- run this query first
			) w
				INNER JOIN #TpExchange e ON w.CurrencyId = e.TpExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY CASE @GroupBy WHEN 1 THEN CONVERT(DATE, @FromDate) 
								   WHEN 2 THEN w.Date
					 ELSE FORMAT(w.Date, 'yyyy-MM-01') END, w.CustId
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
		SELECT b.CustId, b.BonusCode, b.BonusName, b.BonusTypeId, b.BonusTypeName, b.PStatus, b.StartTime, b.EndTime
			,CASE @GroupBy WHEN 1 THEN CONVERT(DATE, @FromDate) 
						   WHEN 2 THEN b.Date 
		     ELSE FORMAT(b.Date, 'yyyy-MM-01') END AS Date
			,SUM(CASE WHEN b.Status = 1 THEN b.BetCount ELSE 0 END) AS Running
			,SUM(CASE WHEN b.Status = 2 THEN b.BetCount ELSE 0 END) AS Canceled
			,SUM(CASE WHEN b.Status = 4 THEN b.BetCount ELSE 0 END) AS Fulfill
			,SUM(CASE WHEN b.Status = 5 THEN b.BetCount ELSE 0 END) AS OtherPlatform
			,SUM(b.Amount) AS Amount
			,SUM(b.GGR) AS GGR
			,SUM(b.ProgressiveBet) AS ProgressiveBet
			,SUM(b.ProgressiveWin) AS ProgressiveWin
		FROM #BonusInfo b
		WHERE (
				@BonusName = ''
				OR CHARINDEX(@BonusName, b.BonusCode, 1) > 0
				OR CHARINDEX(@BonusName, b.BonusName, 1) > 0
			)
		GROUP BY b.CustId, b.BonusCode, b.BonusName, b.BonusTypeId, b.BonusTypeName, b.PStatus, b.StartTime, b.EndTime
			,CASE @GroupBy WHEN 1 THEN CONVERT(DATE, @FromDate) 
						   WHEN 2 THEN b.Date 
		     ELSE FORMAT(b.Date, 'yyyy-MM-01') END

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

	-- Get Bonus by Date
	SELECT b.BonusCode, b.Date
	FROM #BonusInfo b
	WHERE @BonusName = '' OR CHARINDEX(@BonusName, b.BonusCode, 1) > 0 OR CHARINDEX(@BonusName, b.BonusName, 1) > 0
	GROUP BY b.BonusCode, b.Date
	
	DROP TABLE #BonusInfo
	DROP TABLE #BonusType
	DROP TABLE #DepositInfo
	DROP TABLE #TpExchange
	DROP TABLE #tmpResult
	DROP TABLE #WithdrawalInfo
END
GO