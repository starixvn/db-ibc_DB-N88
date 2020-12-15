/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_NewlyRegisteredUsers_Detail]
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
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Newly Registered Users - View detail

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #137395]
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

		SELECT  @NRows = COUNT(1)
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.SiteId = @SiteId
			AND c.IsTest = 0

		DECLARE @FDate DATE, @TDate DATE
		SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')
		
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
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @CreditAgentName = 'Goal123Ref01'

			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8G.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8G.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @CreditAgentName = 'BwingRef01'

			INSERT INTO #Affiliate (CustId, AffName)
			SELECT mi.CustId, ai.UserName
			FROM Affiliate_N8B.dbo.MemberInfo mi WITH (NOLOCK)
				INNER JOIN Affiliate_N8B.dbo.AffInfo ai WITH (NOLOCK) ON mi.AffId = ai.AffId
			WHERE mi.RegisteredDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
		END

		SELECT RowId, BonusCode, UserName, RegTime, SignupUrl, IsDeposit, FirstDepositAmount
		FROM (
			SELECT BonusCode, UserName, RegTime, ISNULL(SignupUrl, 'None') AS SignupUrl, IsDeposit, FirstDepositAmount
				,ROW_NUMBER() OVER(ORDER BY
							 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN BonusCode END ASC
							,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN BonusCode END DESC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN Username END ASC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN Username END DESC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN RegTime END ASC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN RegTime END DESC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN SignupUrl END ASC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN SignupUrl END DESC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN IsDeposit END ASC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN IsDeposit END DESC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN FirstDepositAmount END ASC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN FirstDepositAmount END DESC) AS RowId
			FROM (
				SELECT b.BonusCode, c.UserName, c.RegTime
					,CASE
						WHEN a.CustId IS NOT NULL THEN a.AffName
						WHEN ag.UserName = @CreditAgentName THEN 'Credit Site'
						WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3 THEN @DefaultSignupUrl
						ELSE cg.SignupUrl END AS SignupUrl
					,CASE WHEN d.Amount IS NULL THEN 0 ELSE 1 END AS IsDeposit
					,d.Amount AS FirstDepositAmount
				FROM dbo.Customer c WITH (NOLOCK)
					INNER JOIN dbo.Customer ag WITH (NOLOCK) ON c.AgentId = ag.CustId
					LEFT JOIN #Affiliate a ON c.CustId = a.CustId
					LEFT JOIN dbo.CustRegInfo cg WITH (NOLOCK) ON c.CustId = cg.CustId
					OUTER APPLY
					(
						SELECT b.CustId, b.BonusCode
						FROM dbo.BonusInfo b WITH (NOLOCK)
						WHERE c.CustId = b.CustId
							AND b.WinlostDate BETWEEN @FDate AND @TDate
							AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					) b
					OUTER APPLY
					(
						SELECT d.Amount * e.Rate AS Amount
						FROM dbo.DepositInfo d WITH (NOLOCK)
							INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId
								AND CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) BETWEEN e.FromDate AND e.ToDate
						WHERE c.CustId = d.CustId AND d.FirstDeposit = 1 AND d.Status = 3
							AND d.WinlostDate BETWEEN @FDate AND @TDate
							AND d.CreateTime >= @FromDateTimeGMT AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					) d
				WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND c.SiteId = @SiteId
					AND c.IsTest = 0
			) r
		) t
		WHERE RowId BETWEEN @RowStart AND @RowEnd
		
		DROP TABLE #Affiliate
		DROP TABLE #Exchange
	END
END
GO