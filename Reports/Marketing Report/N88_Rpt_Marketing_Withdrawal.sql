/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Withdrawal]
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
	Task: MPA - Marketing Report - Withdrawal Info

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230705@Sally: Exclude data of Live Streamer [RedmineId: #189299]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE, @TpCurrencyIds VARCHAR(MAX)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @WithdrawalAmount MONEY, @CompareWithdrawalAmount MONEY
			,@WithdrawalUsers INT, @CompareWithdrawalUsers INT

	CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT)

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
				,@CompareFromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
				,@CompareToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))

		-- Get data
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
			
			DELETE #TpExchange
			INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate)
			SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), Rate 
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

			SELECT @WithdrawalAmount = SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
				,@WithdrawalUsers = COUNT(DISTINCT w.CustId)
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
				INNER JOIN #TpExchange e ON w.CurrencyId = e.TpExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE w.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND w.CreateTime >= @FromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND w.SiteId = @SiteId
				AND w.Status = 6
				AND c.IsTest = 0
				AND c.MemberType <> 3 -- Exclude Live Streamer
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
		END

		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
		
			DELETE #TpExchange
			INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate)
			SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), Rate 
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
		
			SELECT @CompareWithdrawalAmount = SUM(w.Amount * e.Rate / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END)
				,@CompareWithdrawalUsers = COUNT(DISTINCT w.CustId)
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
				INNER JOIN #TpExchange e ON w.CurrencyId = e.TpExchangeId
					AND CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) BETWEEN e.FromDate AND e.ToDate
			WHERE w.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND w.CreateTime >= @CompareFromDateTimeGMT AND w.CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
				AND w.SiteId = @SiteId
				AND w.Status = 6
				AND c.IsTest = 0
				AND c.MemberType <> 3 -- Exclude Live Streamer
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
		END
	END

	SELECT
		@WithdrawalAmount AS WithdrawalAmount
		,@CompareWithdrawalAmount AS CompareWithdrawalAmount
		,@WithdrawalUsers AS WithdrawalUsers
		,@CompareWithdrawalUsers AS CompareWithdrawalUsers
	
	DROP TABLE #TpExchange
END
GO