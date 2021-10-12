/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_BonusInfo_Detail]
	@LicenseeId			INT
	,@BonusTypeId		SMALLINT = 0
	,@BonusCode			VARCHAR(50)
	,@ClaimedStatusIds	VARCHAR(MAX) = ''
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
	Created: 20200105@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200105@Percy: Initialize SP [RedmineID: #146759]
		- 20210629@Sol: MPA - Apply Currency permission - [RedmineID: #157588]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]

	Param's Explanation:
		@SortbyId:
			. 1 = Username
			. 2 = Claim Date
			. 3 = Bonus Amount Claimed
			. 4 = Deposit Amount
			. 5 = Withdrawal Amount
			. 6 = Status
			. 7 = Percent Completion
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @DataSource VARCHAR(100)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @tmpFromDate DATE, @tmpToDate DATE
	CREATE TABLE #Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)

	CREATE TABLE #BonusInfo (CustId INT, CurrencyId INT, Status TINYINT, ExchangeDate DATE, ClaimedDate DATETIME, Amount MONEY, PercentagedCompletion FLOAT DEFAULT (1))
	CREATE TABLE #DepositInfo (CustId INT, CurrencyId INT, ExchangeDate DATE, Amount MONEY)
	CREATE TABLE #WithdrawalInfo (CustId INT, CurrencyId INT, ExchangeDate DATE, Amount MONEY)

	BEGIN
		IF @BonusTypeId <> 0
			SELECT @DataSource = DataSource FROM dbo.N88_f_BonusType () WHERE BonusTypeId = @BonusTypeId

		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)

		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate / CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		-- BonusInfo
		IF @BonusTypeId = 0 OR @DataSource = 'BonusInfo'
		BEGIN
			INSERT INTO #BonusInfo (CustId, CurrencyId, Status, ExchangeDate, ClaimedDate, Amount, PercentagedCompletion)
			SELECT b.CustId, b.CurrencyId, b.Status, DATEADD(HOUR, -4, b.CreateTime), DATEADD(HOUR, @TimeZone, b.CreateTime), b.BonusAmount
				,CASE
					WHEN cbr.Turnover > cbr.Rollover THEN 1.0
					WHEN cbr.Rollover = 0 THEN 0.0
					ELSE cbr.Turnover / cbr.Rollover END AS PercentagedCompletion
			FROM dbo.BonusInfo b WITH (NOLOCK)
				LEFT JOIN dbo.CustBonusRollover cbr WITH (NOLOCK) ON b.BonusId = cbr.BonusId
			WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND b.BonusCode = @BonusCode
				AND ',' + @ClaimedStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.Status) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.CurrencyId) + ',%'
		END

		-- RebateMLog
		IF @BonusTypeId = 0 OR @DataSource = 'RebateMLog'
		BEGIN
			INSERT INTO #BonusInfo (CustId, CurrencyId, ExchangeDate, ClaimedDate, Amount, PercentagedCompletion)
			SELECT CustId, CurrencyId, DATEADD(HOUR, -4, CreateTime), DATEADD(HOUR, @TimeZone, CreateTime), RedeemAmount
				,CASE WHEN BonusCode = 'VipRebate' THEN 1 ELSE 0 END
			FROM dbo.RebateMLog WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND BonusCode = @BonusCode
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
		END

		-- DrawLog
		IF @DataSource = 'DrawLog'
		BEGIN
			INSERT INTO #BonusInfo (CustId, CurrencyId, ExchangeDate, ClaimedDate, Amount)
			SELECT d.CustId, d.CurrencyId, DATEADD(HOUR, -4, d.DrawTime), DATEADD(HOUR, @TimeZone, d.DrawTime), d.Amount
			FROM dbo.DrawLog d WITH (NOLOCK)
				INNER JOIN dbo.EventDraw e WITH (NOLOCK) ON d.EventId = e.EventId
			WHERE d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND d.DrawTime >= @FromDateTimeGMT AND d.DrawTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND d.SiteId = @SiteId
				AND e.SiteId = @SiteId
				AND e.EventName = @BonusCode
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
		END

		-- AdjustmentInfo
		IF @DataSource = 'AdjustmentInfo'
		BEGIN
			INSERT INTO #BonusInfo (CustId, CurrencyId, ExchangeDate, ClaimedDate, Amount)
			SELECT CustId, CurrencyId, DATEADD(HOUR, -4, CreateTime), DATEADD(HOUR, @TimeZone, CreateTime)
				,Amount * CASE
							WHEN AdjustType IN (1, 4) THEN -1 -- Debit, Decrease bonus
							WHEN AdjustType IN (2, 3) THEN 1 -- Credit, Increase bonus
							ELSE 0 END
			FROM dbo.AdjustmentInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 2 -- Approved
		END

		-- VIPUpgradeReview
		IF @DataSource = 'VIPUpgradeReview'
		BEGIN
			INSERT INTO #BonusInfo (CustId, CurrencyId, ExchangeDate, ClaimedDate, Amount)
			SELECT CustId, CurrencyId, DATEADD(HOUR, -4, SettleTime), DATEADD(HOUR, @TimeZone, SettleTime), UpgradeAmount
			FROM dbo.VipUpgradeReview WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND SettleTime >= @FromDateTimeGMT AND SettleTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND SiteId = @SiteId
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 4 -- Settled
		END

		-- Deposit, Withdrawal
		BEGIN
			INSERT INTO #DepositInfo (CustId, CurrencyId, ExchangeDate, Amount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
			FROM dbo.DepositInfo d WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND Status = 3 -- Approved
				AND SiteId = @SiteId
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

			INSERT INTO #WithdrawalInfo (CustId, CurrencyId, ExchangeDate, Amount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND Status = 6 -- Approved
				AND SiteId = @SiteId
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		END

		DELETE b
		FROM #BonusInfo b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
		WHERE c.IsTest = 1

		DELETE #DepositInfo WHERE CustId NOT IN (SELECT CustId FROM #BonusInfo)
		DELETE #WithdrawalInfo WHERE CustId NOT IN (SELECT CustId FROM #BonusInfo)

		UPDATE b
		SET b.Amount = b.Amount * e.Rate
		FROM #BonusInfo b
			INNER JOIN #Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate

		UPDATE d
		SET d.Amount = d.Amount * e.Rate
		FROM #DepositInfo d
			INNER JOIN #Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate

		UPDATE w
		SET w.Amount = w.Amount * e.Rate
		FROM #WithdrawalInfo w
			INNER JOIN #Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
	END

	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @NRows = COUNT(1) FROM #BonusInfo

	-- Return
	SELECT RowId, UserName, @BonusCode AS BonusCode, ClaimedDate, ClaimedAmount, TotalDeposit, TotalWithdrawal, Status, PercentagedCompletion
	FROM (
		SELECT UserName, ClaimedDate, ClaimedAmount, TotalDeposit, TotalWithdrawal, Status, PercentagedCompletion
			,ROW_NUMBER() OVER(ORDER BY
							 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN UserName END ASC
							,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN UserName END DESC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN ClaimedDate END ASC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN ClaimedDate END DESC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN ClaimedAmount END ASC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN ClaimedAmount END DESC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN TotalDeposit END ASC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN TotalDeposit END DESC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN TotalWithdrawal END ASC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN TotalWithdrawal END DESC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN Status END ASC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN Status END DESC
							,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN PercentagedCompletion END ASC
							,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN PercentagedCompletion END DESC) AS RowId
		FROM (
		SELECT c.UserName, b.ClaimedDate, b.Amount AS ClaimedAmount, ISNULL(d.Amount, 0) AS TotalDeposit, ISNULL(w.Amount, 0) AS TotalWithdrawal, b.Status, ISNULL(b.PercentagedCompletion, 0) AS PercentagedCompletion
		FROM dbo.Customer c WITH (NOLOCK)
			INNER JOIN #BonusInfo b ON b.CustId = c.CustId
			LEFT JOIN (
				SELECT d.CustId, SUM(d.Amount) AS Amount
				FROM #DepositInfo d
				GROUP BY d.CustId
			) d ON d.CustId = c.CustId
			LEFT JOIN (
				SELECT w.CustId, SUM(w.Amount) AS Amount
				FROM #WithdrawalInfo w
				GROUP BY w.CustId
			) w ON w.CustId = c.CustId
		) t
	) r
	WHERE RowId BETWEEN @RowStart AND @RowEnd
	ORDER BY RowId

	DROP TABLE #BonusInfo
	DROP TABLE #DepositInfo
	DROP TABLE #Exchange
	DROP TABLE #WithdrawalInfo
END
GO