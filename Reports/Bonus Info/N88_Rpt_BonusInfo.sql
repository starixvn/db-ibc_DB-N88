/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_BonusInfo]
	@LicenseeId			INT
	,@BonusName			VARCHAR(500) = ''
	,@BonusTypeIds		VARCHAR(MAX) = ''
	,@BonusStatusIds	VARCHAR(MAX) = ''
	,@FromDate			DATE
	,@ToDate			DATE
	,@ClaimedStatusIds	VARCHAR(MAX) = ''
	,@GroupBy			TINYINT
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

	Param's Explanation:
		@GroupBy
			.1 = Bonus Code
			.2 = Claimed Date, Bonus Code
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @tmpFromDate DATE, @tmpToDate DATE
	CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)

	CREATE TABLE #BonusInfo (Date DATE, BonusCode VARCHAR(50), CustId INT, CurrencyId INT, Status TINYINT, ExchangeDate DATE, BetCount INT, Amount MONEY, ExchangeGGRDate DATE, GGR MONEY)
	CREATE TABLE #DepositInfo (Date DATE, CustId INT, CurrencyId INT, ExchangeDate DATE, Amount MONEY)
	CREATE TABLE #WithdrawalInfo (Date DATE, CustId INT, CurrencyId INT, ExchangeDate DATE, Amount MONEY)

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)

		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
		
		-- Get data
		IF EXISTS (SELECT 1 FROM bodb02.dbo.strSplit(@BonusTypeIds, ',') WHERE val IN ('1', '2', '3'))
			INSERT INTO #BonusInfo (Date, BonusCode, CustId, CurrencyId, Status, ExchangeDate, ExchangeGGRDate, BetCount, Amount, GGR)
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.CreateTime)), b.BonusCode, b.CustId, b.CurrencyId, b.Status, CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)), CONVERT(DATE, DATEADD(HOUR, -4, tb.SettledTime))
				,COUNT(1) AS BetCount, SUM(b.BonusAmount) AS Amount, -SUM(ISNULL(tb.WinlostAmount, 0))
			FROM dbo.BonusInfo b WITH (NOLOCK)
				LEFT JOIN dbo.TpBetRecord tb WITH (NOLOCK)
					ON		b.BonusId = tb.BonusId
						AND tb.SettlementType IN (1, 3)
						AND tb.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CONVERT(DATE, DATEADD(HOUR, @TimeZone, tb.SettledTime)) = CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.CreateTime))
			WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND ',' + @BonusTypeIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.PromotionType) + ',%'
				AND ',' + @ClaimedStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.Status) + ',%'
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.CreateTime)), b.BonusCode, b.CustId, b.CurrencyId, b.Status, CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)), CONVERT(DATE, DATEADD(HOUR, -4, tb.SettledTime))
		
		IF EXISTS (SELECT 1 FROM bodb02.dbo.strSplit(@BonusTypeIds, ',') WHERE val IN ('6', '7'))
			INSERT INTO #BonusInfo (Date, BonusCode, CustId, CurrencyId, ExchangeDate, BetCount, Amount, GGR)
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), BonusCode, CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
				,COUNT(1) AS BetCount, SUM(RedeemAmount) AS Amount, 0 AS GGR
			FROM dbo.RebateMLog WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND (
					',' + @BonusTypeIds + ',' LIKE '%,6,%' AND RebateType = 1
					OR ',' + @BonusTypeIds + ',' LIKE '%,7,%' AND RebateType = 2
				)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), BonusCode, CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

		INSERT INTO #DepositInfo (Date, CustId, CurrencyId, ExchangeDate, Amount)
		SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
		FROM dbo.DepositInfo WITH (NOLOCK)
		WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
			AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND Status = 3 -- Approved
			AND SiteId = @SiteId
		GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

		INSERT INTO #WithdrawalInfo (Date, CustId, CurrencyId, ExchangeDate, Amount)
		SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
		FROM dbo.WithdrawalInfo WITH (NOLOCK)
		WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
			AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND Status = 6 -- Approved
			AND SiteId = @SiteId
		GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

		DELETE b
		FROM #BonusInfo b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			LEFT JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode AND p.SiteId = @SiteId
														AND (p.Description LIKE '%' + ISNULL(@BonusName, '') + '%' OR p.BonusCode LIKE '%' + ISNULL(@BonusName, '') + '%')
														AND ',' + @BonusStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), p.Status) + ',%'
		WHERE c.IsTest = 1 OR p.BonusCode IS NULL

		DELETE #DepositInfo WHERE CustId NOT IN (SELECT CustId FROM #BonusInfo)
		DELETE #WithdrawalInfo WHERE CustId NOT IN (SELECT CustId FROM #BonusInfo)

		UPDATE b
		SET b.Amount = b.Amount * e.Rate
		FROM #BonusInfo b
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate

		UPDATE b
		SET b.GGR = b.GGR * e.Rate
		FROM #BonusInfo b
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeGGRDate BETWEEN e.FromDate AND e.ToDate

		UPDATE d
		SET d.Amount = d.Amount * e.Rate
		FROM #DepositInfo d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate

		UPDATE w
		SET w.Amount = w.Amount * e.Rate
		FROM #WithdrawalInfo w
			INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
	END

	-- Return detail
	IF @GroupBy = 1 -- Bonus Code
	BEGIN
		;WITH CTE_Bonus AS (
			SELECT b.BonusCode
				,SUM(b.Running)				AS Running
				,SUM(b.Canceled)			AS Canceled
				,SUM(b.Fulfill)				AS Fulfill
				,SUM(b.OtherPlatform)		AS OtherPlatform
				,COUNT(DISTINCT b.CustId)	AS TotalClaimants
				,SUM(b.Amount)				AS TotalClaimedAmount
				,SUM(b.GGR)					AS GGR
				,SUM(ISNULL(d.Amount, 0))	AS TotalDeposit
				,SUM(ISNULL(w.Amount, 0))	AS TotalWithdrawal
			FROM
				(
					SELECT b.CustId, b.BonusCode
						,SUM(CASE WHEN b.Status = 1 THEN b.BetCount ELSE 0 END) AS Running
						,SUM(CASE WHEN b.Status = 2 THEN b.BetCount ELSE 0 END) AS Canceled
						,SUM(CASE WHEN b.Status = 4 THEN b.BetCount ELSE 0 END) AS Fulfill
						,SUM(CASE WHEN b.Status = 5 THEN b.BetCount ELSE 0 END) AS OtherPlatform
						,SUM(b.Amount) AS Amount
						,SUM(b.GGR) AS GGR
					FROM #BonusInfo b
					GROUP BY b.CustId, b.BonusCode
				) b
				LEFT JOIN (
					SELECT d.CustId, SUM(d.Amount) AS Amount
					FROM #DepositInfo d
					GROUP BY d.CustId
				) d ON d.CustId = b.CustId
				LEFT JOIN (
					SELECT w.CustId, SUM(w.Amount) AS Amount
					FROM #WithdrawalInfo w
					GROUP BY w.CustId
				) w ON w.CustId = b.CustId
			GROUP BY b.BonusCode
		)
		SELECT CONVERT(DATE, @FromDate) AS Date, p.Description AS BonusName, p.BonusCode, p.PromotionType AS BonusType, p.Status AS BonusStatus
			,DATEADD(HOUR, @TimeZone, p.StartDate) AS StartDate
			,DATEADD(HOUR, @TimeZone, p.EndDate) AS EndDate
			,b.Running, b.Canceled, b.Fulfill, b.OtherPlatform, b.TotalClaimants, b.TotalClaimedAmount, b.GGR, b.TotalDeposit, b.TotalWithdrawal
		FROM CTE_Bonus b
			INNER JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode AND p.SiteId = @SiteId
	END
	ELSE IF @GroupBy = 2 -- Date, Bonus Code
	BEGIN
		;WITH CTE_Bonus AS (
			SELECT CONVERT(DATE, ISNULL(ISNULL(b.Date, d.Date), w.Date)) AS Date
				,b.BonusCode
				,SUM(ISNULL(b.Running, 0))			AS Running
				,SUM(ISNULL(b.Canceled, 0))			AS Canceled
				,SUM(ISNULL(b.Fulfill, 0))			AS Fulfill
				,SUM(ISNULL(b.OtherPlatform, 0))	AS OtherPlatform
				,COUNT(DISTINCT b.CustId)	AS TotalClaimants
				,SUM(ISNULL(b.Amount, 0))	AS TotalClaimedAmount
				,SUM(ISNULL(b.GGR, 0))		AS GGR
				,SUM(ISNULL(d.Amount, 0))	AS TotalDeposit
				,SUM(ISNULL(w.Amount, 0))	AS TotalWithdrawal
			FROM
				(
					SELECT b.Date, b.CustId, b.BonusCode
						,SUM(CASE WHEN b.Status = 1 THEN b.BetCount ELSE 0 END) AS Running
						,SUM(CASE WHEN b.Status = 2 THEN b.BetCount ELSE 0 END) AS Canceled
						,SUM(CASE WHEN b.Status = 4 THEN b.BetCount ELSE 0 END) AS Fulfill
						,SUM(CASE WHEN b.Status = 5 THEN b.BetCount ELSE 0 END) AS OtherPlatform
						,SUM(b.Amount) AS Amount
						,SUM(b.GGR) AS GGR
					FROM #BonusInfo b
					GROUP BY b.Date, b.CustId, b.BonusCode
				) b
				FULL OUTER JOIN (
					SELECT d.Date, d.CustId, SUM(d.Amount) AS Amount
					FROM #DepositInfo d
					GROUP BY d.Date, d.CustId
				) d ON d.CustId = b.CustId AND d.Date = b.Date
				FULL OUTER JOIN (
					SELECT w.Date, w.CustId, SUM(w.Amount) AS Amount
					FROM #WithdrawalInfo w
					GROUP BY w.Date, w.CustId
				) w ON w.CustId = b.CustId AND w.Date = b.Date
			GROUP BY CONVERT(DATE, ISNULL(ISNULL(b.Date, d.Date), w.Date)), b.BonusCode
		)
		SELECT b.Date, p.Description AS BonusName, p.BonusCode, p.PromotionType AS BonusType, p.Status AS BonusStatus
			,DATEADD(HOUR, @TimeZone, p.StartDate) AS StartDate
			,DATEADD(HOUR, @TimeZone, p.EndDate) AS EndDate
			,b.Running, b.Canceled, b.Fulfill, b.OtherPlatform, b.TotalClaimants, b.TotalClaimedAmount, b.GGR, b.TotalDeposit, b.TotalWithdrawal
		FROM CTE_Bonus b
			INNER JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode AND p.SiteId = @SiteId
		ORDER BY b.Date, p.Description
	END

	-- Return total
	;WITH CTE_Bonus AS (
		SELECT SUM(CASE WHEN Status = 1 THEN BetCount ELSE 0 END) AS Running
				,SUM(CASE WHEN Status = 2 THEN BetCount ELSE 0 END) AS Canceled
				,SUM(CASE WHEN Status = 4 THEN BetCount ELSE 0 END) AS Fulfill
				,SUM(CASE WHEN Status = 5 THEN BetCount ELSE 0 END) AS OtherPlatform
				,COUNT(DISTINCT CustId) AS TotalClaimants, SUM(Amount) AS Amount, SUM(GGR) AS GGR
			FROM #BonusInfo
			GROUP BY BonusCode
	)
	SELECT Running, Canceled, Fulfill, OtherPlatform, TotalClaimants, Amount AS TotalClaimedAmount, GGR, TotalDeposit, TotalWithdrawal
	FROM (SELECT SUM(Running) AS Running, SUM(Canceled) AS Canceled, SUM(Fulfill) AS Fulfill, SUM(OtherPlatform) AS OtherPlatform, SUM(TotalClaimants) AS TotalClaimants, SUM(GGR) AS GGR, SUM(Amount) AS Amount FROM CTE_Bonus) b
		OUTER APPLY (SELECT SUM(Amount) AS TotalDeposit FROM #DepositInfo) d
		OUTER APPLY (SELECT SUM(Amount) AS TotalWithdrawal FROM #WithdrawalInfo) w

	DROP TABLE #BonusInfo
	DROP TABLE #DepositInfo
	DROP TABLE #Exchange
	DROP TABLE #WithdrawalInfo
END
GO