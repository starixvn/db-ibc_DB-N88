/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_Deposit]
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
	Created: 20201215@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Deposit

	Revisions:
		- 20201215@Percy: Initialize SP [RedmineID: #146760]
		- 20201229@Sol: change text from "Credit Site" to "Bong88/Viva88" - [RedmineID: #147542]
		- 20210113@Percy: Add 'APP' signup url [RedmineID: #148616]
		- 20210401@Percy: Add Number of Players column [RedmineID: #150876]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211008@Sol: MPA - Marketing & WL Analysis - Add more Info - [RedmineID: #159910]
		- 20220214@Percy: Apply SignupURL function [RedmineID: #164724]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230406@Malcolm: Using Actual Deposit instead of Amount for Deposit Info [RedmineId: #186439]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFromDate DATE, @tmpToDate DATE, @TpCurrencyIds VARCHAR(MAX)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @DepositAmount MONEY, @CompareDepositAmount MONEY

	CREATE TABLE #TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT)
	CREATE TABLE #DepositInfo (CustId INT, FirstDepositAmount MONEY, TotalDepositAmount MONEY, IsCompared BIT)

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
				,@CompareFromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
				,@CompareToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))

		-- Get data
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)
		
			DELETE #TpExchange
			INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate)
			SELECT FromDate, ToDate, ISNULL(Tp.TpExchangeID, e.ExchangeId), Rate / CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END 
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
				LEFT JOIN dbo.TpExchange Tp WITH(NOLOCK) ON Tp.ExchangeId = e.ExchangeId
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
			
			INSERT INTO #DepositInfo (CustId, FirstDepositAmount, TotalDepositAmount, IsCompared)
			SELECT d.CustId, SUM(d.FirstDepositAmount * e.Rate), SUM(d.TotalDepositAmount * e.Rate), 0 AS IsCompared
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(CASE WHEN FirstDeposit = 1 THEN ActualDeposit ELSE 0 END) AS FirstDepositAmount
					,SUM(ActualDeposit) AS TotalDepositAmount
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
					AND Status = 3 -- Approved
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) d
				INNER JOIN #TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.CustId
		END
		
		-- Get data for compare
		BEGIN
			SELECT @tmpFromDate = DATEADD(DAY, -1, @CompareFromDate), @tmpToDate = DATEADD(DAY, 1, @CompareToDate)
		
			DELETE #TpExchange
			INSERT INTO #TpExchange (FromDate, ToDate, TpExchangeId, Rate)
			SELECT FromDate, ToDate, ISNULL(Tp.TpExchangeID, e.ExchangeId), Rate / CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END 
			FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
				LEFT JOIN dbo.TpExchange Tp WITH(NOLOCK) ON Tp.ExchangeId = e.ExchangeId
			WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
			
			INSERT INTO #DepositInfo (CustId, FirstDepositAmount, TotalDepositAmount, IsCompared)
			SELECT d.CustId, SUM(d.FirstDepositAmount * e.Rate), SUM(d.TotalDepositAmount * e.Rate), 1 AS IsCompared
			FROM (
				SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
					,SUM(CASE WHEN FirstDeposit = 1 THEN ActualDeposit ELSE 0 END) AS FirstDepositAmount
					,SUM(ActualDeposit) AS TotalDepositAmount
				FROM dbo.DepositInfo d WITH (NOLOCK)
				WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
					AND CreateTime >= @CompareFromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND SiteId = @SiteId
					AND Status = 3 -- Approved
					AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
			) d
				INNER JOIN #TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			GROUP BY d.CustId
		END

		-- Summary
		SELECT SUM(CASE WHEN d.IsCompared = 0 THEN d.TotalDepositAmount ELSE 0 END) AS DepositAmount,SUM(CASE WHEN d.IsCompared = 1 THEN d.TotalDepositAmount ELSE 0 END) AS CompareDepositAmount
		FROM #DepositInfo d
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
		WHERE 
			c.IsTest = 0
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'

		-- Detail by Signup URL
		CREATE TABLE #Affiliate (CustId INT)
		DECLARE @MainURL VARCHAR(200)
		
		IF @SiteId = 1
		BEGIN
			SELECT @MainURL = 'Nova88.net'
			
			INSERT INTO #Affiliate (CustId)
			SELECT CustId
			FROM Affiliate_N88.dbo.MemberInfo WITH (NOLOCK)
		END
		ELSE IF @SiteId = 2
		BEGIN
			SELECT @MainURL = 'Goal123.com'
			
			INSERT INTO #Affiliate (CustId)
			SELECT CustId
			FROM Affiliate_N8G.dbo.MemberInfo WITH (NOLOCK)
		END
		ELSE IF @SiteId = 3
		BEGIN
			SELECT @MainURL = 'Bwing.com'
			
			INSERT INTO #Affiliate (CustId)
			SELECT CustId
			FROM Affiliate_N8B.dbo.MemberInfo WITH (NOLOCK)
		END

		SELECT
			CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
				WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN @MainURL
				WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
				WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
				ELSE 'None' END AS SignUpSource
			,CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
				WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN 'www.bwing.com'
				WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
				ELSE cg.SignupUrl END AS SignupUrl
			,SUM(d.FirstDepositAmount) AS FirstDepositAmount
			,SUM(d.TotalDepositAmount) AS TotalDepositAmount
			,COUNT(DISTINCT d.CustId) AS DeposiTplayers
		FROM #DepositInfo d
			INNER JOIN dbo.Customer c with (nolock) on d.CustId = c.CustId
			INNER JOIN dbo.Customer ag with (nolock) on c.AgentId = ag.CustId
			LEFT JOIN dbo.CustRegInfo cg with (nolock) on c.CustId = cg.CustId
			LEFT JOIN dbo.N88_f_SignupURL() s ON cg.SignupUrl = s.SignupUrl AND s.SiteId = @SiteId
			LEFT JOIN #Affiliate a ON d.CustId = a.CustId
		WHERE d.IsCompared = 0
			AND c.SiteId = @SiteId
			AND c.IsTest = 0
			AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
		GROUP BY
			CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
				WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) OR (s.GroupId = 3 AND s.SignupURL IS NOT NULL) THEN @MainURL
				WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
				WHEN cg.CustId IS NOT NULL THEN 'Landing Pages'
				ELSE 'None' END
			,CASE
				WHEN a.CustId IS NOT NULL THEN 'AFF'
				WHEN ag.UserName IN ('Goal123Ref01', 'BwingRef01') THEN 'Bong88/Viva88'
				WHEN ag.UserName IN ('Nova88Ref05', 'Nova88Ref06', 'Nova88Ref07', 'Nova88Ref08') THEN 'Nova88.com'
				WHEN (c.RegTime < '2020-08-20' AND cg.CustId IS NULL AND c.SiteId = 3) THEN 'www.bwing.com'
				WHEN s.GroupId = 4 AND s.SignupURL IS NOT NULL THEN 'APP'
				ELSE cg.SignupUrl END

		DROP TABLE #Affiliate
		DROP TABLE #DepositInfo
		DROP TABLE #TpExchange
	END
END
GO