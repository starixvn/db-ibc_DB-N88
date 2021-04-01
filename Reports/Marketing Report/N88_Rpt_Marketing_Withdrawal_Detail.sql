/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Withdrawal_Detail]
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
	Task: MPA - Marketing Report - Withdrawal Info - View detail

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20210401@Percy: Add Currency column [RedmineID: #150876]

	Param's Explanation:
		@SortbyId:
			. 1 = Username
			. 2 = Registered Date
			. 3 = BetCount
			. 4 = WithdrawalAmount
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME

	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

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
			CROSS APPLY
			(
				SELECT TOP 1 w.CustId
				FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				WHERE c.CustId = w.CustId
					AND w.WinlostDate BETWEEN @FDate AND @TDate
					AND w.SiteId = @SiteId
					AND w.Status = 6
					AND w.CreateTime >= @FromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			) w
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND w.CustId IS NOT NULL
		
		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')
		
		DECLARE @RowStart INT, @RowEnd INT
		SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

		-- Detail by User
		CREATE TABLE #WithdrawalInfo (CustId INT, Amount MONEY, BetCount INT)
		INSERT INTO #WithdrawalInfo (CustId, Amount, BetCount)
		SELECT w.CustId, SUM(w.Amount * e.Rate), SUM(w.BetCount)
		FROM (
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate, SUM(Amount) AS Amount, COUNT(1) AS BetCount
			FROM dbo.WithdrawalInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND SiteId = @SiteId
				AND Status = 6
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) w
			INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY w.CustId

		SELECT RowId, UserName, Currency, RegTime, NoOfWithdrawals, TotalWithdrawalAmount
		FROM (
			SELECT c.UserName, e.Code AS Currency, DATEADD(HOUR, @Timezone, c.RegTime) AS RegTime, w.BetCount AS NoOfWithdrawals, w.Amount AS TotalWithdrawalAmount
				,ROW_NUMBER() OVER(ORDER BY
						 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN c.Username END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN c.Username END DESC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN c.RegTime END ASC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN c.RegTime END DESC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN c.RegTime END ASC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN c.RegTime END DESC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN w.BetCount END ASC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN w.BetCount END DESC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN w.Amount END ASC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN w.Amount END DESC) AS RowId
			FROM dbo.Customer c WITH (NOLOCK)
				INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON c.CurrencyId = e.ExchangeId
				INNER JOIN #WithdrawalInfo w ON c.CustId = w.CustId
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
		) r
		WHERE RowId BETWEEN @RowStart AND @RowEnd

		DROP TABLE #Exchange
		DROP TABLE #WithdrawalInfo
	END
END
GO