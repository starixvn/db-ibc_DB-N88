/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BusinessPerformance]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
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
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @TotalUsers INT
			,@TotalDepositUsers INT
			,@TotalActiveUsers INT
			,@DepositUsers INT, @CompareDepositUsers INT
			,@UptoTotalUsers INT, @CompareUptoTotalUsers INT
			,@NewlyRegisterUsers INT, @CompareNewlyRegisterUsers INT
			,@ActiveUsers INT, @CompareActiveUsers INT
			,@DepositAmount MONEY, @CompareDepositAmount MONEY
			,@WithdrawalAmount MONEY, @CompareWithdrawalAmount MONEY
			,@BonusClaimeds INT, @CompareBonusClaimeds INT

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
		
		-- General Info
		BEGIN
			SELECT
				@TotalUsers = COUNT(1)
				,@TotalDepositUsers = COUNT(CASE WHEN ActStatus = 2 THEN 1 ELSE NULL END)
				,@UptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
				,@CompareUptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
				,@NewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
				,@CompareNewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
			FROM dbo.Customer WITH (NOLOCK)
			WHERE SiteId = @SiteId
				AND IsTest = 0

			SELECT @TotalDepositUsers = @TotalDepositUsers - COUNT(CASE WHEN c.ActStatus = 2 THEN 1 ELSE NULL END) + COUNT(d.CustId)
			FROM dbo.Customer c WITH (NOLOCK)
				LEFT JOIN dbo.DepositInfo d WITH (NOLOCK) ON c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
			WHERE c.RegTime < '2020-08-15'
				AND c.SiteId = @SiteId
				AND c.IsTest = 0

			SELECT @TotalActiveUsers = COUNT(1)
			FROM dbo.Customer c WITH (NOLOCK)
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
				AND (
					EXISTS (SELECT 1 FROM dbo.N88_RptWinloss r WITH (NOLOCK) WHERE c.CustId = r.CustId)
					OR EXISTS (SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK) WHERE c.CustId = t.CustId)
				)
		END

		-- Get data
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
		
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')

			SELECT @DepositUsers = COUNT(1)
			FROM (
				SELECT d.CustId
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE d.SiteId = @SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3 -- Approved
					AND d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				GROUP BY d.CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

			SELECT @ActiveUsers = COUNT(1)
			FROM (
				SELECT CustId
				FROM (
					SELECT CustId
					FROM dbo.N88_RptWinloss WITH (NOLOCK)
					WHERE TransDate BETWEEN @tmpFromDate AND @tmpToDate
						AND TransDateGMT BETWEEN @FromDate AND @ToDate
						AND TimeZone = @TimeZone
						AND LicenseeId = @LicenseeId
					GROUP BY CustId

					UNION ALL
					SELECT CustId
					FROM dbo.TpTransferInfo WITH (NOLOCK)
					WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND SiteId = @SiteId
					GROUP BY CustId
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

			SELECT @BonusClaimeds = COUNT(1)
			FROM (
				SELECT b.BonusCode, b.CustId
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
				GROUP BY b.BonusCode, b.CustId
			) b
		END

		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
		
			DELETE #Exchange
			INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
			SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '')
			
			SELECT @CompareDepositUsers = COUNT(1)
			FROM (
				SELECT d.CustId
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE d.SiteId = @SiteId
					AND d.FirstDeposit = 1
					AND d.Status = 3 -- Approved
					AND d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND d.CreateTime >= @CompareFromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				GROUP BY d.CustId
			) AS a
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
			WHERE c.IsTest = 0

			SELECT @CompareActiveUsers = COUNT(1)
			FROM (
				SELECT CustId
				FROM (
					SELECT CustId
					FROM dbo.N88_RptWinloss WITH (NOLOCK)
					WHERE TransDate BETWEEN @tmpFromDate AND @tmpToDate
						AND TransDateGMT BETWEEN @CompareFromDate AND @CompareToDate
						AND TimeZone = @TimeZone
						AND LicenseeId = @LicenseeId
					GROUP BY CustId

					UNION ALL
					SELECT CustId
					FROM dbo.TpTransferInfo WITH (NOLOCK)
					WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
						AND CreateTime >= @CompareFromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
						AND SiteId = @SiteId
					GROUP BY CustId
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

			SELECT @CompareBonusClaimeds = COUNT(1)
			FROM (
				SELECT b.BonusCode, b.CustId
				FROM dbo.BonusInfo b WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
				WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND b.CreateTime >= @CompareFromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND b.SiteId = @SiteId
					AND c.IsTest = 0
				GROUP BY b.BonusCode, b.CustId
			) b
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
			,@ActiveUsers AS ActiveUsers
			,@CompareActiveUsers AS CompareActiveUsers
			,@DepositAmount AS DepositAmount
			,@CompareDepositAmount AS CompareDepositAmount
			,@WithdrawalAmount AS WithdrawalAmount
			,@CompareWithdrawalAmount AS CompareWithdrawalAmount
			,@BonusClaimeds AS BonusClaimeds
			,@CompareBonusClaimeds AS CompareBonusClaimeds
END
GO