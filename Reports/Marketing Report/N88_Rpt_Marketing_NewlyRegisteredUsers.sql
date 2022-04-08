/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_NewlyRegisteredUsers]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Newly Registered Users

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #137395]
		- 20201215@Percy: View detail Signup URL by Credit Site [RedmineID: #146760]
		- 20201229@Sol: change text from "Credit Site" to "Bong88/Viva88" - [RedmineID: #147542]
		- 20210113@Percy: Add 'APP' signup url [RedmineID: #148616]
		- 20210401@Percy: [RedmineID: #150876]
			1. Add Total Total Deposit Amount, Bonus Name columns
			2. Add new group Nova88.com for SigupUrl
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
		- 20220214@Percy: Apply SignupURL function [RedmineID: #164724]
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Integrate new bonus: Referral & Rebuild Bonus Structure [RedmineID: #171245]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @BonusTypeName VARCHAR(100)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @NewlyRegisterUsers INT, @CompareNewlyRegisterUsers INT

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

		-- Total
		SELECT @NewlyRegisterUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND SiteId = @SiteId
			AND IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT @CompareNewlyRegisterUsers = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
			AND SiteId = @SiteId
			AND IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		-- Summary
		SELECT @NewlyRegisterUsers AS NewlyRegisterUsers, @CompareNewlyRegisterUsers AS CompareNewlyRegisterUsers

		-- Detail by Campaign
		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT, MultipleBy FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ExchangeId, Rate, CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
		
		-- Bonus
		CREATE TABLE #tmpBonus (BonusDate DATE, DataSource VARCHAR(128), BonusType SMALLINT, BonusCode VARCHAR(100), BonusName VARCHAR(300), BonusStatus TINYINT, CustId INT, CurrencyId INT, BetCount INT, BonusAmount MONEY, BasedBonusAmount MONEY)
		INSERT INTO #tmpBonus (BonusDate, DataSource, BonusType, BonusCode, BonusName, BonusStatus, CustId, CurrencyId, BetCount, BonusAmount, BasedBonusAmount)
		EXEC dbo.N88_CustBonusSummary_Sel
			@SiteId = @SiteId
			,@FromDate = @FromDate
			,@ToDate = @ToDate
			,@CurrencyIds = @CurrencyIds
			,@DisplayCurrency = @DisplayCurrency
			,@TimeZone = @TimeZone
		
		CREATE TABLE #BonusInfo (CustId INT, BonusCode VARCHAR(100), BonusName VARCHAR(300))
		INSERT INTO #BonusInfo (CustId, BonusCode, BonusName)
		SELECT CustId, BonusCode, BonusName FROM #tmpBonus GROUP BY CustId, BonusCode, BonusName

		-- Deposit
		CREATE TABLE #DepositInfo (CustId INT, FirstDepositAmount MONEY, TotalDepositAmount MONEY)
		INSERT INTO #DepositInfo (CustId, FirstDepositAmount, TotalDepositAmount)
		SELECT d.CustId, SUM(d.FirstDepositAmount * e.Rate / e.MultipleBy), SUM(d.TotalDepositAmount * e.Rate / e.MultipleBy)
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, CustId, CurrencyId
				,SUM(CASE WHEN FirstDeposit = 1 THEN Amount ELSE 0 END) AS FirstDepositAmount
				,SUM(Amount) AS TotalDepositAmount
			FROM dbo.DepositInfo d WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND Status = 3 -- Approved
				AND SiteId = @SiteId
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
			GROUP BY CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), CustId, CurrencyId
		) d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY d.CustId
		
		SELECT b.BonusCode, b.BonusName, COUNT(c.CustId) AS NewlyRegisterUsers, COUNT(d.CustId) AS Deposit, SUM(ISNULL(d.FirstDepositAmount, 0)) AS FirstDepositAmount, SUM(ISNULL(d.TotalDepositAmount, 0)) AS TotalDepositAmount
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN #BonusInfo b ON c.CustId = b.CustId
			LEFT JOIN #DepositInfo d ON c.CustId = d.CustId
		WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
		GROUP BY b.BonusCode, b.BonusName
		ORDER BY CASE WHEN b.BonusCode IS NULL THEN 1 ELSE 0 END, b.BonusCode

		-- Detail by Signup URL
		CREATE TABLE #Affiliate (CustId INT, AffId INT)
		DECLARE @MainURL VARCHAR(200)
		
		IF @SiteId = 1
		BEGIN
			SELECT @MainURL = 'Nova88.net'

			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N88.dbo.MemberInfo WITH (NOLOCK)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @MainURL = 'Goal123.com'

			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N8G.dbo.MemberInfo WITH (NOLOCK)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @MainURL = 'Bwing.com'

			INSERT INTO #Affiliate (CustId, AffId)
			SELECT CustId, AffId
			FROM Affiliate_N8B.dbo.MemberInfo WITH (NOLOCK)
		END

		SELECT SignUpSource, SignupUrl, NewlyRegisterUsers, Deposit, FirstDepositAmount, TotalDepositAmount
		FROM (
			SELECT
				CASE
					WHEN a.CustId IS NOT NULL THEN 'AFF'
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN @MainURL
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
					WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
					ELSE 'None' END AS SignUpSource
				,CASE
					WHEN a.CustId IS NOT NULL THEN 'AFF'
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN 'www.bwing.com'
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
					ELSE cg.SignupUrl END AS SignupUrl
				,CASE
					WHEN a.CustId IS NOT NULL THEN 2
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 4
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 1 -- main site
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN 1 -- main site
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 3
					WHEN cg.CustId IS NOT NULL THEN 5
					ELSE 6 END AS OrderCol
				,COUNT(1) AS NewlyRegisterUsers, COUNT(d.CustId) AS Deposit, SUM(ISNULL(d.FirstDepositAmount, 0)) AS FirstDepositAmount, SUM(ISNULL(d.TotalDepositAmount, 0)) AS TotalDepositAmount
			FROM dbo.Customer c WITH (NOLOCK)
				INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
				LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
				LEFT JOIN dbo.N88_f_SignupURL() s ON cg.SignupUrl = s.SignupUrl AND s.SiteId = @SiteId
				LEFT JOIN #Affiliate a ON c.CustId = a.CustId
				LEFT JOIN #DepositInfo d ON c.CustId = d.CustId
			WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND c.SiteId = @SiteId
				AND c.IsTest = 0
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			GROUP BY
				CASE
					WHEN a.CustId IS NOT NULL THEN 'AFF'
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN @MainURL
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
					WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
					ELSE 'None' END
				,CASE
					WHEN a.CustId IS NOT NULL THEN 'AFF'
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN 'www.bwing.com'
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
					ELSE cg.SignupUrl END
				,CASE
					WHEN a.CustId IS NOT NULL THEN 2
					WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 4
					WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 1 -- main site
					WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN 1 -- main site
					WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 3
					WHEN cg.CustId IS NOT NULL THEN 5
					ELSE 6 END
		) r
		ORDER BY OrderCol, SignupUrl

		DROP TABLE #Affiliate
		DROP TABLE #BonusInfo
		DROP TABLE #DepositInfo
		DROP TABLE #Exchange
		DROP TABLE #tmpBonus
	END
END
GO