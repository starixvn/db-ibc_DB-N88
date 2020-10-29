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
		- 20200928@Percy: Change way to calculate active users [RedmineID: #141575]
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @SiteId INT
	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @BeginCurrentMonth DATETIME, @EndCurrentMonth DATETIME, @BeginCurrentMonthGMT DATETIME, @EndCurrentMonthGMT DATETIME
	DECLARE @OfficialLaunchDate DATETIME

	DECLARE @NoOfUsers						INT
			,@MTD_NoOfUsers					INT
			,@NewlyRegisterUsers			INT
			,@MTD_NewlyRegisterUsers		INT
			,@ActiveUsers					INT
			,@MTD_ActiveUsers				INT

			,@BonusClaimedAmount			MONEY
			,@MTD_BonusClaimedAmount		MONEY
			,@Total_BonusClaimedAmount		MONEY

			,@NoOfDepositUsers				INT
			,@MTD_NoOfDepositUsers			INT
			,@Total_NoOfDepositUsers		INT
			,@DepositAmount					MONEY
			,@MTD_DepositAmount				MONEY
			,@Total_DepositAmount			MONEY

			,@NoOfFirstDepositUsers			INT
			,@MTD_NoOfFirstDepositUsers		INT
			,@Total_NoOfFirstDepositUsers	INT
			,@FirstDepositAmount			MONEY
			,@MTD_FirstDepositAmount		MONEY
			,@Total_FirstDepositAmount		MONEY

			,@NoOfWithdrawalUsers			INT
			,@MTD_NoOfWithdrawalUsers		INT
			,@Total_NoOfWithdrawalUsers		INT
			,@WithdrawalAmount				MONEY
			,@MTD_WithdrawalAmount			MONEY
			,@Total_WithdrawalAmount		MONEY

	DECLARE @tempData TABLE (Name NVARCHAR(200), NameVN NVARCHAR(200), DateRange MONEY, MonthToDate MONEY, AllRange MONEY, DataType TINYINT)
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
		
		SELECT @OfficialLaunchDate = CASE @SiteId
										WHEN 2 THEN '2020-09-12' -- N8G
										WHEN 3 THEN '2020-08-14' -- N8B
										ELSE '1970-01-01' -- Get all
										END

		SELECT @BeginCurrentMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
		SELECT @EndCurrentMonth = DATEADD(DAY, -1, DATEADD(MONTH, 1, @BeginCurrentMonth))

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT			= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
				,@BeginCurrentMonthGMT	= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @BeginCurrentMonth))
				,@EndCurrentMonthGMT	= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @EndCurrentMonth))

		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId TINYINT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')

		-- Active Users
		SELECT @ActiveUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND (
				EXISTS (
					SELECT 1 FROM dbo.N88_RptWinloss r WITH (NOLOCK)
					WHERE c.CustId = r.CustId
						AND r.TransDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
						AND r.TransDateGMT BETWEEN @FromDate AND @ToDate
						AND r.TimeZone = @TimeZone
						AND r.LicenseeId = @LicenseeId
				)
				OR EXISTS (
					SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK)
					WHERE c.CustId = t.CustId
						AND t.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
						AND t.CreateTime >= @FromDateTimeGMT AND t.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND t.SiteId = @SiteId
				)
			)

		SELECT @MTD_ActiveUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND (
				EXISTS (
					SELECT 1 FROM dbo.N88_RptWinloss r WITH (NOLOCK)
					WHERE c.CustId = r.CustId
						AND r.TransDate BETWEEN DATEADD(DAY, -1, @BeginCurrentMonth) AND DATEADD(DAY, 1, @EndCurrentMonth)
						AND r.TransDateGMT BETWEEN @BeginCurrentMonthGMT AND @EndCurrentMonthGMT
						AND r.TimeZone = @TimeZone
						AND r.LicenseeId = @LicenseeId
				)
				OR EXISTS (
					SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK)
					WHERE c.CustId = t.CustId
						AND t.WinlostDate BETWEEN DATEADD(DAY, -1, @BeginCurrentMonth) AND DATEADD(DAY, 1, @EndCurrentMonth)
						AND t.CreateTime >= @BeginCurrentMonthGMT AND t.CreateTime < DATEADD(DAY, 1, @EndCurrentMonthGMT)
						AND t.SiteId = @SiteId
				)
			)

		-- Deposit
		CREATE TABLE #DepositUsers (CustId INT, Deposit MONEY, FirstDeposit MONEY, IsDateRange TINYINT, IsMTD TINYINT)
		INSERT INTO #DepositUsers (CustId, Deposit, FirstDeposit, IsDateRange, IsMTD)
		SELECT
			d.CustId
			,SUM(d.Deposit * e.Rate)
			,SUM(d.FirstDeposit * e.Rate)
			,CASE WHEN d.WinlostDate BETWEEN @FromDate AND @ToDate THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate BETWEEN @BeginCurrentMonth AND @EndCurrentMonth THEN 1 ELSE 0 END
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) AS ExchangeDate
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, d.CreateTime)) AS WinlostDate
				,d.CustId
				,d.CurrencyId
				,SUM(CASE WHEN d.FirstDeposit = 1 THEN d.Amount ELSE 0 END) AS FirstDeposit
				,SUM(d.Amount) AS Deposit
			FROM dbo.DepositInfo d WITH (NOLOCK)
			WHERE d.SiteId = @SiteId
				AND d.Status = 3 -- Approved
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime))
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, d.CreateTime))
				,d.CustId
				,d.CurrencyId
		) d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY
			d.CustId
			,CASE WHEN d.WinlostDate BETWEEN @FromDate AND @ToDate THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate BETWEEN @BeginCurrentMonth AND @EndCurrentMonth THEN 1 ELSE 0 END

		-- Withdrawal
		CREATE TABLE #WithdrawalUsers (CustId INT, Withdrawal MONEY, IsDateRange TINYINT, IsMTD TINYINT)
		INSERT INTO #WithdrawalUsers (CustId, Withdrawal, IsDateRange, IsMTD)
		SELECT
			d.CustId
			,SUM(d.Withdrawal * e.Rate)
			,CASE WHEN d.WinlostDate BETWEEN @FromDate AND @ToDate THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate BETWEEN @BeginCurrentMonth AND @EndCurrentMonth THEN 1 ELSE 0 END
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) AS ExchangeDate
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, w.CreateTime)) AS WinlostDate
				,w.CustId
				,w.CurrencyId
				,SUM(w.Amount) AS Withdrawal
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
			WHERE w.SiteId = @SiteId
				AND w.Status = 6 -- Approved
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime))
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, w.CreateTime))
				,w.CustId
				,w.CurrencyId
		) d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY
			d.CustId
			,CASE WHEN d.WinlostDate BETWEEN @FromDate AND @ToDate THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate BETWEEN @BeginCurrentMonth AND @EndCurrentMonth THEN 1 ELSE 0 END

		-- Bonus
		CREATE TABLE #BonusUsers (CustId INT, BonusCode VARCHAR(20), BonusClaimed MONEY, IsDateRange TINYINT, IsMTD TINYINT)
			-- Date range
			INSERT INTO #BonusUsers (CustId, BonusCode, BonusClaimed, IsDateRange, IsMTD)
			SELECT b.CustId, b.BonusCode
				,SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
				,1 AS IsDateRange
				,0 AS IsMTD
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE b.SiteId = @SiteId
				AND b.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			GROUP BY b.CustId, b.BonusCode

			-- Month to date
			INSERT INTO #BonusUsers (CustId, BonusCode, BonusClaimed, IsDateRange, IsMTD)
			SELECT b.CustId, b.BonusCode
				,SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
				,0 AS IsDateRange
				,1 AS IsMTD
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE b.SiteId = @SiteId
				AND b.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			GROUP BY b.CustId, b.BonusCode

		-- Main data
		SELECT
			@NoOfUsers						= COUNT(CASE WHEN c.RegTime > @OfficialLaunchDate		AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)			THEN 1 ELSE NULL END)
			,@MTD_NoOfUsers					= COUNT(CASE WHEN c.RegTime > @BeginCurrentMonthGMT		AND c.RegTime < DATEADD(DAY, 1, @EndCurrentMonthGMT)	THEN 1 ELSE NULL END)
			,@NewlyRegisterUsers			= COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT			AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)			THEN 1 ELSE NULL END)
			,@MTD_NewlyRegisterUsers		= COUNT(CASE WHEN c.RegTime >= @BeginCurrentMonthGMT	AND c.RegTime < DATEADD(DAY, 1, @EndCurrentMonthGMT)	THEN 1 ELSE NULL END)
			,@BonusClaimedAmount			= SUM(ISNULL(b.BonusClaimed, 0))
			,@MTD_BonusClaimedAmount		= SUM(ISNULL(b.MTD_BonusClaimed, 0))
			,@NoOfDepositUsers				= SUM(ISNULL(d.DepositUsers, 0))
			,@MTD_NoOfDepositUsers			= SUM(ISNULL(d.MTD_DepositUsers, 0))
			,@Total_NoOfDepositUsers		= SUM(ISNULL(d.Total_NoOfDepositUsers, 0))
			,@DepositAmount					= SUM(ISNULL(d.DepositAmount, 0))
			,@MTD_DepositAmount				= SUM(ISNULL(d.MTD_DepositAmount, 0))
			,@Total_DepositAmount			= SUM(ISNULL(d.Total_DepositAmount, 0))
			,@NoOfFirstDepositUsers			= SUM(ISNULL(d.FirstDepositUsers, 0))
			,@MTD_NoOfFirstDepositUsers		= SUM(ISNULL(d.MTD_FirstDepositUsers, 0))
			,@Total_NoOfFirstDepositUsers	= SUM(ISNULL(d.Total_FirstDepositUsers, 0))
			,@FirstDepositAmount			= SUM(ISNULL(d.FirstDepositAmount, 0))
			,@MTD_FirstDepositAmount		= SUM(ISNULL(d.MTD_FirstDepositAmount, 0))
			,@Total_FirstDepositAmount		= SUM(ISNULL(d.Total_FirstDepositAmount, 0))
			,@NoOfWithdrawalUsers			= SUM(ISNULL(w.WithdrawalUsers, 0))
			,@MTD_NoOfWithdrawalUsers		= SUM(ISNULL(w.MTD_WithdrawalUsers, 0))
			,@Total_NoOfWithdrawalUsers		= SUM(ISNULL(w.Total_WithdrawalUsers, 0))
			,@WithdrawalAmount				= SUM(ISNULL(w.WithdrawalAmount, 0))
			,@MTD_WithdrawalAmount			= SUM(ISNULL(w.MTD_WithdrawalAmount, 0))
			,@Total_WithdrawalAmount		= SUM(ISNULL(w.Total_WithdrawalAmount, 0))
		FROM dbo.Customer c WITH (NOLOCK)
			OUTER APPLY (
				SELECT
					 SUM(b.IsDateRange) AS BonusUsers
					,SUM(b.IsMTD)		AS MTD_BonusUsers
					,SUM(b.BonusClaimed * b.IsDateRange)	AS BonusClaimed
					,SUM(b.BonusClaimed * b.IsMTD)			AS MTD_BonusClaimed
				FROM #BonusUsers b
				WHERE b.CustId = c.CustId
			) b
			OUTER APPLY (
				SELECT
					 SUM(d.IsDateRange) AS DepositUsers
					,SUM(d.IsMTD)		AS MTD_DepositUsers
					,SUM(1)				AS Total_NoOfDepositUsers
					,SUM(d.Deposit * d.IsDateRange) AS DepositAmount
					,SUM(d.Deposit * d.IsMTD)		AS MTD_DepositAmount
					,SUM(d.Deposit)					AS Total_DepositAmount
					,SUM(CASE WHEN d.FirstDeposit <> 0 THEN 1 ELSE 0 END * d.IsDateRange)	AS FirstDepositUsers
					,SUM(CASE WHEN d.FirstDeposit <> 0 THEN 1 ELSE 0 END * d.IsMTD)			AS MTD_FirstDepositUsers
					,SUM(CASE WHEN d.FirstDeposit <> 0 THEN 1 ELSE 0 END)					AS Total_FirstDepositUsers
					,SUM(d.FirstDeposit * d.IsDateRange)	AS FirstDepositAmount
					,SUM(d.FirstDeposit * d.IsMTD)			AS MTD_FirstDepositAmount
					,SUM(d.FirstDeposit)					AS Total_FirstDepositAmount
				FROM #DepositUsers d
				WHERE d.CustId = c.CustId
			) d
			OUTER APPLY (
				SELECT
					 SUM(w.IsDateRange) AS WithdrawalUsers
					,SUM(w.IsMTD)		AS MTD_WithdrawalUsers
					,SUM(1)				AS Total_WithdrawalUsers
					,SUM(w.Withdrawal * w.IsDateRange)	AS WithdrawalAmount
					,SUM(w.Withdrawal * w.IsMTD)		AS MTD_WithdrawalAmount
					,SUM (w.Withdrawal)					AS Total_WithdrawalAmount
				FROM #WithdrawalUsers w
				WHERE w.CustId = c.CustId
			) w
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0

		SELECT  @Total_NoOfDepositUsers = @Total_NoOfDepositUsers - COUNT(CASE WHEN c.ActStatus = 2 THEN 1 ELSE NULL END) + COUNT(d.CustId) 
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN dbo.DepositInfo d WITH (NOLOCK) ON c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
		WHERE c.RegTime < '2020-08-15'
			AND c.SiteId = @SiteId
			AND c.IsTest = 0

		INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, AllRange, DataType)
		VALUES
			('Total Users'					, N'Tổng user hiện có'	, @NoOfUsers			, @MTD_NoOfUsers			, 0 , 1)
			,('NRU - Newly Registered Users', N'Số khách mới'		, @NewlyRegisterUsers	, @MTD_NewlyRegisterUsers	, 0 , 1)
			,('Active Users'				, N'Số khách có cược'	, @ActiveUsers			, @MTD_ActiveUsers			, 0 , 1)
		
		-- Bonus Info
		INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, AllRange, DataType)
		SELECT 'No. of users claiming "' + b.BonusCode + '"', N'Số khách nhận khuyến mãi "' + b.BonusCode + '"', SUM(BonusUsers), SUM(MTD_BonusUsers), 0, 1
		FROM dbo.Customer c WITH (NOLOCK)
			CROSS APPLY (
				SELECT b.BonusCode
					,COUNT(DISTINCT CASE WHEN b.IsMTD = 0 THEN b.CustId ELSE NULL END) AS BonusUsers
					,COUNT(DISTINCT CASE WHEN b.IsMTD = 1 THEN b.CustId ELSE NULL END) AS MTD_BonusUsers
				FROM #BonusUsers b
				WHERE b.CustId = c.CustId
				GROUP BY b.BonusCode
			) b
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
		GROUP BY b.BonusCode

		DROP TABLE #BonusUsers
		DROP TABLE #DepositUsers
		DROP TABLE #Exchange
		DROP TABLE #WithdrawalUsers

		DECLARE @CR FLOAT, @RR FLOAT, @MTD_CR FLOAT, @MTD_RR FLOAT
		SELECT  @CR = CASE WHEN @NoOfUsers = 0 THEN 0 ELSE (@NoOfUsers - @ActiveUsers) * 1.0 / @NoOfUsers * 100 END
		SELECT  @RR = 100.0 - @CR

		SELECT  @MTD_CR = CASE WHEN @MTD_NoOfUsers = 0 THEN 0 ELSE (@MTD_NoOfUsers - @MTD_ActiveUsers) * 1.0 / @MTD_NoOfUsers * 100 END
		SELECT  @MTD_RR = 100.0 - @MTD_CR

		SELECT  @CR = ROUND(@CR, 0), @RR = ROUND(@RR, 0), @MTD_CR = ROUND(@MTD_CR, 0), @MTD_RR = ROUND(@MTD_RR, 0)

		INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, AllRange, DataType)
		VALUES
			('Total bonus amount claimed'	, N'Tổng tiền khuyến mãi'		, @BonusClaimedAmount, @MTD_BonusClaimedAmount, 0, 2)
			
			,('No. of deposit users'		, N'Số khách nạp tiền'			, @NoOfDepositUsers		, @MTD_NoOfDepositUsers		, @Total_NoOfDepositUsers		, 1)
			,('No. of FTD users'			, N'Số khách nạp tiền lần đầu'	, @NoOfFirstDepositUsers, @MTD_NoOfFirstDepositUsers, @Total_NoOfFirstDepositUsers	, 1)
			,('No. of withdrawal users'		, N'Số khách rút tiền'			, @NoOfWithdrawalUsers	, @MTD_NoOfWithdrawalUsers	, @Total_NoOfWithdrawalUsers	, 1)

			,('Total deposit amount'		, N'Tổng tiền nạp'				, @DepositAmount		, @MTD_DepositAmount		, @Total_DepositAmount		, 2)
			,('Total FTD amount'			, N'Tổng tiền nạp lần đầu'		, @FirstDepositAmount	, @MTD_FirstDepositAmount	, @Total_FirstDepositAmount	, 2)
			,('Total withdrawal amount'		, N'Tổng tiền rút'				, @WithdrawalAmount		, @MTD_WithdrawalAmount		, @Total_WithdrawalAmount	, 2)

			,('CR - Churn Rate'					, N'Tỉ lệ người rời bỏ chơi'	, @CR, @MTD_CR, 0, 3)
			,('RR - Retention Rate'				, N'Tỉ lệ giữ chân người chơi'	, @RR, @MTD_RR, 0, 3)

		-- Signup url
		DECLARE @DefaultSignupUrl VARCHAR(200)
		SELECT  @DefaultSignupUrl = CASE @SiteId
										WHEN 3 THEN 'www.bwing.com'
										END

		SELECT Name, NameVN, DateRange, MonthToDate, AllRange, DataType FROM @tempData

		-- Registration Details
		SELECT SignupUrl, SignupUsers, MTD_SignupUsers, Total_SignupUsers, CONVERT(TINYINT, 1) AS DataType -- int
		FROM
		(
			SELECT CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END AS SignupUrl
				,COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END) AS SignupUsers
				,COUNT(CASE WHEN c.RegTime >= @BeginCurrentMonthGMT AND c.RegTime < DATEADD(DAY, 1, @EndCurrentMonthGMT) THEN 1 ELSE NULL END) AS MTD_SignupUsers
				,COUNT(CASE WHEN c.RegTime >= @OfficialLaunchDate THEN 1 ELSE NULL END) AS Total_SignupUsers
			FROM dbo.Customer c WITH (NOLOCK)
				LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON cg.CustId = c.CustId
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
			GROUP BY CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END
		) t
		WHERE SignupUrl IS NOT NULL
	END
END
GO