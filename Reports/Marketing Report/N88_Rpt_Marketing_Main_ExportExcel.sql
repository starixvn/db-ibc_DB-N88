/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Main_ExportExcel]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@CurrencyIds VARCHAR(MAX)
	,@FromLastXDays		DATE = NULL
AS

/*
	Created: 20200915@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Main - Export Excel

	Revisions:
		- 20200915@Percy: Initialize SP [RedmineID: #141575]
		- 20200928@Percy: Change way to calculate active users [RedmineID: #141575]
		- 20201029@Percy: Change Bonus User to Bonus Amount [RedmineID: #143879]
		- 20201215@Percy: View detail Signup URL by Credit Site [RedmineID: #146760]
		- 20201223@Sol: Add newly active registered users info - [RedmineID: #147542]
		- 20201229@Sol: change text from "Credit Site" to "Bong88/Viva88" and sort - [RedmineID: #147542]
		- 20210113@Percy: Add Rebate & Cashback + 'APP' signup url [RedmineID: #148616]
		- 20210301@Percy: Change date range on MTD column + translate of Credit [RedmineID: #150398]
		- 20210401@Percy: Add new group Signup Url [RedmineID: #150876]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20210719@Sol: MPA - Apply Date Range permission & some enhancement - [RedmineID: #158257]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @SiteId INT
	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @FromDateMTD DATETIME, @ToDateMTD DATETIME, @FromDateMTDGMT DATETIME, @ToDateMTDGMT DATETIME
	DECLARE @OfficialLaunchDate DATETIME, @OfficialLaunchDateGMT DATETIME

	DECLARE @NoOfUsers						INT
			,@MTD_NoOfUsers					INT
			,@NewlyRegisterUsers			INT
			,@MTD_NewlyRegisterUsers		INT
			,@NewlyActiveRegisterUsers		INT
			,@MTD_NewlyActiveRegisterUsers	INT
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
										END -- GMT+8

		SELECT @FromDateMTD = DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(HOUR, 4 + @TimeZone, GETDATE() - 1)), 0)
		SELECT @ToDateMTD = CONVERT(DATE, DATEADD(HOUR, 4 + @TimeZone, GETDATE() - 1))

		IF (@FromLastXDays IS NOT NULL)
		BEGIN
			IF (@FromLastXDays > @FromDateMTD) --gmt+8 comparation)
				SET @FromDateMTD = @FromLastXDays

			IF (@FromLastXDays > @OfficialLaunchDate) --gmt+8 comparation)
				SET @OfficialLaunchDate = @FromLastXDays
		END

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT			= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
				,@FromDateMTDGMT	= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDateMTD))
				,@ToDateMTDGMT	= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDateMTD))
				,@OfficialLaunchDateGMT	= DATEADD(HOUR, -8, @OfficialLaunchDate) -- GMT+8

		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = '2019-12-31', @TDate = DATEADD(DAY, 1, CONVERT(DATE, GETDATE()))
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId TINYINT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		-- Active Users
		SELECT @ActiveUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND (
				EXISTS (
					SELECT 1 FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE c.CustId = r.CustId
						AND r.TransTime >= @FromDateTimeGMT AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND r.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				)
				OR EXISTS (
					SELECT 1 
					FROM dbo.TpTransferInfo t WITH (NOLOCK)
					WHERE c.CustId = t.CustId
						AND t.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
						AND t.CreateTime >= @FromDateTimeGMT AND t.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND t.SiteId = @SiteId
				)
			)
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT @MTD_ActiveUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND (
				EXISTS (
					SELECT 1 FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE c.CustId = r.CustId
						AND r.TransTime >= @FromDateMTDGMT AND r.TransTime < DATEADD(DAY, 1, @ToDateMTDGMT)
						AND r.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				)
				OR EXISTS (
					SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK)
					WHERE c.CustId = t.CustId
						AND t.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDateMTD) AND DATEADD(DAY, 1, @ToDateMTD)
						AND t.CreateTime >= @FromDateMTDGMT AND t.CreateTime < DATEADD(DAY, 1, @ToDateMTDGMT)
						AND t.SiteId = @SiteId
				)
			)
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		-- Newly Active Registered Users
		SELECT @NewlyActiveRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND (
				EXISTS (
					SELECT 1 FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE c.CustId = r.CustId
						AND r.TransTime >= @FromDateTimeGMT AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND r.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				)
				OR EXISTS (
					SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK)
					WHERE c.CustId = t.CustId
						AND t.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
						AND t.CreateTime >= @FromDateTimeGMT AND t.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
						AND t.SiteId = @SiteId
				)
			)
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT @MTD_NewlyActiveRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateMTDGMT AND RegTime < DATEADD(DAY, 1, @ToDateMTDGMT) THEN 1 ELSE NULL END)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND (
				EXISTS (
					SELECT 1 FROM dbo.N88_SumWinloss r WITH (NOLOCK)
					WHERE c.CustId = r.CustId
						AND r.TransTime >= @FromDateMTDGMT AND r.TransTime < DATEADD(DAY, 1, @ToDateMTDGMT)
						AND r.SiteId = @SiteId
						AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				)
				OR EXISTS (
					SELECT 1 FROM dbo.TpTransferInfo t WITH (NOLOCK)
					WHERE c.CustId = t.CustId
						AND t.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDateMTD) AND DATEADD(DAY, 1, @ToDateMTD)
						AND t.CreateTime >= @FromDateMTDGMT AND t.CreateTime < DATEADD(DAY, 1, @ToDateMTDGMT)
						AND t.SiteId = @SiteId
				)
			)
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		-- Deposit
		CREATE TABLE #DepositUsers (CustId INT, Deposit MONEY, FirstDeposit MONEY, IsDateRange TINYINT, IsMTD TINYINT, IsAll TINYINT)
		INSERT INTO #DepositUsers (CustId, Deposit, FirstDeposit, IsDateRange, IsMTD, IsAll)
		SELECT
			d.CustId
			,SUM(d.Deposit * e.Rate)
			,SUM(d.FirstDeposit * e.Rate)
			,CASE WHEN d.WinlostDate BETWEEN @FromDate AND @ToDate THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate BETWEEN @FromDateMTD AND @ToDateMTD THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate >= @OfficialLaunchDate THEN 1 ELSE 0 END
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
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
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
			,CASE WHEN d.WinlostDate BETWEEN @FromDateMTD AND @ToDateMTD THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate >= @OfficialLaunchDate THEN 1 ELSE 0 END

		-- Withdrawal
		CREATE TABLE #WithdrawalUsers (CustId INT, Withdrawal MONEY, IsDateRange TINYINT, IsMTD TINYINT, IsAll TINYINT)
		INSERT INTO #WithdrawalUsers (CustId, Withdrawal, IsDateRange, IsMTD, IsAll)
		SELECT
			d.CustId
			,SUM(d.Withdrawal * e.Rate)
			,CASE WHEN d.WinlostDate BETWEEN @FromDate AND @ToDate THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate BETWEEN @FromDateMTD AND @ToDateMTD THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate >= @OfficialLaunchDate THEN 1 ELSE 0 END
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
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
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
			,CASE WHEN d.WinlostDate BETWEEN @FromDateMTD AND @ToDateMTD THEN 1 ELSE 0 END
			,CASE WHEN d.WinlostDate >= @OfficialLaunchDate THEN 1 ELSE 0 END

		-- Bonus
		CREATE TABLE #BonusUsers (CustId INT, BonusCode VARCHAR(20), BonusClaimed MONEY, IsDateRange TINYINT, IsMTD TINYINT)
			-- Date range
			INSERT INTO #BonusUsers (CustId, BonusCode, BonusClaimed, IsDateRange, IsMTD)
			SELECT b.CustId, b.BonusCode
				,SUM(b.BonusAmount * e.Rate)
				,1 AS IsDateRange
				,0 AS IsMTD
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE b.SiteId = @SiteId
				AND b.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			GROUP BY b.CustId, b.BonusCode

			INSERT INTO #BonusUsers (CustId, BonusCode, BonusClaimed, IsDateRange, IsMTD)
			SELECT r.CustId, r.BonusCode
				,SUM(r.RedeemAmount * e.Rate)
				,1 AS IsDateRange
				,0 AS IsMTD
			FROM dbo.RebateMLog r WITH (NOLOCK)
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE r.SiteId = @SiteId
				AND r.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
				AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			GROUP BY r.CustId, r.BonusCode

			-- Month to date
			INSERT INTO #BonusUsers (CustId, BonusCode, BonusClaimed, IsDateRange, IsMTD)
			SELECT b.CustId, b.BonusCode
				,SUM(b.BonusAmount * e.Rate)
				,0 AS IsDateRange
				,1 AS IsMTD
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE b.SiteId = @SiteId
				AND b.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDateMTD) AND DATEADD(DAY, 1, @ToDateMTD)
				AND b.CreateTime >= @FromDateMTDGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateMTDGMT)
			GROUP BY b.CustId, b.BonusCode

			INSERT INTO #BonusUsers (CustId, BonusCode, BonusClaimed, IsDateRange, IsMTD)
			SELECT r.CustId, r.BonusCode
				,SUM(r.RedeemAmount * e.Rate)
				,0 AS IsDateRange
				,1 AS IsMTD
			FROM dbo.RebateMLog r WITH (NOLOCK)
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, r.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE r.SiteId = @SiteId
				AND r.WinlostDate BETWEEN DATEADD(DAY, -1, @FromDateMTD) AND DATEADD(DAY, 1, @ToDateMTD)
				AND r.CreateTime >= @FromDateMTDGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateMTDGMT)
			GROUP BY r.CustId, r.BonusCode

		-- Main data
		SELECT
			@NoOfUsers						= COUNT(CASE WHEN c.RegTime > @OfficialLaunchDateGMT	AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)			THEN 1 ELSE NULL END)
			,@MTD_NoOfUsers					= COUNT(CASE WHEN c.RegTime > @OfficialLaunchDateGMT	AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT)	THEN 1 ELSE NULL END)
			,@NewlyRegisterUsers			= COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT			AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)			THEN 1 ELSE NULL END)
			,@MTD_NewlyRegisterUsers		= COUNT(CASE WHEN c.RegTime >= @FromDateMTDGMT	AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT)	THEN 1 ELSE NULL END)
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
					 COUNT(DISTINCT CASE WHEN d.IsDateRange = 1 THEN d.CustId ELSE NULL END)	AS DepositUsers
					,COUNT(DISTINCT CASE WHEN d.IsMTD = 1 THEN d.CustId ELSE NULL END)			AS MTD_DepositUsers
					,COUNT(DISTINCT CASE WHEN d.IsAll = 1 THEN d.CustId ELSE NULL END)			AS Total_NoOfDepositUsers
					,SUM(d.Deposit * d.IsDateRange) AS DepositAmount
					,SUM(d.Deposit * d.IsMTD)		AS MTD_DepositAmount
					,SUM(d.Deposit * d.IsAll)		AS Total_DepositAmount
					,SUM(CASE WHEN d.FirstDeposit <> 0 THEN 1 ELSE 0 END * d.IsDateRange)	AS FirstDepositUsers
					,SUM(CASE WHEN d.FirstDeposit <> 0 THEN 1 ELSE 0 END * d.IsMTD)			AS MTD_FirstDepositUsers
					,SUM(CASE WHEN d.FirstDeposit <> 0 THEN 1 ELSE 0 END * d.IsAll)			AS Total_FirstDepositUsers
					,SUM(d.FirstDeposit * d.IsDateRange)	AS FirstDepositAmount
					,SUM(d.FirstDeposit * d.IsMTD)			AS MTD_FirstDepositAmount
					,SUM(d.FirstDeposit * d.IsAll)			AS Total_FirstDepositAmount
				FROM #DepositUsers d
				WHERE d.CustId = c.CustId
			) d
			OUTER APPLY (
				SELECT
					 COUNT(DISTINCT CASE WHEN w.IsDateRange = 1 THEN w.CustId ELSE NULL END)	AS WithdrawalUsers
					,COUNT(DISTINCT CASE WHEN w.IsMTD = 1 THEN w.CustId ELSE NULL END)			AS MTD_WithdrawalUsers
					,COUNT(DISTINCT CASE WHEN w.IsAll = 1 THEN w.CustId ELSE NULL END)			AS Total_WithdrawalUsers
					,SUM(w.Withdrawal * w.IsDateRange)	AS WithdrawalAmount
					,SUM(w.Withdrawal * w.IsMTD)		AS MTD_WithdrawalAmount
					,SUM (w.Withdrawal * w.IsAll)		AS Total_WithdrawalAmount
				FROM #WithdrawalUsers w
				WHERE w.CustId = c.CustId
			) w
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, AllRange, DataType)
		VALUES
			('Total Users'					, N'Tổng khách hiện có'	, @NoOfUsers			, @MTD_NoOfUsers			, 0 , 1)
			,('NRU - Newly Registered Users', N'Số khách mới'		, @NewlyRegisterUsers	, @MTD_NewlyRegisterUsers	, 0 , 1)
			,('Active Users'				, N'Số khách có cược'	, @ActiveUsers			, @MTD_ActiveUsers			, 0 , 1)
			,('Active NRU'					, N'Số khách mới có cược', @NewlyActiveRegisterUsers, @MTD_NewlyActiveRegisterUsers			, 0 , 1)
		
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
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
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

		---show CR/RR when user is not limited by last x day
		IF (@FromLastXDays IS NULL)
		BEGIN
			INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, AllRange, DataType)
			VALUES
			('CR - Churn Rate'					, N'Tỉ lệ người rời bỏ chơi'	, @CR, @MTD_CR, 0, 3)
			,('RR - Retention Rate'				, N'Tỉ lệ giữ chân người chơi'	, @RR, @MTD_RR, 0, 3)
		END

		INSERT INTO @tempData (Name) VALUES (NULL) -- support web a line in excel

		SELECT Name, NameVN, DateRange, MonthToDate, AllRange, DataType FROM @tempData

		-- Registration Details
		DECLARE @DefaultSignupUrl VARCHAR(200), @APPSignupUrl VARCHAR(200), @MainUrl VARCHAR(200)
		DECLARE @CreditAgentName VARCHAR(30) = ''
		DECLARE @MainUrls TABLE (Url VARCHAR(200))
		CREATE TABLE #Affiliate (CustId INT, AffName VARCHAR(50))

		IF @SiteId = 1
		BEGIN
			SELECT @APPSignupUrl = 'app.n17881788.com', @MainUrl = 'Nova88.net'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.nova88.com'), ('www.nova88.net'), ('m.nova88.net')

			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N88.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N88.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01', @APPSignupUrl = 'app.goal123.com', @MainUrl = 'Goal123.com'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.goal123.com'), ('m.goal123.com')
					,('m.sutbong123.com') 
					,('mrelease.goal123.com')
					,('release.goal123.com')     
					,('www.sutbong123.com')     
					,('www.duongdenkhungthanh.com')
					,('m.duongdenkhungthanh.com')
					,('https://www.duongdenkhungthanh.com')
					,('https://m.duongdenkhungthanh.com')


			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01', @APPSignupUrl = 'app.bwing.com', @DefaultSignupUrl = 'www.bwing.com', @MainUrl = 'Bwing.com'

			INSERT INTO @MainUrls (Url)
			VALUES ('www.bwing.com'), ('m.bwing.com')
					,('release.bwing.com')
					,('mrelease.bwing.com')
					,('www.bwinghotevent.club')
					,('m.bwinghotevent.club')    
					,('www.bomtanhoitu.live')
					,('m.bomtanhoitu.live')
					,('https://www.bwinghotevent.club')
					,('https://www.bomtanhoitu.live')

			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8B.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8B.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END

		SELECT ISNULL(SignupUrl, 'None') AS SignupUrl
			,ISNULL(SignupUrl, N'Không xác định') AS SignupUrlVN
			,SignupUsers, MTD_SignupUsers 
			,CONVERT(TINYINT, 1) AS DataType -- int
		FROM (
			SELECT
				CAST((CASE
					WHEN a.CustId IS NOT NULL THEN 'AFF'
					WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
					WHEN c.SiteId = 1 AND ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN @MainUrl
					WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
					ELSE cg.SignupUrl END) AS NVARCHAR(200)) AS SignupUrl
				,COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END) AS SignupUsers
				,COUNT(CASE WHEN c.RegTime >= @FromDateMTDGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT) THEN 1 ELSE NULL END) AS MTD_SignupUsers
				--,COUNT(CASE WHEN c.RegTime >= @OfficialLaunchDateGMT THEN 1 ELSE NULL END) AS Total_SignupUsers
				,CASE
					WHEN a.CustId IS NOT NULL THEN 2
					WHEN ag.UserName = @CreditAgentName THEN 4
					WHEN c.SiteId = 1 AND ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 1 -- main site
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN 1 -- main site
					WHEN cg.SignupUrl = @APPSignupUrl THEN 3
					WHEN cg.CustId IS NOT NULL THEN 5
					ELSE 6 END AS OrderCol
			FROM dbo.Customer c WITH (NOLOCK)
				INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
				LEFT JOIN #Affiliate a ON c.CustId = a.CustId
				LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON cg.CustId = c.CustId
				LEFT JOIN @MainUrls mu ON cg.SignupUrl = mu.Url
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			GROUP BY
				CASE
					WHEN a.CustId IS NOT NULL THEN 'AFF'
					WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
					WHEN c.SiteId = 1 AND ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN @MainUrl
					WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
					ELSE cg.SignupUrl END
				,CASE
					WHEN a.CustId IS NOT NULL THEN 2
					WHEN ag.UserName = @CreditAgentName THEN 4
					WHEN c.SiteId = 1 AND ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 1 -- main site
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR mu.Url IS NOT NULL THEN 1 -- main site
					WHEN cg.SignupUrl = @APPSignupUrl THEN 3
					WHEN cg.CustId IS NOT NULL THEN 5
					ELSE 6 END
		) r
		WHERE r.SignupUsers > 0 OR r.MTD_SignupUsers > 0
		ORDER BY r.OrderCol, r.SignupUrl
	END

	DROP TABLE #Affiliate
END
GO