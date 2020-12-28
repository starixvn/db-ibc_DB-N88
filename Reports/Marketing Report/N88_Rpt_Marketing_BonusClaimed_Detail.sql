/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BonusClaimed_Detail]
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
	Task: MPA - Marketing Report - Bonus Info - View detail

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20201215@Percy: Fix sort on Deposit & Withdrawal Amount [RedmineID: #146760]

	Param's Explanation:
		@SortbyId:
			. 1 = Campaign
			. 2 = Username
			. 3 = Registered Date
			. 4 = Deposit Amount
			. 5 = Withdrawal Amount
			. 6 = Bonus Amount Claimed
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
				SELECT b.BonusCode
				FROM dbo.BonusInfo b WITH (NOLOCK)
				WHERE c.CustId = b.CustId
					AND b.WinlostDate BETWEEN @FDate AND @TDate
					AND b.SiteId = @SiteId
					AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				GROUP BY b.BonusCode
			) b
		WHERE c.SiteId = @SiteId
			AND c.IsTest = 0
			AND b.BonusCode IS NOT NULL

		CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')

		DECLARE @RowStart INT, @RowEnd INT
		SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

		-- Detail by Campaign, User
		CREATE TABLE #DepositInfo (CustId INT, CurrencyId INT, WinlostDate DATE, Amount MONEY)
		INSERT INTO #DepositInfo (CustId, CurrencyId, WinlostDate, Amount)
		SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
		FROM dbo.DepositInfo WITH (NOLOCK)
		WHERE WinlostDate BETWEEN @FDate AND @TDate
			AND SiteId = @SiteId
			AND Status = 3
			AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
		GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

		CREATE TABLE #WithdrawalInfo (CustId INT, CurrencyId INT, WinlostDate DATE, Amount MONEY)
		INSERT INTO #WithdrawalInfo (CustId, CurrencyId, WinlostDate, Amount)
		SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
		FROM dbo.WithdrawalInfo WITH (NOLOCK)
		WHERE WinlostDate BETWEEN @FDate AND @TDate
			AND SiteId = @SiteId
			AND Status = 6
			AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
		GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

		SELECT RowId, BonusCode, UserName, RegTime, DepositAmount, WithdrawalAmount, BonusAmount 
		FROM (
			SELECT b.BonusCode, c.Username, DATEADD(HOUR, @TimeZone, c.RegTime) AS RegTime, d.DepositAmount, w.WithdrawalAmount, b.BonusAmount
				,ROW_NUMBER() OVER(ORDER BY
						 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN b.BonusCode END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN b.BonusCode END DESC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN c.Username END ASC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN c.Username END DESC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN c.RegTime END ASC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN c.RegTime END DESC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN ISNULL(d.DepositAmount, 0) END ASC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN ISNULL(d.DepositAmount, 0) END DESC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN ISNULL(w.WithdrawalAmount, 0) END ASC
						,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN ISNULL(w.WithdrawalAmount, 0) END DESC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN b.BonusAmount END ASC
						,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN b.BonusAmount END DESC) AS RowId
			FROM dbo.Customer c WITH (NOLOCK)
				CROSS APPLY (
					SELECT b.BonusCode, SUM(b.BonusAmount * e.Rate / CASE WHEN b.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS BonusAmount
					FROM dbo.BonusInfo b WITH (NOLOCK)
						INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId
							AND CONVERT(DATE, DATEADD(HOUR, -4, b.CreateTime)) BETWEEN e.FromDate AND e.ToDate
					WHERE c.CustId = b.CustId
						AND b.WinlostDate BETWEEN @FDate AND @TDate
						AND b.SiteId = @SiteId
						AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					GROUP BY b.BonusCode
				) b
				OUTER APPLY
				(
					SELECT SUM(d.Amount * e.Rate / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS DepositAmount
					FROM #DepositInfo d
						INNER JOIN #Exchange e ON d.WinlostDate BETWEEN e.FromDate AND e.ToDate AND d.CurrencyId = e.ExchangeId
					WHERE c.CustId = d.CustId
				) d
				OUTER APPLY
				(
					SELECT SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS WithdrawalAmount
					FROM #WithdrawalInfo w
						INNER JOIN #Exchange e ON w.WinlostDate BETWEEN e.FromDate AND e.ToDate AND w.CurrencyId = e.ExchangeId
					WHERE c.CustId = w.CustId
				) w
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
		) t
		WHERE RowId BETWEEN @RowStart AND @RowEnd

		DROP TABLE #Exchange
		DROP TABLE #DepositInfo
		DROP TABLE #WithdrawalInfo
	END
END
GO