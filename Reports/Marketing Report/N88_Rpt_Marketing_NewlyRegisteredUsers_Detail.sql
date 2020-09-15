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

		SELECT RowId, BonusCode, UserName, RegTime, SignupUrl, IsDeposit, FirstDepositAmount 
		FROM (
			SELECT b.BonusCode, c.UserName, c.RegTime
				,CASE WHEN c.RegTime < '2020-08-20' AND cg.CustId IS NULL THEN @DefaultSignupUrl ELSE cg.SignupUrl END AS SignupUrl
				,CASE WHEN d.Amount IS NULL THEN 0 ELSE 1 END AS IsDeposit
				,d.Amount AS FirstDepositAmount
				,ROW_NUMBER() OVER(ORDER BY
						 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN b.BonusCode END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN b.BonusCode END DESC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN c.Username END ASC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN c.Username END DESC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN c.RegTime END ASC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN c.RegTime END DESC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN cg.SignupUrl END ASC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN cg.SignupUrl END DESC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN CASE WHEN d.Amount IS NULL THEN 0 ELSE 1 END END ASC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN CASE WHEN d.Amount IS NULL THEN 0 ELSE 1 END END DESC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN d.Amount END ASC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN d.Amount END DESC) AS RowId
			FROM dbo.Customer c WITH (NOLOCK)
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
		WHERE RowId BETWEEN @RowStart AND @RowEnd

		DROP TABLE #Exchange
	END
END
GO