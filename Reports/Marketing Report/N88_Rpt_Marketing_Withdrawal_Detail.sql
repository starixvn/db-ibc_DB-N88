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
		SELECT FromDate, ToDate, ExchangeId, Rate FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '')
		
		DECLARE @RowStart INT, @RowEnd INT
		SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

		-- Detail by User
		SELECT RowId, UserName, RegTime, BetCount, WithdrawalAmount
		FROM (
			SELECT c.UserName, DATEADD(HOUR, @Timezone, c.RegTime) AS RegTime, BetCount, WithdrawalAmount
				,ROW_NUMBER() OVER(ORDER BY
						 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN c.Username END ASC
						,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN c.Username END DESC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN c.RegTime END ASC
						,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN c.RegTime END DESC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN w.BetCount END ASC
						,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN w.BetCount END DESC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN w.WithdrawalAmount END ASC
						,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN w.WithdrawalAmount END DESC) AS RowId
			FROM dbo.Customer c WITH (NOLOCK)
				CROSS APPLY
				(
					SELECT COUNT(1) AS BetCount, SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS WithdrawalAmount
					FROM dbo.WithdrawalInfo w WITH (NOLOCK)
						INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId
							AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
					WHERE c.CustId = w.CustId
						AND w.WinlostDate BETWEEN @FDate AND @TDate
						AND w.SiteId = @SiteId
						AND w.Status = 6
						AND w.CreateTime >= @FromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				) w
			WHERE c.SiteId = @SiteId
				AND c.IsTest = 0
				AND ISNULL(w.BetCount, 0) > 0
		) r
		WHERE RowId BETWEEN @RowStart AND @RowEnd

		DROP TABLE #Exchange
	END
END
GO