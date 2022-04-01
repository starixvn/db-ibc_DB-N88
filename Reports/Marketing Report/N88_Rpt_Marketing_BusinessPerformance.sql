/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BusinessPerformance]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@FromLastXDays		DATE = NULL
AS

/*
	Created: 20200713@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Business Performance

	Revisions:
		- 20200713@Percy: Initialize SP [RedmineID: #137395]
		- 20200818@Percy: Support special date range [RedmineID: #137395]
		- 20200915@Percy: Recalculate total paid users (first deposit users) [RedmineID: #141575]
		- 20200928@Percy: Add Deposit Amount, Withdrawal Amount, Bonus Users [RedmineID: #141575]
		- 20201029@Percy: Change Bonus User to Bonus Amount [RedmineID: #143879]
		- 20201223@Sol: Add newly active registered users info - [RedmineID: #147542]
		- 20210113@Percy: Add Rebate & Cashback [RedmineID: #148616]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20210719@Sol: MPA - Apply Date Range permission & some enhancement - [RedmineID: #158257]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
		- 20220214@Percy: Total Active Users base on Registration Date [RedmineID: #164724]
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]

	Param explaination:
		- @FromLastXDays:
			+ NULL: no limit
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME
			,@FromLastXDaysGMT DATETIME

	DECLARE @TotalUsers INT
			,@TotalDepositUsers INT
			,@TotalActiveUsers INT
			,@DepositUsers INT, @CompareDepositUsers INT
			,@UptoTotalUsers INT, @CompareUptoTotalUsers INT
			,@NewlyRegisterUsers INT, @CompareNewlyRegisterUsers INT
			,@NewlyActiveRegisterUsers INT, @CompareNewlyActiveRegisterUsers INT
			,@ActiveUsers INT, @CompareActiveUsers INT
			,@DepositAmount MONEY, @CompareDepositAmount MONEY
			,@WithdrawalAmount MONEY, @CompareWithdrawalAmount MONEY
			,@BonusAmountClaimeds MONEY, @CompareBonusAmountClaimeds MONEY

	CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)

	SELECT @SiteId = SiteId
	FROM dbo.ServerInfo s WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
	WHERE l.LicenseeId = @LicenseeId

	-- Data on GMT+0 --> convert timezone
	SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
			,@CompareFromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
			,@CompareToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))
			,@FromLastXDaysGMT = CASE WHEN @FromLastXDays IS NULL THEN NULL ELSE DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromLastXDays)) END
		
	-- General Info
	BEGIN
		SELECT
			@TotalUsers = COUNT(CASE 
									WHEN @FromLastXDaysGMT IS NULL THEN 1
									WHEN c.RegTime >= @FromLastXDaysGMT THEN 1
									ELSE NULL
								END)
			,@TotalDepositUsers = COUNT
									(CASE 
											WHEN c.FirstDepositDate IS NOT NULL AND @FromLastXDaysGMT IS NULL THEN 1
											WHEN c.FirstDepositDate IS NOT NULL AND c.FirstDepositDate >= @FromLastXDaysGMT THEN 1
										ELSE NULL 
									END
									)
			,@UptoTotalUsers = COUNT(CASE 
											WHEN @FromLastXDaysGMT IS NULL AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 
											WHEN @FromLastXDaysGMT IS NOT NULL AND (c.RegTime >= @FromLastXDaysGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)) THEN 1 
											ELSE NULL 
										END)
			,@CompareUptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
			,@NewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
			,@CompareNewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE SiteId = @SiteId
			AND IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT @TotalActiveUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			AND EXISTS (
				SELECT 1 
				FROM dbo.N88_SumWinloss r WITH (NOLOCK) 
				WHERE 
					c.CustId = r.CustId
					AND 1 = CASE 
								WHEN @FromLastXDaysGMT IS NULL THEN 1
								WHEN r.TransTime >= @FromLastXDaysGMT THEN 1
								ELSE 0 END
			)
			AND (@FromLastXDaysGMT IS NULL OR c.RegTime >= @FromLastXDaysGMT)
	END

	-- Get data
	DECLARE @i TINYINT = 1, @tmpFDateGMT DATETIME, @tmpTDateGMT DATETIME

	CREATE TABLE #Bonus (CustId INT, CurrencyId INT, ExchangeDate DATE, BonusAmount MONEY)

	WHILE @i <= 2
	BEGIN
		IF @i = 1
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
				,@tmpFDateGMT = @FromDateTimeGMT, @tmpTDateGMT = DATEADD(DAY, 1, @ToDateTimeGMT)
		ELSE
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
				,@tmpFDateGMT = @CompareFromDateTimeGMT, @tmpTDateGMT = DATEADD(DAY, 1, @CompareToDateTimeGMT)
			
		DELETE #Exchange
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		SELECT @DepositUsers = CASE WHEN @i = 1 THEN DepositUsers ELSE @DepositUsers END
			,@CompareDepositUsers = CASE WHEN @i = 2 THEN DepositUsers ELSE @CompareDepositUsers END
		FROM (
			SELECT COUNT(1) AS DepositUsers
			FROM (
				SELECT d.CustId
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE d.SiteId = @SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3 -- Approved
					AND d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND d.CreateTime >= @tmpFDateGMT AND d.CreateTime < @tmpTDateGMT
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY d.CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0
		) t

		SELECT @ActiveUsers = CASE WHEN @i = 1 THEN ActiveUsers ELSE @ActiveUsers END
			,@CompareActiveUsers = CASE WHEN @i = 2 THEN ActiveUsers ELSE @CompareActiveUsers END
		FROM (
			SELECT COUNT(1) AS ActiveUsers
			FROM (
				SELECT CustId
				FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				WHERE TransTime >= @tmpFDateGMT AND TransTime < @tmpTDateGMT
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0
		) t

		SELECT @DepositAmount = CASE WHEN @i = 1 THEN DepositAmount ELSE @DepositAmount END
			,@CompareDepositAmount = CASE WHEN @i = 2 THEN DepositAmount ELSE @CompareDepositAmount END
		FROM (
			SELECT SUM(d.Amount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS DepositAmount
			FROM dbo.DepositInfo d WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND d.CreateTime >= @tmpFDateGMT AND d.CreateTime < @tmpTDateGMT
				AND d.SiteId = @SiteId
				AND d.Status = 3
				AND c.IsTest = 0
		) t

		SELECT @WithdrawalAmount = CASE WHEN @i = 1 THEN WithdrawalAmount ELSE @WithdrawalAmount END
			,@CompareWithdrawalAmount = CASE WHEN @i = 2 THEN WithdrawalAmount ELSE @CompareWithdrawalAmount END
		FROM (
			SELECT SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS WithdrawalAmount
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
				INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE w.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND w.CreateTime >= @tmpFDateGMT AND w.CreateTime < @tmpTDateGMT
				AND w.SiteId = @SiteId
				AND w.Status = 6
				AND c.IsTest = 0
		) t

		-- Bonus
		BEGIN
			TRUNCATE TABLE #Bonus

			-- BonusInfo
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(BonusAmount) AS BonusAmount
			FROM dbo.BonusInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
				AND SiteId = @SiteId
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

			-- RebateMLog
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(RedeemAmount) AS BonusAmount
			FROM dbo.RebateMLog WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
				AND SiteId = @SiteId
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

			-- DrawLog
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, DrawTime)) AS ExchangeDate, SUM(Amount) AS Amount
			FROM dbo.DrawLog WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND DrawTime >= @tmpFDateGMT AND DrawTime < @tmpTDateGMT
				AND SiteId = @SiteId
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, DrawTime))

			-- AdjustmentInfo
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(Amount * CASE
								WHEN AdjustType IN (1, 3) THEN 1 -- Credit, Increase bonus
								WHEN AdjustType IN (2, 4) THEN -1 -- Debit, Decrease bonus
								ELSE 0 END) AS Amount
			FROM dbo.AdjustmentInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
				AND SiteId = @SiteId
				AND Status = 2 -- Approved
				AND 1 = CASE WHEN CreateTime < '2021-10-31 16:00' OR AdjustType IN (3, 4) THEN 1 ELSE 0 END -- From 1 Nov 2021 (GMT+8), just get Increase & Decrease bonus
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

			-- LogAdminAdjustWallet
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(Amount * CASE
								WHEN Direction = 1 THEN 1 -- 3rd Add
								WHEN Direction = 2 THEN -1 -- 3rd Minus
								ELSE 0 END) AS Amount
			FROM dbo.LogAdminAdjustWallet WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
				AND SiteId = @SiteId
				AND Status = 0 -- Success
				AND CreateTime < '2021-10-31 16:00' -- only get data before 1 Nov 2021 (GMT+8)
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

			-- VIPUpgradeReview
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, SettleTime)) AS ExchangeDate, SUM(UpgradeAmount) AS Amount
			FROM dbo.VIPUpgradeReview WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND SettleTime >= @tmpFDateGMT AND SettleTime < @tmpTDateGMT
				AND SiteId = @SiteId
				AND Status = 4 -- Settled
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, SettleTime))

			-- CustVerificationReward
			INSERT INTO #Bonus (CustId, CurrencyId, ExchangeDate, BonusAmount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, RewardTime)) AS ExchangeDate, SUM(RewardAmount) AS Amount
			FROM dbo.CustVerificationRewardDetail WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND RewardTime >= @tmpFDateGMT AND RewardTime < @tmpTDateGMT
				AND SiteId = @SiteId
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, RewardTime))

			SELECT @BonusAmountClaimeds = CASE WHEN @i = 1 THEN BonusAmountClaimeds ELSE @BonusAmountClaimeds END
				,@CompareBonusAmountClaimeds = CASE WHEN @i = 2 THEN BonusAmountClaimeds ELSE @CompareBonusAmountClaimeds END
			FROM (
				SELECT SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmountClaimeds
				FROM #Bonus b
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
					INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
				WHERE c.IsTest = 0
			) t
		END
		
		-- Newly active registered users
		SELECT @NewlyActiveRegisterUsers = CASE WHEN @i = 1 THEN NewlyActiveRegisterUsers ELSE @NewlyActiveRegisterUsers END
			,@CompareNewlyActiveRegisterUsers = CASE WHEN @i = 2 THEN NewlyActiveRegisterUsers ELSE @CompareNewlyActiveRegisterUsers END
		FROM (
			SELECT COUNT(CASE WHEN RegTime >= @tmpFDateGMT AND RegTime < @tmpTDateGMT THEN 1 ELSE NULL END) AS NewlyActiveRegisterUsers
			FROM (
				SELECT CustId
				FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				WHERE TransTime >= @tmpFDateGMT AND TransTime < @tmpTDateGMT
					AND SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0
		) t

		SELECT @i = @i + 1
	END

	DROP TABLE #Bonus
	DROP TABLE #Exchange

	-- Return data
	SELECT @TotalUsers AS TotalUsers
			,@UptoTotalUsers AS UptoTotalUsers
			,@CompareUptoTotalUsers AS CompareUptoTotalUsers
			,@TotalDepositUsers AS TotalDepositUsers
			,@TotalActiveUsers AS TotalActiveUsers
			,@DepositUsers AS DepositUsers
			,@CompareDepositUsers AS CompareDepositUsers
			,@NewlyRegisterUsers AS NewlyRegisterUsers
			,@CompareNewlyRegisterUsers AS CompareNewlyRegisterUsers
			,@NewlyActiveRegisterUsers AS NewlyActiveRegisterUsers
			,@CompareNewlyActiveRegisterUsers AS CompareNewlyActiveRegisterUsers
			,@ActiveUsers AS ActiveUsers
			,@CompareActiveUsers AS CompareActiveUsers
			,@DepositAmount AS DepositAmount
			,@CompareDepositAmount AS CompareDepositAmount
			,@WithdrawalAmount AS WithdrawalAmount
			,@CompareWithdrawalAmount AS CompareWithdrawalAmount
			,@BonusAmountClaimeds AS BonusAmountClaimeds
			,@CompareBonusAmountClaimeds AS CompareBonusAmountClaimeds
END
GO