/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Deposit_Detail]
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
	,@NRows				INT = 0 OUTpUT
AS

/*
	Created: 20201215@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Deposit - View detail

	Revisions:
		- 20201215@Percy: Initialize SP [RedmineID: #146760]
		- 20201215@Percy: View detail Signup URL by Credit Site [RedmineID: #146760]
		- 20201229@Sol: change text from "Credit Site" to "Bong88/Viva88" - [RedmineID: #147542]
		- 20210113@Percy: Add 'APP' signup url [RedmineID: #148616]
		- 20210401@Percy: Add Currency, Aff Code columns [RedmineID: #150876]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]

	Param's Explanation:
		@SortbyId:
			. 1 = Username
			. 2 = Currency
			. 3 = Registered Date
			. 4 = Signup URL
			. 5 = Aff Code
			. 6 = First Deposit Amount
			. 7 = Number of Deposits
			. 8 = Total Deposit Amount
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME, @TpCurrencyIds VARCHAR(MAX)

	BEGIN
		SELECT @TpCurrencyIds = 
		(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(Tp.TpExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TpExchange Tp WITH(NOLOCK) ON Tp.ExchangeId = t.value
		)

		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)
		
		CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, ExchangeId INT, Rate FLOAT)
		INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, ExchangeId, Rate)
		SELECT FromDate, ToDate, ISNULL(Tp.TpExchangeID, e.ExchangeId), e.ExchangeId, Rate / CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END 
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange Tp WITH(NOLOCK) ON Tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
		
		CREATE TABLE #DepositInfo (CustId INT, NoOfDeposits INT, TotalDepositAmount MONEY, FirstDepositAmount MONEY)
		
		;WITH CTE_DepositInfo AS (
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,COUNT(1) AS NoOfDeposits
				,SUM(Amount) AS TotalDepositAmount
				,SUM(CASE WHEN FirstDeposit = 1 THEN Amount ELSE 0 END) AS FirstDepositAmount
			FROM dbo.DepositInfo d WITH (NOLOCK)
			WHERE CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND Status = 3
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		)
		INSERT INTO #DepositInfo (CustId, NoOfDeposits, TotalDepositAmount, FirstDepositAmount)
		SELECT CustId, SUM(NoOfDeposits), SUM(TotalDepositAmount * e.Rate), SUM(FirstDepositAmount * e.Rate)
		FROM CTE_DepositInfo d
			INNER JOIN #TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY CustId

		SELECT @NRows = COUNT(1)
		FROM #DepositInfo d
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
		WHERE c.SiteId = @SiteId AND c.IsTest = 0
		
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
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01', @APPSignupUrl = 'app.goal123.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01', @APPSignupUrl = 'app.bwing.com', @DefaultSignupUrl = 'www.bwing.com'

			INSERT INTO #Affiliate (CustId, AffCode)
			SELECT mi.CustId, ai.AffCode
			FROM Affiliate_N8B.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8B.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
		END

		SELECT RowId, UserName, Currency, RegTime, SignupUrl, AffCode, FirstDepositAmount, NoOfDeposits, TotalDepositAmount
		FROM (
			SELECT UserName, Currency, DATEADD(HOUR, @TimeZone, RegTime) AS RegTime, ISNULL(SignupUrl, 'None') AS SignupUrl, AffCode, FirstDepositAmount, NoOfDeposits, TotalDepositAmount
				,ROW_NUMBER() OVER(ORDER BY
							 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN Username END ASC
							,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN Username END DESC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN Currency END ASC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN Currency END DESC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN RegTime END ASC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN RegTime END DESC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN SignupUrl END ASC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN SignupUrl END DESC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN AffCode END ASC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN AffCode END DESC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN FirstDepositAmount END ASC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN FirstDepositAmount END DESC
							,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN NoOfDeposits END ASC
							,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN NoOfDeposits END DESC
							,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN TotalDepositAmount END ASC
							,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN TotalDepositAmount END DESC) AS RowId
			FROM (
				SELECT c.UserName, c.RegTime
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
					,d.NoOfDeposits
					,d.FirstDepositAmount
					,d.TotalDepositAmount
				FROM #DepositInfo d
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
					INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
					LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.TpExchangeId = c.CurrencyId
					INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON e.ExchangeId = ISNULL(tp.ExchangeId, c.CurrencyId)
					LEFT JOIN #Affiliate a ON c.CustId = a.CustId
					LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
				WHERE c.SiteId = @SiteId
					AND c.IsTest = 0
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
			) r
		) t
		WHERE RowId BETWEEN @RowStart AND @RowEnd
		
		DROP TABLE #Affiliate
		DROP TABLE #DepositInfo
		DROP TABLE #TpExchange
	END
END
GO