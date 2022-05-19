/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="1"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_CustBonusSummary_Sel]
	@SiteId				INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			INT = 8
	,@GetByDate			BIT = 0
AS

/*
	Created: 20220412@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Get Bonus Info

	Revisions:
		- 20220412@Percy: Initialize SP [RedmineID: #171245]
*/

BEGIN
	SET NOCOUNT ON

	-- Data on GMT+0 --> convert timezone
	DECLARE @FromDateTimeGMT0 DATETIME, @ToDateTimeGMT0 DATETIME
	SELECT	@FromDateTimeGMT0 = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT0 = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

	-- Get Exchange
	DECLARE @tmpFDate DATE = DATEADD(DAY, -1, @FromDate), @tmpTDate DATE = DATEADD(DAY, 1, @ToDate)
	
	CREATE TABLE #__Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
	INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeId, Rate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFDate, @tmpTDate, @DisplayCurrency, '') e
	WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

	SELECT b.BonusDate, b.DataSource, b.BonusType
		,CONVERT(VARCHAR(100), ISNULL(ISNULL(ISNULL(ed.EventName, b.BonusCode), bt.BonusTypeName), 'Unidentified')) AS BonusCode
		,CONVERT(VARCHAR(300), ISNULL(ed.EventName, p.Description)) AS BonusName, b.BonusStatus
		,b.CustId, b.CurrencyId
		,SUM(BetCount), SUM(b.BonusAmount) AS BonusAmount, SUM(b.BonusAmount * e.Rate) AS BasedBonusAmount
	FROM (
		SELECT b.DataSource, b.BonusType, b.BonusCode, b.BonusStatus, b.CustId, b.CurrencyId
			,CASE WHEN @GetByDate = 1 THEN CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.BonusTime)) ELSE @FromDate END AS BonusDate
			,CONVERT(DATE, DATEADD(HOUR, -4, b.BonusTime)) AS ExchangeDate
			,CONVERT(INT, CASE WHEN b.DataSource = 'DrawLog' THEN b.BonusCode END) AS EventId
			,COUNT(1) AS BetCount
			,SUM(b.BonusAmount * CASE
									WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusType IN (1, 3) THEN 1 -- Credit, Increase bonus
									WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusType IN (2, 4) THEN -1 -- Debit, Decrease bonus
									WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusType = 1 THEN 1 -- 3rd Add
									WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusType = 2 THEN -1 -- 3rd Minus
									ELSE 1 END) AS BonusAmount
		FROM dbo.CustBonusSummary b WITH (NOLOCK)
		WHERE b.BonusTime >= @FromDateTimeGMT0 AND b.BonusTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
			AND b.SiteId = @SiteId
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.CurrencyId) + ',%'
			AND 1 = CASE
						WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusStatus <> 2 THEN 0 -- 2 = Approved
						WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusStatus <> 0 THEN 0 -- 0 = Success
						WHEN b.DataSource = 'VipUpgradeReview' AND b.BonusStatus <> 4 THEN 0 -- 4 = Settled
						ELSE 1 END
			AND 1 = CASE WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusTime >= '2021-10-31 16:00' AND b.BonusType IN (1, 2) THEN 0 ELSE 1 END -- From 1 Nov 2021 (GMT+8), don't get Credit & Debit
			AND 1 = CASE WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusTime >= '2021-10-31 16:00' THEN 0 ELSE 1 END -- only get LogAdminAdjustWallet data before 1 Nov 2021 (GMT+8)
		GROUP BY CASE WHEN @GetByDate = 1 THEN CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.BonusTime)) ELSE @FromDate END
			,b.DataSource, b.BonusType, b.BonusCode, b.BonusStatus, b.CustId, b.CurrencyId
			,CASE WHEN @GetByDate = 1 THEN CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.BonusTime)) ELSE @FromDate END
			,CONVERT(DATE, DATEADD(HOUR, -4, b.BonusTime))
			,CONVERT(INT, CASE WHEN b.DataSource = 'DrawLog' THEN b.BonusCode END)
	) b
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId AND c.IsTest = 0
		INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		LEFT JOIN dbo.N88_f_BonusType() bt ON b.DataSource = bt.DataSource AND ISNULL(b.BonusType, 0) = bt.DBTypeId
		LEFT JOIN dbo.Promotion p WITH (NOLOCK) ON b.BonusCode = p.BonusCode AND p.SiteId = @SiteId AND b.DataSource IN ('BonusInfo', 'RebateMLog')
		LEFT JOIN dbo.EventDraw ed WITH (NOLOCK) ON b.EventId = ed.EventId AND ed.SiteId = @SiteId AND b.DataSource IN ('DrawLog')
	WHERE b.DataSource IN ('BonusInfo', 'RebateMLog', 'DrawLog') OR bt.DataSource IS NOT NULL
	GROUP BY  b.BonusDate, b.DataSource, b.BonusType
		,CONVERT(VARCHAR(100), ISNULL(ISNULL(ISNULL(ed.EventName, b.BonusCode), bt.BonusTypeName), 'Unidentified'))
		,CONVERT(VARCHAR(300), ISNULL(ed.EventName, p.Description)), b.BonusStatus
		,b.CustId, b.CurrencyId
END
GO