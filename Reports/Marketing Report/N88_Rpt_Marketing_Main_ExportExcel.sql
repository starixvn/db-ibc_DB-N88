/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Main_ExportExcel]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@CurrencyIds		VARCHAR(MAX)
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
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
		- 20220214@Percy: Remove some redundant information & apply SignupURL function [RedmineID: #164724]
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @SiteId INT
	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @FromDateMTD DATETIME, @ToDateMTD DATETIME, @FromDateMTDGMT DATETIME, @ToDateMTDGMT DATETIME
	DECLARE @OfficialLaunchDate DATETIME, @OfficialLaunchDateGMT DATETIME
	DECLARE @tmpFDate DATE, @tmpTDate DATE, @tmpFDateGMT DATETIME, @tmpTDateGMT DATETIME

	DECLARE @NoOfUsers						INT
			,@MTD_NoOfUsers					INT
			,@NewlyRegisterUsers			INT
			,@MTD_NewlyRegisterUsers		INT
			,@NewlyActiveRegisterUsers		INT
			,@MTD_NewlyActiveRegisterUsers	INT
			,@ActiveUsers					INT
			,@MTD_ActiveUsers				INT

			,@BonusClaimants				INT
			,@MTD_BonusClaimants			INT
			,@BonusClaimedAmount			MONEY
			,@MTD_BonusClaimedAmount		MONEY

			,@NoOfDepositUsers				INT
			,@MTD_NoOfDepositUsers			INT
			,@Total_NoOfDepositUsers		INT
			,@DepositAmount					MONEY
			,@MTD_DepositAmount				MONEY

			,@NoOfFirstDepositUsers			INT
			,@MTD_NoOfFirstDepositUsers		INT
			,@Total_NoOfFirstDepositUsers	INT
			,@FirstDepositAmount			MONEY
			,@MTD_FirstDepositAmount		MONEY

			,@NoOfWithdrawalUsers			INT
			,@MTD_NoOfWithdrawalUsers		INT
			,@Total_NoOfWithdrawalUsers		INT
			,@WithdrawalAmount				MONEY
			,@MTD_WithdrawalAmount			MONEY

	DECLARE @tempData TABLE (Name NVARCHAR(200), NameVN NVARCHAR(200), DateRange MONEY, MonthToDate MONEY, DataType TINYINT)
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

		-- Active Users, Newly Active Registered Users
		DECLARE @ActiveCustomer TABLE (CustId INT, IsMTD TINYINT)

		INSERT INTO @ActiveCustomer (CustId, IsMTD)
		SELECT CustId, 0 FROM dbo.N88_SumWinloss WITH (NOLOCK)
		WHERE TransTime >= @FromDateTimeGMT AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND SiteId = @SiteId
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), Currency) + ',%'
		GROUP BY CustId

		INSERT INTO @ActiveCustomer (CustId, IsMTD)
		SELECT CustId, 1 FROM dbo.N88_SumWinloss WITH (NOLOCK)
		WHERE TransTime >= @FromDateMTDGMT AND TransTime < DATEADD(DAY, 1, @ToDateMTDGMT)
			AND SiteId = @SiteId
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), Currency) + ',%'
		GROUP BY CustId

		SELECT
			@ActiveUsers		= ISNULL(SUM(a.ActiveUsers), 0)
			,@MTD_ActiveUsers	= ISNULL(SUM(a.MTD_ActiveUsers), 0)
			,@NewlyActiveRegisterUsers		= ISNULL(SUM(CASE WHEN a.ActiveUsers > 0 AND c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE 0 END), 0)
			,@MTD_NewlyActiveRegisterUsers	= ISNULL(SUM(CASE WHEN a.MTD_ActiveUsers > 0 AND c.RegTime >= @FromDateMTDGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT) THEN 1 ELSE 0 END), 0)
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN (
				SELECT CustId
					,MAX(CASE WHEN IsMTD = 0 THEN 1 ELSE 0 END) AS ActiveUsers
					,MAX(CASE WHEN IsMTD = 1 THEN 1 ELSE 0 END) AS MTD_ActiveUsers
				FROM @ActiveCustomer
				GROUP BY CustId
			) a ON c.CustId = a.CustId
		WHERE c.IsTest = 0

		-- Deposit/Withdrawal
		CREATE TABLE #DepositUsers (CustId INT, Deposit MONEY, FirstDeposit MONEY, IsMTD TINYINT, PRIMARY KEY (CustId, IsMTD))
		CREATE TABLE #WithdrawalUsers (CustId INT, Withdrawal MONEY, IsMTD TINYINT, PRIMARY KEY (CustId, IsMTD))
		
		-- Bonus data
		CREATE TABLE #BonusUsers (CustId INT, BonusTypeId SMALLINT, BonusClaimed MONEY, IsMTD TINYINT)
		CREATE CLUSTERED INDEX CIX_Bonus ON #BonusUsers (CustId)
		
		CREATE TABLE #BonusType (DBTypeId SMALLINT, BonusTypeId SMALLINT, BonusTypeName VARCHAR(100), DataSource VARCHAR(100), OrderId SMALLINT)
		INSERT INTO #BonusType (DBTypeId, BonusTypeId, BonusTypeName, DataSource, OrderId)
		SELECT DBTypeId, BonusTypeId, BonusTypeName, DataSource, OrderId
		FROM dbo.N88_f_BonusType()

		DECLARE @BonusTypeId SMALLINT, @i TINYINT = 1, @IsMTD TINYINT -- tinyint for SUM

		WHILE @i <= 2
		BEGIN
			IF @i = 1 -- Date range
				SELECT @IsMTD = 0
					,@tmpFDate = DATEADD(DAY, -1, @FromDate), @tmpTDate = DATEADD(DAY, 1, @ToDate)
					,@tmpFDateGMT = @FromDateTimeGMT, @tmpTDateGMT = DATEADD(DAY, 1, @ToDateTimeGMT)
			ELSE -- MTD
				SELECT @IsMTD = 1
					,@tmpFDate = DATEADD(DAY, -1, @FromDateMTD), @tmpTDate = DATEADD(DAY, 1, @ToDateMTD)
					,@tmpFDateGMT = @FromDateMTDGMT, @tmpTDateGMT = DATEADD(DAY, 1, @ToDateMTDGMT)

			-- DepositInfo
			INSERT INTO #DepositUsers (CustId, Deposit, FirstDeposit, IsMTD)
			SELECT d.CustId, SUM(d.Deposit * e.Rate), SUM(d.FirstDeposit * e.Rate), @IsMTD
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS WinlostDate
					,CustId
					,CurrencyId
					,SUM(CASE WHEN FirstDeposit = 1 THEN Amount ELSE 0 END) AS FirstDeposit
					,SUM(Amount) AS Deposit
				FROM dbo.DepositInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
					AND SiteId = @SiteId
					AND Status = 3 -- Approved
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CustId
					,CurrencyId
			) d
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.CustId

			-- WithdrawalInfo
			INSERT INTO #WithdrawalUsers (CustId, Withdrawal, IsMTD)
			SELECT w.CustId, SUM(w.Withdrawal * e.Rate), @IsMTD
			FROM (
				SELECT
					CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS WinlostDate
					,CustId
					,CurrencyId
					,SUM(Amount) AS Withdrawal
				FROM dbo.WithdrawalInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
					AND SiteId = @SiteId
					AND Status = 6 -- Approved
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				GROUP BY
					CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
					,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime))
					,CustId
					,CurrencyId
			) w
				INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY w.CustId
			
			-- BonusInfo
			INSERT INTO #BonusUsers (CustId, BonusTypeId, IsMTD, BonusClaimed)
			SELECT b.CustId, ISNULL(bt.BonusTypeId, 0), @IsMTD, SUM(b.BonusAmount * e.Rate)
			FROM (
				SELECT CustId, PromotionType, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(BonusAmount) AS BonusAmount
				FROM dbo.BonusInfo WITH (NOLOCK)
				WHERE SiteId = @SiteId
					AND WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
				GROUP BY CustId, PromotionType, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) b
				LEFT JOIN #BonusType bt ON b.PromotionType = bt.DBTypeId AND bt.DataSource = 'BonusInfo'
				INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY b.CustId, ISNULL(bt.BonusTypeId, 0)

			-- RebateMLog
			INSERT INTO #BonusUsers (CustId, BonusTypeId, IsMTD, BonusClaimed)
			SELECT r.CustId, ISNULL(bt.BonusTypeId, 0), @IsMTD, SUM(r.BonusAmount * e.Rate)
			FROM (
				SELECT CustId, RebateType, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(RedeemAmount) AS BonusAmount
				FROM dbo.RebateMLog WITH (NOLOCK)
				WHERE SiteId = @SiteId
					AND WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
				GROUP BY CustId, RebateType, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) r
				LEFT JOIN #BonusType bt ON r.RebateType = bt.DBTypeId AND bt.DataSource = 'RebateMLog'
				INNER JOIN #Exchange e ON r.CurrencyId = e.ExchangeId AND r.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY r.CustId, ISNULL(bt.BonusTypeId, 0)

			-- DrawLog
			SET @BonusTypeId = NULL
			SELECT TOP 1 @BonusTypeId = BonusTypeId FROM #BonusType WHERE DataSource = 'DrawLog'
			
			INSERT INTO #BonusUsers (CustId, BonusTypeId, IsMTD, BonusClaimed)
			SELECT d.CustId, @BonusTypeId, @IsMTD, SUM(d.BonusAmount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, DrawTime)) AS ExchangeDate
					,SUM(Amount) AS BonusAmount
				FROM dbo.DrawLog WITH (NOLOCK)
				WHERE SiteId = @SiteId
					AND WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND DrawTime >= @tmpFDateGMT AND DrawTime < @tmpTDateGMT
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, DrawTime))
			) d
				INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.CustId

			-- AdjustmentInfo
			SET @BonusTypeId = NULL
			SELECT TOP 1 @BonusTypeId = BonusTypeId FROM #BonusType WHERE DataSource = 'AdjustmentInfo'

			INSERT INTO #BonusUsers (CustId, BonusTypeId, IsMTD, BonusClaimed)
			SELECT a.CustId, @BonusTypeId, @IsMTD, SUM(a.BonusAmount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(Amount * CASE
									WHEN AdjustType IN (1, 3) THEN 1 -- Credit, Increase bonus
									WHEN AdjustType IN (2, 4) THEN -1 -- Debit, Decrease bonus
									ELSE 0 END) AS BonusAmount
				FROM dbo.AdjustmentInfo WITH (NOLOCK)
				WHERE SiteId = @SiteId
					AND WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
					AND Status = 2 -- Approved
					AND 1 = CASE WHEN CreateTime < '2021-10-31 16:00' OR AdjustType IN (3, 4) THEN 1 ELSE 0 END -- From 1 Nov 2021 (GMT+8), just get Increase & Decrease bonus
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.CustId

			-- LogAdminAdjustWallet
			SET @BonusTypeId = NULL
			SELECT TOP 1 @BonusTypeId = BonusTypeId FROM #BonusType WHERE DataSource = 'LogAdminAdjustWallet'

			INSERT INTO #BonusUsers (CustId, BonusTypeId, IsMTD, BonusClaimed)
			SELECT a.CustId, @BonusTypeId, @IsMTD, SUM(a.BonusAmount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(Amount * CASE
									WHEN Direction = 1 THEN 1 -- 3rd Add
									WHEN Direction = 2 THEN -1 -- 3rd Minus
									ELSE 0 END) AS BonusAmount
				FROM dbo.LogAdminAdjustWallet WITH (NOLOCK)
				WHERE SiteId = @SiteId
					AND WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND CreateTime >= @tmpFDateGMT AND CreateTime < @tmpTDateGMT
					AND Status = 0 -- Success
					AND CreateTime < '2021-10-31 16:00' -- only get data before 1 Nov 2021 (GMT+8)
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.CustId

			-- VipUpgradeReview
			SET @BonusTypeId = NULL
			SELECT TOP 1 @BonusTypeId = BonusTypeId FROM #BonusType WHERE DataSource = 'VipUpgradeReview'

			INSERT INTO #BonusUsers (CustId, BonusTypeId, IsMTD, BonusClaimed)
			SELECT a.CustId, @BonusTypeId, @IsMTD, SUM(a.BonusAmount * e.Rate)
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, SettleTime)) AS ExchangeDate
					,SUM(UpgradeAmount) AS BonusAmount
				FROM dbo.VipUpgradeReview WITH (NOLOCK)
				WHERE SiteId = @SiteId
					AND WinlostDate BETWEEN @tmpFDate AND @tmpTDate
					AND SettleTime >= @tmpFDateGMT AND SettleTime < @tmpTDateGMT
					AND Status = 4 -- Settled
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, SettleTime))
			) a
				INNER JOIN #Exchange e ON a.CurrencyId = e.ExchangeId AND a.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY a.CustId

			SELECT @i = @i + 1
		END

		-- Main data
		SELECT
			@NoOfUsers						= COUNT(CASE WHEN c.RegTime > @OfficialLaunchDateGMT	AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)	THEN 1 ELSE NULL END)
			,@MTD_NoOfUsers					= COUNT(CASE WHEN c.RegTime > @OfficialLaunchDateGMT	AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT)	THEN 1 ELSE NULL END)
			,@NewlyRegisterUsers			= COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT			AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)	THEN 1 ELSE NULL END)
			,@MTD_NewlyRegisterUsers		= COUNT(CASE WHEN c.RegTime >= @FromDateMTDGMT			AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT)	THEN 1 ELSE NULL END)
			,@BonusClaimants				= SUM(ISNULL(b.BonusClaimants, 0))
			,@MTD_BonusClaimants			= SUM(ISNULL(b.MTD_BonusClaimants, 0))
			,@BonusClaimedAmount			= SUM(ISNULL(b.BonusClaimed, 0))
			,@MTD_BonusClaimedAmount		= SUM(ISNULL(b.MTD_BonusClaimed, 0))
			,@NoOfDepositUsers				= SUM(ISNULL(d.DepositUsers, 0))
			,@MTD_NoOfDepositUsers			= SUM(ISNULL(d.MTD_DepositUsers, 0))
			,@DepositAmount					= SUM(ISNULL(d.DepositAmount, 0))
			,@MTD_DepositAmount				= SUM(ISNULL(d.MTD_DepositAmount, 0))
			,@NoOfFirstDepositUsers			= SUM(ISNULL(d.FirstDepositUsers, 0))
			,@MTD_NoOfFirstDepositUsers		= SUM(ISNULL(d.MTD_FirstDepositUsers, 0))
			,@FirstDepositAmount			= SUM(ISNULL(d.FirstDepositAmount, 0))
			,@MTD_FirstDepositAmount		= SUM(ISNULL(d.MTD_FirstDepositAmount, 0))
			,@NoOfWithdrawalUsers			= SUM(ISNULL(w.WithdrawalUsers, 0))
			,@MTD_NoOfWithdrawalUsers		= SUM(ISNULL(w.MTD_WithdrawalUsers, 0))
			,@WithdrawalAmount				= SUM(ISNULL(w.WithdrawalAmount, 0))
			,@MTD_WithdrawalAmount			= SUM(ISNULL(w.MTD_WithdrawalAmount, 0))
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN (
				SELECT CustId
					,MAX(CASE WHEN IsMTD = 0 THEN 1 ELSE 0 END) AS BonusClaimants
					,MAX(CASE WHEN IsMTD = 1 THEN 1 ELSE 0 END) AS MTD_BonusClaimants
					,SUM(CASE WHEN IsMTD = 0 THEN BonusClaimed ELSE 0 END) AS BonusClaimed
					,SUM(CASE WHEN IsMTD = 1 THEN BonusClaimed ELSE 0 END) AS MTD_BonusClaimed
				FROM #BonusUsers
				GROUP BY CustId
			) b ON b.CustId = c.CustId
			LEFT JOIN (
				SELECT CustId
					,MAX(CASE WHEN IsMTD = 0 THEN 1 ELSE 0 END) AS DepositUsers
					,MAX(CASE WHEN IsMTD = 1 THEN 1 ELSE 0 END) AS MTD_DepositUsers
					,SUM(CASE WHEN IsMTD = 0 THEN Deposit ELSE 0 END) AS DepositAmount
					,SUM(CASE WHEN IsMTD = 1 THEN Deposit ELSE 0 END) AS MTD_DepositAmount
					,MAX(CASE WHEN IsMTD = 0 AND FirstDeposit <> 0 THEN 1 ELSE 0 END) AS FirstDepositUsers
					,MAX(CASE WHEN IsMTD = 1 AND FirstDeposit <> 0 THEN 1 ELSE 0 END) AS MTD_FirstDepositUsers
					,SUM(CASE WHEN IsMTD = 0 THEN FirstDeposit ELSE 0 END) AS FirstDepositAmount
					,SUM(CASE WHEN IsMTD = 1 THEN FirstDeposit ELSE 0 END) AS MTD_FirstDepositAmount
				FROM #DepositUsers
				GROUP BY CustId
			) d ON d.CustId = c.CustId
			LEFT JOIN (
				SELECT CustId
					,MAX(CASE WHEN IsMTD = 0 THEN 1 ELSE 0 END) AS WithdrawalUsers
					,MAX(CASE WHEN IsMTD = 1 THEN 1 ELSE 0 END) AS MTD_WithdrawalUsers
					,SUM(CASE WHEN IsMTD = 0 THEN Withdrawal ELSE 0 END) AS WithdrawalAmount
					,SUM(CASE WHEN IsMTD = 1 THEN Withdrawal ELSE 0 END) AS MTD_WithdrawalAmount
				FROM #WithdrawalUsers
				GROUP BY CustId
			) w ON w.CustId = c.CustId
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, DataType)
		VALUES
			('NRU - Newly Registered Users'	, N'Số khách mới'				, @NewlyRegisterUsers		, @MTD_NewlyRegisterUsers	, 1)
			,('Active Users'				, N'Số khách có cược'			, @ActiveUsers				, @MTD_ActiveUsers			, 1)
			,('Active NRU'					, N'Số khách mới có cược'		, @NewlyActiveRegisterUsers	, @MTD_NewlyActiveRegisterUsers, 1)
			
			,('Total bonus claimants'		, N'Tổng khách nhận khuyến mãi'	, @BonusClaimants			, @MTD_BonusClaimants, 1)
			,('Total bonus amount claimed'	, N'Tổng tiền khuyến mãi'		, @BonusClaimedAmount		, @MTD_BonusClaimedAmount, 2)
			
			,('No. of deposit users'		, N'Số khách nạp tiền'			, @NoOfDepositUsers			, @MTD_NoOfDepositUsers		, 1)
			,('No. of FTD users'			, N'Số khách nạp tiền lần đầu'	, @NoOfFirstDepositUsers	, @MTD_NoOfFirstDepositUsers, 1)
			,('No. of withdrawal users'		, N'Số khách rút tiền'			, @NoOfWithdrawalUsers		, @MTD_NoOfWithdrawalUsers	, 1)

			,('Total deposit amount'		, N'Tổng tiền nạp'				, @DepositAmount			, @MTD_DepositAmount		, 2)
			,('Total FTD amount'			, N'Tổng tiền nạp lần đầu'		, @FirstDepositAmount		, @MTD_FirstDepositAmount	, 2)
			,('Total withdrawal amount'		, N'Tổng tiền rút'				, @WithdrawalAmount			, @MTD_WithdrawalAmount		, 2)
		
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

		---show CR/RR when user is not limited by last x day
		IF (@FromLastXDays IS NULL)
		BEGIN
			INSERT INTO @tempData (Name, NameVN, DateRange, MonthToDate, DataType)
			VALUES
			('CR - Churn Rate'		, N'Tỉ lệ người rời bỏ chơi'	, @CR, @MTD_CR, 3)
			,('RR - Retention Rate'	, N'Tỉ lệ giữ chân người chơi'	, @RR, @MTD_RR, 3)
		END

		INSERT INTO @tempData (Name) VALUES (NULL) -- support web a line in excel

		SELECT Name, NameVN, DateRange, MonthToDate, DataType FROM @tempData

		-- Registration Details
		CREATE TABLE #Affiliate (CustId INT, AffName VARCHAR(50))
		DECLARE @MainURL VARCHAR(200)

		IF @SiteId = 1
		BEGIN
			SELECT @MainURL = 'Nova88.net'
			
			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N88.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N88.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @MainURL = 'Goal123.com'
			
			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @MainURL = 'Bwing.com'
			
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
				CONVERT(NVARCHAR(200),
					CASE
						WHEN a.CustId IS NOT NULL THEN 'AFF'
						WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
						WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
						WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN @MainURL
						ELSE cg.SignupUrl END
					) AS SignupUrl
				,CASE
					WHEN a.CustId IS NOT NULL THEN 2
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 4
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 1 -- main site
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN 1 -- main site
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 3
					WHEN cg.CustId IS NOT NULL THEN 5
					ELSE 6 END AS OrderCol
				,COUNT(CASE WHEN c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END) AS SignupUsers
				,COUNT(CASE WHEN c.RegTime >= @FromDateMTDGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateMTDGMT) THEN 1 ELSE NULL END) AS MTD_SignupUsers
				
			FROM dbo.Customer c WITH (NOLOCK)
				INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
				LEFT JOIN #Affiliate a ON c.CustId = a.CustId
				LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON cg.CustId = c.CustId
				LEFT JOIN dbo.N88_f_SignupURL() s ON cg.SignupUrl = s.SignupUrl AND s.SiteId = @SiteId
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			GROUP BY
				CONVERT(NVARCHAR(200),
					CASE
						WHEN a.CustId IS NOT NULL THEN 'AFF'
						WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
						WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
						WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN @MainURL
						ELSE cg.SignupUrl END
					)
				,CASE
					WHEN a.CustId IS NOT NULL THEN 2
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 4
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 1 -- main site
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN 1 -- main site
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 3
					WHEN cg.CustId IS NOT NULL THEN 5
					ELSE 6 END
		) r
		WHERE r.SignupUsers > 0 OR r.MTD_SignupUsers > 0
		ORDER BY r.OrderCol, r.SignupUrl
	END
	
	DROP TABLE #Affiliate
	DROP TABLE #BonusType
END
GO