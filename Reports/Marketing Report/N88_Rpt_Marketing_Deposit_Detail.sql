/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Deposit_Detail]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@SortbyId			TINYINT = 1
	,@IsSortAsc			BIT = 1
	,@PageIndex			INT = 1
	,@PageSize			INT = 50
	,@NRows				INT = 0 OUTPUT
AS

/*
	Created: 20201215@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Deposit - View detail

	Revisions:
		- 20201215@Percy: Initialize SP [RedmineID: #146760]
		- 20201215@Percy: View detail Signup URL by Credit Site [RedmineID: #146760]

	Param's Explanation:
		@SortbyId:
			. 1 = Campaign
			. 2 = Username
			. 3 = Registered Date
			. 4 = Signup URL
			. 5 = Deposit
			. 6 = First Deposit Amount
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME

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
		
		CREATE TABLE #DepositInfo (CustId INT, NoOfDeposits INT, DepositAmount MONEY, FirstDepositAmount MONEY)
		
		;WITH CTE_DepositInfo AS (
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,COUNT(1) AS NoOfDeposits
				,SUM(Amount) AS DepositAmount
				,SUM(CASE WHEN FirstDeposit = 1 THEN Amount ELSE 0 END) AS FirstDepositAmount
			FROM dbo.DepositInfo WITH (NOLOCK)
			WHERE CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND Status = 3
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		)
		INSERT INTO #DepositInfo (CustId, NoOfDeposits, DepositAmount, FirstDepositAmount)
		SELECT CustId
			,SUM(NoOfDeposits)
			,SUM(DepositAmount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
			,SUM(FirstDepositAmount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
		FROM CTE_DepositInfo d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY CustId

		SELECT @NRows = COUNT(1)
		FROM #DepositInfo d
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
		WHERE c.SiteId = @SiteId AND c.IsTest = 0
		
		DECLARE @RowStart INT, @RowEnd INT
		SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

		-- Detail by Campaign
		DECLARE @DefaultSignupUrl VARCHAR(200)
		SELECT  @DefaultSignupUrl = CASE @SiteId
										WHEN 3 THEN 'www.bwing.com'
										END

		DECLARE @CreditAgentName VARCHAR(30) = ''
		CREATE TABLE #Affiliate (CustId INT, AffName VARCHAR(50))

		IF @SiteId = 1
		BEGIN
			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N88.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N88.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate <= DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01'

			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate <= DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01'

			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8B.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8B.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate <= DATEADD(DAY, 1, @ToDate)
		END

		SELECT RowId, UserName, RegTime, SignupUrl, FirstDepositAmount, NoOfDeposits, DepositAmount
		FROM (
			SELECT UserName, DATEADD(HOUR, @TimeZone, RegTime) AS RegTime, ISNULL(SignupUrl, 'None') AS SignupUrl, FirstDepositAmount, NoOfDeposits, DepositAmount
				,ROW_NUMBER() OVER(ORDER BY
							 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN Username END ASC
							,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN Username END DESC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN RegTime END ASC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN RegTime END DESC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN SignupUrl END ASC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN SignupUrl END DESC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN FirstDepositAmount END ASC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN FirstDepositAmount END DESC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN NoOfDeposits END ASC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN NoOfDeposits END DESC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN DepositAmount END ASC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN DepositAmount END DESC) AS RowId
			FROM (
				SELECT c.UserName, c.RegTime
					,CASE
						WHEN a.CustId IS NOT NULL THEN a.AffName
						WHEN ag.UserName = @CreditAgentName THEN 'Credit Site'
						WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3 THEN @DefaultSignupUrl
						ELSE cg.SignupUrl END AS SignupUrl
					,d.NoOfDeposits
					,d.FirstDepositAmount
					,d.DepositAmount
				FROM #DepositInfo d
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
					INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
					LEFT JOIN #Affiliate a ON c.CustId = a.CustId
					LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
				WHERE c.SiteId = @SiteId
					AND c.IsTest = 0
			) r
		) t
		WHERE RowId BETWEEN @RowStart AND @RowEnd
		
		DROP TABLE #Affiliate
		DROP TABLE #DepositInfo
		DROP TABLE #Exchange
	END
END
GO