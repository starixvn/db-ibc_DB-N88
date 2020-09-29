/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Main_ExportExcel]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200915@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Main - Export Excel

	Revisions:
		- 20200915@Percy: Initialize SP [RedmineID: #141575]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT
	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME

	DECLARE @UptoTotalUsers			INT
			,@TotalUsers			INT
			,@UptoActiveUsers		INT
			,@TotalActiveUsers		INT
			,@UptoDepositUsers		INT
			,@TotalDepositUsers		INT
			,@NewlyRegisterUsers	INT
			,@TotalBonus			MONEY
			,@TotalDeposit			MONEY
			,@TotalFirstDeposit		MONEY
			,@TotalWithdrawal		MONEY
			,@TotalWithdrawalUsers	INT

	DECLARE @tempData TABLE (Name VARCHAR(100), DateRange MONEY, AllRange MONEY, DataType TINYINT)
	/*
		DataType
			1 = int
			2 = money
			3 = percent (%)
	*/

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')

		-- Active Users
		CREATE TABLE #ActiveUsers (CustId INT, IsAll BIT, IsRange BIT)
		INSERT INTO #ActiveUsers (CustId, IsAll, IsRange)
		SELECT CustId, 1, 1
		FROM (
			SELECT CustId
			FROM dbo.N88_RptWinloss WITH (NOLOCK)
			WHERE TransDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
				AND TransDateGMT BETWEEN @FromDate AND @ToDate
				AND TimeZone = @TimeZone
				AND LicenseeId = @LicenseeId
			GROUP BY CustId

			UNION ALL
			SELECT CustId
			FROM dbo.TpTransferInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
			GROUP BY CustId
		) t
		GROUP BY CustId

		INSERT INTO #ActiveUsers (CustId, IsAll, IsRange)
		SELECT CustId, 1, 0
		FROM (
			SELECT CustId
			FROM dbo.N88_RptWinloss WITH (NOLOCK)
			WHERE TransDate < DATEADD(DAY, -1, @FromDate)
				AND TransDateGMT < @FromDate
				AND TimeZone = @TimeZone
				AND LicenseeId = @LicenseeId
			GROUP BY CustId

			UNION ALL
			SELECT CustId
			FROM dbo.TpTransferInfo WITH (NOLOCK)
			WHERE WinlostDate < DATEADD(DAY, -1, @FromDate)
				AND CreateTime < @FromDateTimeGMT
				AND SiteId = @SiteId
			GROUP BY CustId
		) t
		WHERE NOT EXISTS (SELECT 1 FROM #ActiveUsers a WHERE t.CustId = a.CustId)
		GROUP BY CustId

		-- Deposit
		CREATE TABLE #DepositUsers (CustId INT, Deposit MONEY, FirstDeposit MONEY)
		INSERT INTO #DepositUsers (CustId, Deposit, FirstDeposit)
		SELECT d.CustId
			,SUM(d.Amount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS Deposit
			,SUM(CASE WHEN d.FirstDeposit = 1 THEN d.Amount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END ELSE 0 END) AS FirstDeposit
		FROM dbo.DepositInfo d WITH (NOLOCK)
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
				AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
		WHERE d.SiteId = @SiteId
			AND d.Status = 3 -- Approved
			AND d.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
			AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
		GROUP BY d.CustId

		-- Withdrawal
		CREATE TABLE #WithdrawalUsers (CustId INT, Withdrawal MONEY)
		INSERT INTO #WithdrawalUsers (CustId, Withdrawal)
		SELECT w.CustId, SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS Withdrawal
		FROM dbo.WithdrawalInfo w WITH (NOLOCK)
			INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId
				AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
		WHERE w.SiteId = @SiteId
			AND w.Status = 6 -- Approved
			AND w.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
			AND w.CreateTime >= @FromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
		GROUP BY w.CustId

		SELECT @TotalBonus = SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
		FROM dbo.BonusInfo b WITH (NOLOCK)
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
				AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND b.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
			AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)

		-- Main data
		SELECT @UptoTotalUsers			= COUNT(1)
				,@TotalUsers			= COUNT(CASE WHEN c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
				,@UptoActiveUsers		= SUM(ISNULL(CONVERT(INT, a.IsAll), 0))
				,@TotalActiveUsers		= SUM(ISNULL(CONVERT(INT, a.IsRange), 0))
				,@UptoDepositUsers		= COUNT(CASE WHEN c.ActStatus = 2 THEN 1 ELSE NULL END)
				,@TotalDepositUsers		= COUNT(CASE WHEN d.FirstDeposit = 0 THEN NULL ELSE d.CustId END)
				,@NewlyRegisterUsers	= COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
				,@TotalDeposit			= SUM(ISNULL(d.Deposit, 0))
				,@TotalFirstDeposit		= SUM(ISNULL(d.FirstDeposit, 0))
				,@TotalWithdrawal		= SUM(ISNULL(w.Withdrawal, 0))
				,@TotalWithdrawalUsers	= COUNT(w.CustId)
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN #ActiveUsers a ON c.CustId = a.CustId
			LEFT JOIN #DepositUsers d ON c.CustId = d.CustId
			LEFT JOIN #WithdrawalUsers w ON c.CustId = w.CustId
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0

		SELECT @UptoDepositUsers = @UptoDepositUsers - COUNT(CASE WHEN c.ActStatus = 2 THEN 1 ELSE NULL END) + COUNT(d.CustId)
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN dbo.DepositInfo d WITH (NOLOCK) ON c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
		WHERE c.RegTime < '2020-08-15'
			AND c.SiteId = @SiteId
			AND c.IsTest = 0

		DROP TABLE #ActiveUsers
		DROP TABLE #DepositUsers
		DROP TABLE #Exchange
		DROP TABLE #WithdrawalUsers

		INSERT INTO @tempData (Name, DateRange, AllRange, DataType)
		VALUES
			('Total Users', @TotalUsers, @UptoTotalUsers, 1)
			,('Active Users', @TotalActiveUsers, @UptoActiveUsers, 1)
			,('PU (APA) - Deposit Users', @TotalDepositUsers, @UptoDepositUsers, 1)
			,('NRU - Newly Registered Users', @NewlyRegisterUsers, NULL, 1)

		-- Bonus Info
		INSERT INTO @tempData (Name, DateRange, DataType)
		SELECT 'No. of users claiming ' + b.BonusCode, COUNT(1) AS TotalUsers, 1
		FROM dbo.BonusInfo b WITH (NOLOCK)
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND b.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
			AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
		GROUP BY b.BonusCode

		DECLARE @CR FLOAT, @RR FLOAT
		SELECT  @CR = CASE WHEN @TotalUsers = 0 THEN 0 ELSE (@TotalUsers - @TotalActiveUsers) * 1.0 / @TotalUsers * 100 END
		SELECT  @RR = 100.0 - @CR

		SELECT  @CR = ROUND(@CR, 0), @RR = ROUND(@RR, 0)

		INSERT INTO @tempData (Name, DateRange, DataType)
		VALUES
			('Total bonus amount claimed', @TotalBonus, 2)
			,('Total Deposit Amount', @TotalDeposit, 2)
			,('Total First Deposit', @TotalFirstDeposit, 2)
			,('Total Withdrawal Amount', @TotalWithdrawal, 2)
			,('Total Withdrawal Users', @TotalWithdrawalUsers, 1)
			,('CR - Churn Rate', @CR, 3)
			,('RR - Retention Rate', @RR, 3)

		-- Signup url
		DECLARE @DefaultSignupUrl VARCHAR(200)
		SELECT  @DefaultSignupUrl = CASE @SiteId
										WHEN 3 THEN 'www.bwing.com'
										END

		INSERT INTO @tempData (Name)
		VALUES (NULL), ('Registration Details')

		INSERT INTO @tempData (Name, DateRange, DataType)
		SELECT SignupUrl, TotalUsers, 1
		FROM
		(
			SELECT CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END AS SignupUrl, COUNT(1) AS TotalUsers
			FROM dbo.Customer c WITH (NOLOCK)
				LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON cg.CustId = c.CustId
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
				AND c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			GROUP BY CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END
		) t
		WHERE SignupUrl IS NOT NULL
	END

	SELECT Name, DateRange, AllRange, DataType FROM @tempData
END
GO