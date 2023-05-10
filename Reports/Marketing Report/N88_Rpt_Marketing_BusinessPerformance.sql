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
		- 20220412@Percy: Integrate new bonus: Referral & Rebuild Bonus Structure [RedmineID: 171245]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230406@Malcolm: Using Actual Deposit instead of Amount for Deposit Info [RedmineId: #186439]

	Param explaination:
		- @FromLastXDays:
			+ NULL: no limit
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @FDate DATE, @TDate DATE, @B_FDate DATE, @A_TDate DATE, @TpCurrencyIds VARCHAR(MAX)

	DECLARE @FromDateTimeGMT0 DATETIME, @ToDateTimeGMT0 DATETIME
			,@CompareFromDateTimeGMT0 DATETIME, @CompareToDateTimeGMT0 DATETIME
			,@FromLastXDaysGMT0 DATETIME

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

	CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT)

	SELECT @SiteId = SiteId
	FROM dbo.ServerInfo s WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
	WHERE l.LicenseeId = @LicenseeId

	-- Data on GMT+0 --> convert timezone
	SELECT  @FromDateTimeGMT0 = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT0 = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
			,@CompareFromDateTimeGMT0 = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
			,@CompareToDateTimeGMT0 = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))
			,@FromLastXDaysGMT0 = CASE WHEN @FromLastXDays IS NULL THEN NULL ELSE DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromLastXDays)) END
		
	-- General Info
	BEGIN
		SELECT @TpCurrencyIds = 
		(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(Tp.TpExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TpExchange Tp WITH(NOLOCK) ON Tp.ExchangeId = t.value
		)
		
		SELECT
			@TotalUsers = COUNT(CASE 
									WHEN @FromLastXDaysGMT0 IS NULL THEN 1
									WHEN c.RegTime >= @FromLastXDaysGMT0 THEN 1
									ELSE NULL
								END)
			,@TotalDepositUsers = COUNT
									(CASE 
											WHEN c.FirstDepositDate IS NOT NULL AND @FromLastXDaysGMT0 IS NULL THEN 1
											WHEN c.FirstDepositDate IS NOT NULL AND c.FirstDepositDate >= @FromLastXDaysGMT0 THEN 1
										ELSE NULL 
									END
									)
			,@UptoTotalUsers = COUNT(CASE 
											WHEN @FromLastXDaysGMT0 IS NULL AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT0) THEN 1 
											WHEN @FromLastXDaysGMT0 IS NOT NULL AND (c.RegTime >= @FromLastXDaysGMT0 AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT0)) THEN 1 
											ELSE NULL 
										END)
			,@CompareUptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT0) THEN 1 ELSE NULL END)
			,@NewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT0 AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT0) THEN 1 ELSE NULL END)
			,@CompareNewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @CompareFromDateTimeGMT0 AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT0) THEN 1 ELSE NULL END)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE SiteId = @SiteId
			AND IsTest = 0
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT @TotalActiveUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			AND EXISTS (
				SELECT 1 
				FROM dbo.N88_SumWinloss r WITH (NOLOCK) 
				WHERE 
					c.CustId = r.CustId
					AND 1 = CASE 
								WHEN @FromLastXDaysGMT0 IS NULL THEN 1
								WHEN r.TransTime >= @FromLastXDaysGMT0 THEN 1
								ELSE 0 END
			)
			AND (@FromLastXDaysGMT0 IS NULL OR c.RegTime >= @FromLastXDaysGMT0)
	END

	-- Get data
	DECLARE @i TINYINT = 1, @tmpFDateGMT0 DATETIME, @tmpTDateGMT0 DATETIME
	CREATE TABLE #tmpBonus (BonusDate DATE, DataSource VARCHAR(128), BonusType SMALLINT, BonusCode VARCHAR(100), BonusName VARCHAR(300), BonusStatus TINYINT, CustId INT, CurrencyId INT, BetCount INT, BonusAmount MONEY, BasedBonusAmount MONEY)

	WHILE @i <= 2
	BEGIN
		IF @i = 1 -- Date range
			SELECT @FDate = @FromDate, @TDate = @ToDate
				,@B_FDate = DATEADD(DAY, -1, @FromDate), @A_TDate = DATEADD(DAY, 1, @ToDate)
				,@tmpFDateGMT0 = @FromDateTimeGMT0, @tmpTDateGMT0 = DATEADD(DAY, 1, @ToDateTimeGMT0)
		ELSE -- Compare date range
			SELECT @FDate = @CompareFromDate, @TDate = @CompareToDate
				,@B_FDate = DATEADD(DAY, -1, @CompareFromDate), @A_TDate = DATEADD(DAY, 1, @CompareToDate)
				,@tmpFDateGMT0 = @CompareFromDateTimeGMT0, @tmpTDateGMT0 = DATEADD(DAY, 1, @CompareToDateTimeGMT0)

		DELETE #TpExchange
		INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate)
		SELECT FromDate, ToDate, ISNULL(Tp.TpExchangeID, e.ExchangeId), Rate 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@B_FDate, @A_TDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange Tp WITH(NOLOCK) ON Tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		-- Deposit Users
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
					AND d.WinlostDate BETWEEN @B_FDate AND @A_TDate
					AND d.CreateTime >= @tmpFDateGMT0 AND d.CreateTime < @tmpTDateGMT0
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY d.CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0
		) t

		-- Active Users
		SELECT @ActiveUsers = CASE WHEN @i = 1 THEN ActiveUsers ELSE @ActiveUsers END
			,@CompareActiveUsers = CASE WHEN @i = 2 THEN ActiveUsers ELSE @CompareActiveUsers END
		FROM (
			SELECT COUNT(1) AS ActiveUsers
			FROM (
				SELECT CustId
				FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				WHERE TransTime >= @tmpFDateGMT0 AND TransTime < @tmpTDateGMT0
					AND SiteId = @SiteId
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0
		) t

		-- Deposit Amount
		SELECT @DepositAmount = CASE WHEN @i = 1 THEN DepositAmount ELSE @DepositAmount END
			,@CompareDepositAmount = CASE WHEN @i = 2 THEN DepositAmount ELSE @CompareDepositAmount END
		FROM (
			SELECT SUM(d.ActualDeposit * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS DepositAmount
			FROM dbo.DepositInfo d WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
				INNER JOIN #TpExchange e ON d.CurrencyId = e.TpExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE d.WinlostDate BETWEEN @B_FDate AND @A_TDate
				AND d.CreateTime >= @tmpFDateGMT0 AND d.CreateTime < @tmpTDateGMT0
				AND d.SiteId = @SiteId
				AND d.Status = 3
				AND c.IsTest = 0
		) t

		-- Withdrawal Amount
		SELECT @WithdrawalAmount = CASE WHEN @i = 1 THEN WithdrawalAmount ELSE @WithdrawalAmount END
			,@CompareWithdrawalAmount = CASE WHEN @i = 2 THEN WithdrawalAmount ELSE @CompareWithdrawalAmount END
		FROM (
			SELECT SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS WithdrawalAmount
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
				INNER JOIN #TpExchange e ON w.CurrencyId = e.TpExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE w.WinlostDate BETWEEN @B_FDate AND @A_TDate
				AND w.CreateTime >= @tmpFDateGMT0 AND w.CreateTime < @tmpTDateGMT0
				AND w.SiteId = @SiteId
				AND w.Status = 6
				AND c.IsTest = 0
		) t

		-- Bonus Amount
		TRUNCATE TABLE #tmpBonus
		
		INSERT INTO #tmpBonus (BonusDate, DataSource, BonusType, BonusCode, BonusName, BonusStatus, CustId, CurrencyId, BetCount, BonusAmount, BasedBonusAmount)
		EXEC dbo.N88_CustBonusSummary_Sel
			@SiteId = @SiteId
			,@FromDate = @FDate
			,@ToDate = @TDate
			,@CurrencyIds = @CurrencyIds
			,@DisplayCurrency = @DisplayCurrency
			,@TimeZone = @TimeZone

		SELECT @BonusAmountClaimeds = CASE WHEN @i = 1 THEN SUM(BasedBonusAmount) ELSE @BonusAmountClaimeds END
			,@CompareBonusAmountClaimeds = CASE WHEN @i = 2 THEN SUM(BasedBonusAmount) ELSE @CompareBonusAmountClaimeds END
		FROM #tmpBonus
		
		-- Newly active registered users
		SELECT @NewlyActiveRegisterUsers = CASE WHEN @i = 1 THEN NewlyActiveRegisterUsers ELSE @NewlyActiveRegisterUsers END
			,@CompareNewlyActiveRegisterUsers = CASE WHEN @i = 2 THEN NewlyActiveRegisterUsers ELSE @CompareNewlyActiveRegisterUsers END
		FROM (
			SELECT COUNT(CASE WHEN RegTime >= @tmpFDateGMT0 AND RegTime < @tmpTDateGMT0 THEN 1 ELSE NULL END) AS NewlyActiveRegisterUsers
			FROM (
				SELECT CustId
				FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				WHERE TransTime >= @tmpFDateGMT0 AND TransTime < @tmpTDateGMT0
					AND SiteId = @SiteId
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0
		) t

		SELECT @i = @i + 1
	END

	DROP TABLE #TpExchange

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