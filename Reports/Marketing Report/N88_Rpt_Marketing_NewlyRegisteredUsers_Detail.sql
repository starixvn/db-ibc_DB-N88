/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_NewlyRegisteredUsers_Detail]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@SortbyId			TINYINT = 1
	,@IsSortAsc			BIT = 1
	,@PageIndex			INT = 1
	,@PageSize			INT = 50
	,@NRows				INT = 0 OUTPUT
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Newly Registered Users - View detail

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #137395]
		- 20201215@Percy: View detail Signup URL by Credit Site [RedmineID: #146760]
		- 20201229@Sol: change text from "Credit Site" to "Bong88/Viva88" - [RedmineID: #147542]
		- 20210113@Percy: Add 'APP' signup url [RedmineID: #148616]
		- 20210401@Percy: [RedmineID: #150876]
			1. Add Total Currency, SigupUrl, AFF Code, Total Deposit Amount columns
			2. Add new group Nova88.com for SigupUrl
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
		- 20220214@Percy: Add @SortbyId = 0 for default sort  [RedmineID: #164724]
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Integrate new bonus: Referral & Rebuild Bonus Structure [RedmineID: #171245]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230406@Malcolm: Using Actual Deposit instead of Amount for Deposit Info [RedmineId: #186439]
		- 20230705@Sally: Exclude data of Live Streamer [RedmineId: #189299]

	Param's Explanation:
		@SortbyId:
			. 1 = Campaign
			. 2 = Username
			. 3 = Currency
			. 4 = Registered Date
			. 5 = Signup URL
			. 6 = Aff Code
			. 7 = Is Deposit
			. 8 = First Deposit Amount
			. 9 = Total Deposit Amount
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME, @BonusTypeName VARCHAR(100), @TpCurrencyIds VARCHAR(MAX)
	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	BEGIN	
		SELECT @TpCurrencyIds = 
		(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(tp.TpExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = t.value
		)

		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
		
		CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, ExchangeId INT, Rate FLOAT, MultipleBy FLOAT)
		INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, ExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), e.ExchangeId, Rate, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
		
		DECLARE @RowStart INT, @RowEnd INT
		SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

		-- Detail by Campaign
		DECLARE @DefaultSignupUrl VARCHAR(200), @APPSignupUrl VARCHAR(200)
		DECLARE @CreditAgentName VARCHAR(30) = ''
		CREATE TABLE #Affiliate (CustId INT, AffCode VARCHAR(20))

		IF @SiteId = 1
		BEGIN
			SELECT @APPSignupUrl = 'app.n17881788.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N88.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N88.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01', @APPSignupUrl = 'app.goal123.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01', @APPSignupUrl = 'app.bwing.com', @DefaultSignupUrl = 'www.bwing.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N8B.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8B.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END

		-- Bonus
		BEGIN
			CREATE TABLE #tmpBonus (BonusDate DATE, DataSource VARCHAR(128), BonusType SMALLINT, BonusCode VARCHAR(100), BonusName VARCHAR(300), BonusStatus TINYINT, CustId INT, CurrencyId INT, BetCount INT, BonusAmount MONEY, BasedBonusAmount MONEY)
			INSERT INTO #tmpBonus (BonusDate, DataSource, BonusType, BonusCode, BonusName, BonusStatus, CustId, CurrencyId, BetCount, BonusAmount, BasedBonusAmount)
			EXEC dbo.N88_CustBonusSummary_Sel
				@SiteId = @SiteId
				,@FromDate = @FromDate
				,@ToDate = @ToDate
				,@CurrencyIds = @CurrencyIds
				,@DisplayCurrency = @DisplayCurrency
				,@TimeZone = @TimeZone

			CREATE TABLE #BonusInfo (CustId INT, BonusCode VARCHAR(100))
			INSERT INTO #BonusInfo (CustId, BonusCode)
			SELECT CustId, BonusCode FROM #tmpBonus GROUP BY CustId, BonusCode
		END

		-- Deposit
		BEGIN
			CREATE TABLE #DepositInfo (CustId INT, FirstDepositAmount MONEY, TotalDepositAmount MONEY)
			INSERT INTO #DepositInfo (CustId, FirstDepositAmount, TotalDepositAmount)
			SELECT d.CustId, SUM(d.FirstDepositAmount * e.Rate / e.MultipleBy), SUM(d.TotalDepositAmount * e.Rate / e.MultipleBy)
			FROM (
				SELECT CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, CustId, CurrencyId
					,SUM(CASE WHEN FirstDeposit = 1 THEN ActualDeposit ELSE 0 END) AS FirstDepositAmount
					,SUM(ActualDeposit) AS TotalDepositAmount
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @FDate AND @TDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND Status = 3 -- Approved
					AND SiteId = @SiteId
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), CustId, CurrencyId
			) d
				INNER JOIN #TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.CustId
		END

		SELECT @NRows = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
			LEFT JOIN #BonusInfo b ON c.CustId = b.CustId
		WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.SiteId = @SiteId
			AND c.IsTest = 0
			AND c.MemberType <> 3 -- Exclude Live Streamer
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		SELECT RowId, BonusCode, UserName, Currency, RegTime, SignupUrl, AffCode, IsDeposit, FirstDepositAmount, TotalDepositAmount
		FROM (
			SELECT BonusCode, UserName, Currency, DATEADD(HOUR, @TimeZone, RegTime) AS RegTime, ISNULL(SignupUrl, 'None') AS SignupUrl, AffCode, IsDeposit, FirstDepositAmount, TotalDepositAmount
				,ROW_NUMBER() OVER(ORDER BY
						CASE WHEN @SortbyId = 0 THEN CASE WHEN BonusCode IS NULL THEN 1 ELSE 0 END END
						,CASE WHEN @SortbyId = 0 THEN BonusCode END ASC
						,CASE WHEN @SortbyId = 0 THEN Username END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN BonusCode END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN BonusCode END DESC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN Username END ASC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN Username END DESC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN Currency END ASC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN Currency END DESC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN RegTime END ASC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN RegTime END DESC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN SignupUrl END ASC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN SignupUrl END DESC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN AffCode END ASC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN AffCode END DESC
						,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN IsDeposit END ASC
						,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN IsDeposit END DESC
						,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN FirstDepositAmount END ASC
						,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN FirstDepositAmount END DESC
						,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 1 THEN TotalDepositAmount END ASC
						,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 0 THEN TotalDepositAmount END DESC) AS RowId
			FROM (
				SELECT b.BonusCode, c.UserName, c.RegTime
					,CASE
						WHEN e.ExchangeId = 51 THEN 'INH'
						WHEN e.ExchangeId = 20 THEN 'UUS'
						ELSE e.Code END AS Currency
					,CASE
						WHEN a.CustId IS NOT NULL THEN cg.SignupUrl
						WHEN ag.UserName = @CreditAgentName THEN 'Bong88/Viva88'
						WHEN c.SiteId = 1 AND ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
						WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3 THEN @DefaultSignupUrl
						WHEN cg.SignupUrl = @APPSignupUrl THEN 'APP'
						ELSE cg.SignupUrl END AS SignupUrl
					,a.AffCode
					,CASE WHEN d.TotalDepositAmount IS NULL THEN 0 ELSE 1 END AS IsDeposit
					,d.FirstDepositAmount
					,d.TotalDepositAmount
				FROM dbo.Customer c WITH (NOLOCK)
					INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
					LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.TpExchangeId = c.CurrencyId
					INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON ISNULL(tp.ExchangeId, c.CurrencyId) = e.ExchangeId
					LEFT JOIN #Affiliate a ON c.CustId = a.CustId
					LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
					LEFT JOIN #BonusInfo b ON c.CustId = b.CustId
					LEFT JOIN #DepositInfo d ON c.CustId = d.CustId
				WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND c.SiteId = @SiteId
					AND c.IsTest = 0
					AND c.MemberType <> 3 -- Exclude Live Streamer
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			) r
		) t
		WHERE RowId BETWEEN @RowStart AND @RowEnd
		
		DROP TABLE #Affiliate
		DROP TABLE #BonusInfo
		DROP TABLE #DepositInfo
		DROP TABLE #TpExchange
		DROP TABLE #tmpBonus
	END
END
GO