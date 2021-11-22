/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BonusClaimed]
	@LicenseeId				INT
	,@FromDate				DATE
	,@ToDate				DATE
	,@CompareFromDate		DATE = NULL
	,@CompareToDate			DATE = NULL
	,@CurrencyIds			VARCHAR(MAX)
	,@DisplayCurrency		VARCHAR(3)
	,@TimeZone				SMALLINT = 8
	,@TotalBonusUsers		INT = 0 OUTPUT
	,@TotalBasedBonusAmount MONEY = 0 OUTPUT
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20201029@Percy: Change Bonus User to Bonus Amount [RedmineID: #143879]
		- 20210113@Percy: Add Rebate & Cashback [RedmineID: #148616]
		- 20210401@Percy: [RedmineID: #150876]
			1. Add Bonus Name column
			2. Breakdown by original currency
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE, @BonusTypeName VARCHAR(100)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME

	CREATE TABLE #BonusInfo (BonusCode VARCHAR(50), EventId INT, CustId INT, Currency INT, BonusAmount MONEY, BasedBonusAmount MONEY, IsCompared BIT)
	CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
	DECLARE @BonusType TABLE (DBTypeId SMALLINT, BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), DataSource VARCHAR(100))

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		INSERT INTO @BonusType (DBTypeId, BonusTypeId, BonusTypeName, DataSource)
		SELECT DBTypeId, BonusTypeId, BonusTypeName, DataSource
		FROM dbo.N88_f_BonusType()
		
		-- Get data
		DECLARE @i TINYINT = 1, @IsCompared BIT
		WHILE @i <= 2
		BEGIN
			-- Data on GMT+0 --> convert timezone
			IF @i = 1
				SELECT @IsCompared = 0
					,@tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
					,@FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
					,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
			ELSE
				SELECT @IsCompared = 1
					,@tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
					,@FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
					,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))
			
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

			-- BonusInfo
			INSERT INTO #BonusInfo (BonusCode, CustId, Currency, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT b.BonusCode, b.CustId, b.CurrencyId, SUM(b.BonusAmount) AS BonusAmount, SUM(b.BonusAmount * e.Rate) AS BasedBonusAmount, @IsCompared
			FROM (
				SELECT b.BonusCode, b.CustId, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) AS ExchangeDate
					,SUM(b.BonusAmount / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmount
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY b.BonusCode, b.CustId, b.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime))
			) b
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.BonusCode, b.CustId, b.CurrencyId

			-- RebateMLog
			INSERT INTO #BonusInfo (BonusCode, CustId, Currency, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT r.BonusCode, r.CustId, r.CurrencyId, SUM(r.BonusAmount) AS BonusAmount, SUM(r.BonusAmount * e.Rate) AS BasedBonusAmount, @IsCompared
			FROM (
				SELECT r.BonusCode, r.CustId, r.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) AS ExchangeDate
					,SUM(r.RedeemAmount / CASE WHEN r.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.RebateMLog r WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
				WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND r.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY r.BonusCode, r.CustId, r.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime))
			) r
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId AND r.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY r.BonusCode, r.CustId, r.CurrencyId

			-- DrawLog
			INSERT INTO #BonusInfo (EventId, CustId, Currency, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT d.EventId, d.CustId, d.CurrencyId, SUM(d.BonusAmount) AS BonusAmount, SUM(d.BonusAmount * e.Rate) AS BasedBonusAmount, @IsCompared
			FROM (
				SELECT d.EventId, d.CustId, d.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, d.DrawTime)) AS ExchangeDate
					,SUM(d.Amount / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.DrawLog d WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
				WHERE d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND d.DrawTime >= @FromDateTimeGMT AND d.DrawTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND d.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY d.EventId, d.CustId, d.CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, d.DrawTime))
			) d
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.EventId, d.CustId, d.CurrencyId

			-- AdjustmentInfo
			SET @BonusTypeName = NULL
			SELECT TOP 1 @BonusTypeName = BonusTypeName FROM @BonusType WHERE DataSource = 'AdjustmentInfo'

			INSERT INTO #BonusInfo (BonusCode, CustId, Currency, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT @BonusTypeName, a.CustId, a.CurrencyId, SUM(a.BonusAmount) AS BonusAmount, SUM(a.BonusAmount * e.Rate) AS BasedBonusAmount, @IsCompared
			FROM (
				SELECT a.CurrencyId, a.CustId, CONVERT(DATE, DATEADD(HOUR, -4, a.CreateTime)) AS ExchangeDate
					,SUM(a.Amount * CASE
									WHEN a.AdjustType IN (1, 3) THEN 1 -- Credit, Increase bonus
									WHEN a.AdjustType IN (2, 4) THEN -1 -- Debit, Decrease bonus
									ELSE 0 END
									/ CASE WHEN a.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.AdjustmentInfo a WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
				WHERE a.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND a.CreateTime >= @FromDateTimeGMT AND a.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND a.SiteId = @SiteId
					AND c.IsTest = 0
					AND a.Status = 2 -- Approved
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
					AND 1 = CASE WHEN a.CreateTime < '2021-10-31 16:00' OR a.AdjustType IN (3, 4) THEN 1 ELSE 0 END -- From 1 Nov 2021 (GMT+8), just get Increase & Decrease bonus
				GROUP BY a.CurrencyId, a.CustId, CONVERT(DATE, DATEADD(HOUR, -4, a.CreateTime))
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.CustId, a.CurrencyId

			-- LogAdminAdjustWallet
			SET @BonusTypeName = NULL
			SELECT TOP 1 @BonusTypeName = BonusTypeName FROM @BonusType WHERE DataSource = 'LogAdminAdjustWallet'

			INSERT INTO #BonusInfo (BonusCode, CustId, Currency, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT @BonusTypeName, a.CustId, a.CurrencyId, SUM(a.BonusAmount) AS BonusAmount, SUM(a.BonusAmount * e.Rate) AS BasedBonusAmount, @IsCompared
			FROM (
				SELECT a.CurrencyId, a.CustId, CONVERT(DATE, DATEADD(HOUR, -4, a.CreateTime)) AS ExchangeDate
					,SUM(a.Amount * CASE
									WHEN Direction = 1 THEN 1 -- 3rd Add
									WHEN Direction = 2 THEN -1 -- 3rd Minus
									ELSE 0 END
									/ CASE WHEN a.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.LogAdminAdjustWallet a WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
				WHERE a.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND a.CreateTime >= @FromDateTimeGMT AND a.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND a.SiteId = @SiteId
					AND c.IsTest = 0
					AND a.Status = 0 -- Success
					AND a.CreateTime < '2021-10-31 16:00' -- only get data before 1 Nov 2021 (GMT+8)
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY a.CurrencyId, a.CustId, CONVERT(DATE, DATEADD(HOUR, -4, a.CreateTime))
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.CustId, a.CurrencyId

			-- VipUpgradeReview
			SET @BonusTypeName = NULL
			SELECT TOP 1 @BonusTypeName = BonusTypeName FROM @BonusType WHERE DataSource = 'VipUpgradeReview'

			INSERT INTO #BonusInfo (BonusCode, CustId, Currency, BonusAmount, BasedBonusAmount, IsCompared)
			SELECT @BonusTypeName, v.CustId, v.CurrencyId, SUM(v.BonusAmount) AS BonusAmount, SUM(v.BonusAmount * e.Rate) AS BasedBonusAmount, @IsCompared
			FROM (
				SELECT v.CurrencyId, v.CustId, CONVERT(DATE, DATEADD(HOUR, -4, v.SettleTime)) AS ExchangeDate
					,SUM(v.UpgradeAmount / CASE WHEN v.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ) AS BonusAmount
				FROM dbo.VipUpgradeReview v WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON v.CustId = c.CustId
				WHERE v.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND v.SettleTime >= @FromDateTimeGMT AND v.SettleTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND v.SiteId = @SiteId
					AND c.IsTest = 0
					AND v.Status = 4 -- Settled
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY v.CurrencyId, v.CustId, CONVERT(DATE, DATEADD(HOUR, -4, v.SettleTime))
			) v
				INNER JOIN #Exchange e ON v.CurrencyId = e.ExchangeId AND v.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY v.CustId, v.CurrencyId

			SELECT @i = @i + 1
		END

		-- Summary by Currency
		SELECT Currency
			,SUM(CASE WHEN IsCompared = 0 THEN BonusAmount ELSE 0 END)		AS BonusAmountClaimeds
			,SUM(CASE WHEN IsCompared = 0 THEN BasedBonusAmount ELSE 0 END) AS BasedBonusAmountClaimeds
			,SUM(CASE WHEN IsCompared = 1 THEN BonusAmount ELSE 0 END)		AS CompareBonusAmountClaimeds
			,SUM(CASE WHEN IsCompared = 1 THEN BasedBonusAmount ELSE 0 END) AS CompareBasedBonusAmountClaimeds
		FROM #BonusInfo
		GROUP BY Currency

		-- Detail by Bonus Code, Currency
		SELECT BonusCode, Currency, BonusName, BonusUsers, BonusAmount, BasedBonusAmount
		FROM (
			SELECT ISNULL(e.EventName, b.BonusCode) AS BonusCode, b.Currency, ISNULL(e.EventName, p.Description) AS BonusName, b.BonusUsers, b.BonusAmount, b.BasedBonusAmount
			FROM (
				SELECT BonusCode, EventId, Currency, COUNT(DISTINCT CustId) AS BonusUsers, SUM(BonusAmount) AS BonusAmount, SUM(BasedBonusAmount) AS BasedBonusAmount
				FROM #BonusInfo
				WHERE IsCompared = 0
				GROUP BY BonusCode, EventId, Currency
			) b
				LEFT JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode
				LEFT JOIN dbo.EventDraw e WITH (NOLOCK) ON b.EventId = e.EventId AND e.SiteId = @SiteId
		) t
		ORDER BY CASE WHEN BonusCode IS NULL THEN 1 ELSE 0 END, BonusCode

		-- Total
		SELECT @TotalBonusUsers = COUNT(DISTINCT CustId), @TotalBasedBonusAmount = SUM(BasedBonusAmount) FROM #BonusInfo WHERE IsCompared = 0

		DROP TABLE #BonusInfo
		DROP TABLE #Exchange
	END
END
GO