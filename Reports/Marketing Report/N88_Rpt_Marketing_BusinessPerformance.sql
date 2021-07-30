/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
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
											WHEN ActStatus = 2 AND @FromLastXDaysGMT IS NULL THEN 1
											WHEN ActStatus = 2 AND c.RegTime >= @FromLastXDaysGMT THEN 1
											ELSE NULL 
										END
										)
				,@UptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
				,@CompareUptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
				,@NewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
				,@CompareNewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
			FROM dbo.Customer c WITH (NOLOCK)
			WHERE SiteId = @SiteId
				AND IsTest = 0
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

			SELECT @TotalDepositUsers = @TotalDepositUsers - COUNT
										(CASE 
											WHEN ActStatus = 2 AND @FromLastXDaysGMT IS NULL THEN 1
											WHEN ActStatus = 2 AND c.RegTime >= @FromLastXDaysGMT THEN 1
											ELSE NULL 
										END) + COUNT(d.CustId)
			FROM dbo.Customer c WITH (NOLOCK)
				LEFT JOIN dbo.DepositInfo d WITH (NOLOCK) ON c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
			WHERE c.RegTime < '2020-08-15'
				AND c.SiteId = @SiteId
				AND c.IsTest = 0
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

			SELECT @TotalActiveUsers = COUNT(1)
			FROM dbo.Customer c WITH (NOLOCK)
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				AND (
						EXISTS 
						(
							SELECT 1 
							FROM dbo.N88_SumWinloss r WITH (NOLOCK) 
							WHERE 
								c.CustId = r.CustId
								AND r.SiteId = @SiteId
								AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
								AND 1 = CASE 
										WHEN @FromLastXDaysGMT IS NULL THEN 1
										WHEN r.TransTime >= @FromLastXDaysGMT THEN 1
									END
						)
						OR 
						EXISTS 
						(
							SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK) 
							WHERE 
								c.CustId = t.CustId
								AND t.SiteId = @SiteId
								AND 1 = CASE 
											WHEN @FromLastXDaysGMT IS NULL THEN 1
											WHEN t.CreateTime >= @FromLastXDaysGMT THEN 1
										END
						)
				)

		END

		-- Get data
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
		
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

			SELECT @DepositUsers = COUNT(1)
			FROM (
				SELECT d.CustId
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE d.SiteId = @SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3 -- Approved
					AND d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY d.CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

			SELECT @ActiveUsers = COUNT(1)
			FROM (
				SELECT CustId
				FROM (
					SELECT CustId
					FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE TransTime >= @FromDateTimeGMT AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
					GROUP BY CustId

					UNION ALL
					SELECT t.CustId
					FROM dbo.TpTransferInfo t WITH (NOLOCK)
						INNER JOIN dbo.Customer c WITH(NOLOCK)
							ON t.CustId = c.CustId
					WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND t.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
					GROUP BY t.CustId
				) AS t
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

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

			SELECT @WithdrawalAmount = SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
				INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE w.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND w.CreateTime >= @FromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND w.SiteId = @SiteId
				AND w.Status = 6
				AND c.IsTest = 0

			SELECT @BonusAmountClaimeds = SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND c.IsTest = 0

			SELECT @BonusAmountClaimeds = ISNULL(@BonusAmountClaimeds, 0) + ISNULL(SUM(r.RedeemAmount * e.Rate / CASE WHEN r.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END), 0)
			FROM dbo.RebateMLog r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND r.SiteId = @SiteId
				AND c.IsTest = 0

			--newly active registered users
			SELECT @NewlyActiveRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
			FROM (
				SELECT CustId
				FROM (
					SELECT CustId
					FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE TransTime >= @FromDateTimeGMT AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
					GROUP BY CustId

					UNION ALL
					SELECT t.CustId
					FROM dbo.TpTransferInfo t WITH (NOLOCK)
						INNER JOIN dbo.Customer c WITH(NOLOCK)
							ON t.CustId = c.CustId
					WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND t.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
					GROUP BY t.CustId
				) AS t
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

		END

		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
		
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
			
			SELECT @CompareDepositUsers = COUNT(1)
			FROM (
				SELECT d.CustId
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE d.SiteId = @SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3 -- Approved
					AND d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND d.CreateTime >= @CompareFromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY d.CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

			SELECT @CompareActiveUsers = COUNT(1)
			FROM (
				SELECT CustId
				FROM (
					SELECT CustId
					FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE TransTime >= @CompareFromDateTimeGMT AND r.TransTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
						AND SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
					GROUP BY CustId

					UNION ALL
					SELECT t.CustId
					FROM dbo.TpTransferInfo t WITH (NOLOCK)
						INNER JOIN dbo.Customer c WITH(NOLOCK)
							ON t.CustId = c.CustId
					WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CreateTime >= @CompareFromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
						AND t.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
					GROUP BY t.CustId
				) AS t
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

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

			SELECT @CompareWithdrawalAmount = SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
				INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE w.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND w.CreateTime >= @CompareFromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				AND w.SiteId = @SiteId
				AND w.Status = 6
				AND c.IsTest = 0

			SELECT @CompareBonusAmountClaimeds = SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND b.CreateTime >= @CompareFromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND c.IsTest = 0

			SELECT @CompareBonusAmountClaimeds = ISNULL(@CompareBonusAmountClaimeds, 0) + ISNULL(SUM(r.RedeemAmount * e.Rate / CASE WHEN r.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END), 0)
			FROM dbo.RebateMLog r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND r.CreateTime >= @CompareFromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				AND r.SiteId = @SiteId
				AND c.IsTest = 0

			--compare newly active registered users
			SELECT @CompareNewlyActiveRegisterUsers = COUNT(CASE WHEN RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
			FROM (
				SELECT CustId
				FROM (
					SELECT CustId
					FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE TransTime >= @CompareFromDateTimeGMT AND r.TransTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
						AND SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
					GROUP BY CustId

					UNION ALL
					SELECT t.CustId
					FROM dbo.TpTransferInfo t WITH (NOLOCK)
						INNER JOIN dbo.Customer c WITH(NOLOCK)
							ON t.CustId = c.CustId
					WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CreateTime >= @CompareFromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
						AND t.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
					GROUP BY t.CustId
				) AS t
				GROUP BY CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

		END
	END

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