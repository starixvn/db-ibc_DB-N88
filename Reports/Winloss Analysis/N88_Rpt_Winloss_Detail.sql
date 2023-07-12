/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_Winloss_Detail]
	@LicenseeIds				VARCHAR(MAX)
	,@FilterBy					TINYINT
	,@GroupBy					TINYINT
	,@FromDate					DATE
	,@ToDate					DATE
	,@ProductIds				VARCHAR(MAX)
	,@UserNameFilterId			TINYINT = 1
	,@UserName					VARCHAR(30) = ''
	,@CurrencyIds				VARCHAR(MAX)
	,@DisplayCurrency			VARCHAR(3)
	,@IsIncludedFreeSpin		BIT
	,@IsNoDrawTicket			BIT
	,@IsIncludedTestData		BIT
	,@IsDetailInOriginalCurr	BIT = 0
	,@TimeZone					SMALLINT = 8
	,@DataLimitBy				INT= 0
	,@IsDataLimitDesc			INT = 0
	,@DataLimitValue			INT = 0
AS

/*
	Created: 20210305@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Winloss Analysis
	
	Revisions:
		- 20210305@Percy: Initialize [Redmine:#151187]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - include free spin filter - [RedmineID: #155334]
		- 20210715@Percy: Exclude Jackpot, Contribition from Win Loss (GGR) [RedmineID: #158438]
		- 20220518@Percy: Add Commission for 9W Sports [RedmineID: #172917]
		- 20220608@Percy: Update GGR formula for 9W Sports [RedmineID: #173396]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230406@Malcolm: Using Actual Deposit instead of Amount for Deposit Info [RedmineId: #186439]
		- 20230704@Sally: Exclude data of Live Streamer [RedmineId: #189299]
		- 20230710@Sally: Data Limits by top/bottom X player [RedmineId: #189299]
		
	Param's Explanation:
		@DataLimitBy:
			.  0 =  data with no limit 
			.  1 =  data limit by Turnover
			.  2 =  data limit by GGR
			.  3 =  data limit by BetCount
			.  4 =  data limit by AvgBet Amount
		@IsDataLimitDesc
			.  0 =  Top
			.  1 =  Bottom
		@DataLimitValue: Top/bottom X player
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FDate DATE, @TDate DATE, @TpCurrencyIds VARCHAR(MAX)
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	-- Data on GMT+0 --> convert timezone
	DECLARE @FromDateTimeGMT0 DATETIME, @ToDateTimeGMT0 DATETIME
	SELECT  @FromDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

	DECLARE @SiteIds VARCHAR(MAX)
	SELECT  @SiteIds = COALESCE(@SiteIds + ',', '') + CONVERT(VARCHAR(15), s.SiteId)
	FROM dbo.ServerInfo s WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
	WHERE ',' + @LicenseeIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), l.LicenseeId) + ',%'

	-- 1. Get raw data
	CREATE TABLE #__N88_SumWinloss
	(
		rptDate						DATE
		,GameType					INT
		,CustId						INT
		,CurrencyId					INT
		,BetCount					INT
		,TurnOver					MONEY
		,NetTurnOver				MONEY
		,NetTurnOverForMargin		MONEY
		,Revenue					MONEY
		,RevenueForMargin			MONEY
		,Winloss					MONEY
		,ProgressiveWin				MONEY
		,ProgressiveBet				MONEY
		,Commission					MONEY
		,NumberOfDeposit			INT
		,DepositAmount				MONEY
		,NumberOfWithdrawal			INT
		,WithdrawalAmount			MONEY
		,IsDepositWithrawUser		BIT DEFAULT (0)
	)
	CREATE CLUSTERED INDEX CIX_N88_SumWinloss ON #__N88_SumWinloss (CustId)

	CREATE TABLE #__TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT, MultipleBy FLOAT)
	CREATE CLUSTERED INDEX CIX_Exchange ON #__TpExchange (TpExchangeId, FromDate)
	
	DECLARE @MinDate DATE, @MaxDate DATE, @TicketStatus VARCHAR(50) = '1,2' -- win, loss

	SELECT @TicketStatus = @TicketStatus + CASE WHEN @IsNoDrawTicket = 0 THEN ',4' ELSE '' END -- draw ticket
	SELECT @TicketStatus = @TicketStatus + CASE WHEN @IsIncludedFreeSpin = 1 THEN ',6' ELSE '' END -- free spin ticket
	SELECT @TpCurrencyIds = 
	(
		SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(tp.TpExchangeId, t.Value)), ',')
		FROM STRING_SPLIT(@CurrencyIds, ',') t 
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = t.value
	)
	
	---- by winlostdate
	IF (@FilterBy = 1)
	BEGIN
		INSERT INTO #__TpExchange (FromDate, ToDate, TpExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), CASE WHEN @IsDetailInOriginalCurr = 0 THEN Rate ELSE 1 END, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_SumWinloss
		(
			rptDate, GameType, CustId, CurrencyId
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, Revenue, RevenueForMargin, Winloss, ProgressiveWin, ProgressiveBet
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
			,SUM(NetTurnOverForMargin * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(RevenueForMargin * e.Rate)
			,SUM(Winloss * e.Rate)
			,SUM(ProgressiveWin * e.Rate)
			,SUM(ProgressiveBet * e.Rate)
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,rptDate				= CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,r.CustId
				,r.Currency
				,r.GameType
				,TurnOver				= SUM(TurnOver)
				,NetTurnOver			= SUM(ValidBet)
				,NetTurnOverForMargin	= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE ValidBet END)
				,Revenue				= SUM(CASE WHEN r.GameType IN (41, 42) THEN ISNULL(Revenue, 0) ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,RevenueForMargin		= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,Winloss				= SUM(Winloss)
				,ProgressiveWin			= SUM(ISNULL(ProgressiveWin, 0))
				,ProgressiveBet			= SUM(ISNULL(ProgressiveBet, 0))
				,BetCount				= SUM(BetCount)
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.SettledTime >= @FromDateTimeGMT0 AND r.SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.SiteId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND ',' + @TicketStatus + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.StatusId) + ',%'
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND c.MemberType <> 3
				AND (
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime))
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,r.CustId
				,r.Currency
				,r.GameType
		) r
			INNER JOIN #__TpExchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.TpExchangeId
		GROUP BY rptDate, GameType, CustId, Currency

		-- Get commission for 9W (filter by winlostdate only)
		IF EXISTS (SELECT 1 FROM #__N88_SumWinloss WHERE GameType = 51)
		BEGIN
			DECLARE @FromDateTimeGMT8 DATETIME, @ToDateTimeGMT8 DATETIME -- data on GMT+8
			SELECT  @FromDateTimeGMT8		= DATEADD(HOUR, 8 - @TimeZone, CONVERT(DATETIME, @FromDate))
					,@ToDateTimeGMT8		= DATEADD(HOUR, 8 - @TimeZone, CONVERT(DATETIME, @ToDate))
			
			CREATE TABLE #__9W (CustId INT, rptDate DATE, Commission MONEY, BasedCommission MONEY)
			INSERT INTO #__9W (CustId, rptDate, Commission, BasedCommission)
			SELECT t.CustId, t.rptDate, SUM(t.Commission / e.MultipleBy), SUM(t.Commission * e.Rate / e.MultipleBy)
			FROM (
				SELECT CustId, CurrencyId, DATEADD(HOUR, -12, settledDate) AS ExchangeDate, CONVERT(DATE, DATEADD(HOUR, @TimeZone - 8, settledDate)) AS rptDate, SUM(Commission) AS Commission
				FROM dbo.TpReport9W WITH (NOLOCK)
				WHERE settledDate >= @FromDateTimeGMT8 AND settledDate < DATEADD(DAY, 1, @ToDateTimeGMT8)
				GROUP BY CustId, CurrencyId, DATEADD(HOUR, -12, settledDate), CONVERT(DATE, DATEADD(HOUR, @TimeZone - 8, settledDate))
			) t
				INNER JOIN #__TpExchange e ON t.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND t.CurrencyId = e.TpExchangeId
			GROUP BY t.CustId, t.rptDate

			UPDATE t
			SET t.Commission = -w.Commission, t.Revenue = t.Revenue - w.Commission, t.RevenueForMargin = t.RevenueForMargin - w.Commission
			FROM #__N88_SumWinloss t
				INNER JOIN #__9W w ON t.CustId = w.CustId AND t.rptDate = w.rptDate
			WHERE t.GameType = 51

			DROP TABLE #__9W
		END
	END
	---- by transdate
	ELSE 
	BEGIN
		SELECT @MinDate = MIN(CONVERT(DATE, SettledTime)), @MaxDate = MAX(CONVERT(DATE, SettledTime))
		FROM dbo.N88_SumWinloss WITH (NOLOCK) WHERE TransTime >= @FromDateTimeGMT0 AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)

		SELECT @MinDate = DATEADD(DAY, -1, @MinDate), @MaxDate = DATEADD(DAY, 1, @MaxDate)

		INSERT INTO #__TpExchange (FromDate, ToDate, TpExchangeId, Rate)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), CASE WHEN @IsDetailInOriginalCurr = 0 THEN Rate ELSE 1 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_SumWinloss
		(
			rptDate, GameType, CustId, CurrencyId
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, Revenue, RevenueForMargin, Winloss, ProgressiveWin, ProgressiveBet
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
			,SUM(NetTurnOverForMargin * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(RevenueForMargin * e.Rate)
			,SUM(Winloss * e.Rate)
			,SUM(ProgressiveWin * e.Rate)
			,SUM(ProgressiveBet * e.Rate)
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,rptDate				= CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,r.CustId
				,r.Currency
				,r.GameType
				,TurnOver				= SUM(TurnOver)
				,NetTurnOver			= SUM(ValidBet)
				,NetTurnOverForMargin	= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE ValidBet END)
				,Revenue				= SUM(CASE WHEN r.GameType IN (41, 42) THEN ISNULL(Revenue, 0) ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,RevenueForMargin		= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,Winloss				= SUM(Winloss)
				,ProgressiveWin			= SUM(ISNULL(ProgressiveWin, 0))
				,ProgressiveBet			= SUM(ISNULL(ProgressiveBet, 0))
				,BetCount				= SUM(BetCount)
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.TransTime >= @FromDateTimeGMT0 AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.SiteId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND ',' + @TicketStatus + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.StatusId) + ',%'
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND c.MemberType <> 3
				AND (
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime))
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,r.CustId
				,r.Currency
				,r.GameType
		) r
			INNER JOIN #__TpExchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.TpExchangeId
		GROUP BY rptDate, GameType, CustId, Currency
	END

	--Get data limits by player
	BEGIN
		CREATE TABLE #_ListPlayer (CustId INT)
		IF (@DataLimitBy <> 0)
		BEGIN
			;WITH CTE_Cust AS (
				SELECT CustId
					,CASE @DataLimitBy WHEN 1 THEN SUM(TurnOver)
										WHEN 2 THEN SUM(Revenue)
										WHEN 3 THEN SUM(BetCount)
										WHEN 4 THEN ISNULL(SUM(BasedNetTurnOver)/SUM(NULLIF(BetCount,0)), 0)
					END AS GroupAmount
				FROM  #__N88_SumWinloss
				GROUP BY CustId
			)
			INSERT INTO #_ListPlayer(CustId)
			SELECT TOP(@DataLimitValue) c.CustId	
			FROM CTE_Cust c
			ORDER BY
				CASE WHEN @IsDataLimitDesc =1 THEN GroupAmount END DESC
				,CASE WHEN @IsDataLimitDesc = 0 THEN GroupAmount END ASC
				,c.CustId 			
		END

		IF EXISTS (
			SELECT 1
			FROM #_ListPlayer
		)
		BEGIN
			DELETE n
			FROM #__N88_SumWinloss n
				LEFT JOIN #_ListPlayer l ON n.CustId = l.CustId
			WHERE l.CustId IS NULL
		END 
	END

	-- Reset Exchange
	DELETE #__TpExchange
	INSERT INTO #__TpExchange (FromDate, ToDate, TpExchangeId, Rate, MultipleBy)
	SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), CASE WHEN @IsDetailInOriginalCurr = 0 THEN Rate ELSE 1 END, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
	WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
	
	-- Deposit/Withdrawal
	BEGIN 
		-- Deposit
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, NumberOfDeposit, DepositAmount, IsDepositWithrawUser)
		SELECT d.rptDate, d.CustId, d.CurrencyId, 
			SUM(d.BetCount) AS NumberOfDeposit, 
			SUM(d.Amount * e.Rate / e.MultipleBy) AS DepositAmount,
			1 AS IsDepositWithrawUser
		FROM 
		(
			SELECT 
				CONVERT(DATE, DATEADD(HOUR, @TimeZone, d.CreateTime)) AS rptDate, c.CustId, c.CurrencyId, 
				CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) AS ExchangeDate,
				COUNT(1) AS BetCount,
				SUM(d.ActualDeposit) AS Amount
			FROM dbo.DepositInfo d WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON d.CustId = c.CustId
			WHERE d.WinlostDate BETWEEN @FDate AND @TDate
				AND d.CreateTime >= @FromDateTimeGMT0 
				AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.SiteId) + ',%'
				AND d.Status = 3
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND c.MemberType <> 3
				AND (
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, d.CreateTime)), c.CustId, c.CurrencyId
				, CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime))
		) d
			INNER JOIN #__TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY d.rptDate, d.CustId, d.CurrencyId
		
		-- Withdrawal
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, NumberOfWithdrawal, WithdrawalAmount, IsDepositWithrawUser)
		SELECT w.rptDate, w.CustId, w.CurrencyId, 
			SUM(w.BetCount) AS NumberOfWithdrawal, 
			SUM(w.Amount * e.Rate / e.MultipleBy) AS WithdrawalAmount,
			1 AS IsDepositWithrawUser
		FROM 
		(
			SELECT 
				CONVERT(DATE, DATEADD(HOUR, @TimeZone, w.CreateTime)) AS rptDate, c.CustId, c.CurrencyId, 
				CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) AS ExchangeDate,
				COUNT(1) AS BetCount,
				SUM(w.Amount) AS Amount
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON w.CustId = c.CustId
			WHERE w.WinlostDate BETWEEN @FDate AND @TDate
				AND w.CreateTime >= @FromDateTimeGMT0 
				AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.SiteId) + ',%'
				AND w.Status = 6
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND c.MemberType <> 3
				AND (
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, w.CreateTime)), c.CustId, c.CurrencyId
				, CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime))
		) w
			INNER JOIN #__TpExchange e ON w.CurrencyId = e.TpExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY w.rptDate, w.CustId, w.CurrencyId
	END

	;WITH CTE_Result AS (
		SELECT
			CASE
				WHEN @GroupBy = 1 THEN CONVERT(VARCHAR(10), rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, rptDate), 0), 103), 7) END AS rptDate
			,GameType
			,CustId
			,TurnOver = SUM(TurnOver)
			,NetTurnOver = SUM(NetTurnOver)
			,NetTurnOverForMargin = SUM(NetTurnOverForMargin)
			,Winloss = SUM(Winloss)
			,ProgressiveWin = SUM(ProgressiveWin)
			,ProgressiveBet = SUM(ProgressiveBet)
			,Commission = SUM(Commission)
			,Revenue = SUM(Revenue)
			,RevenueForMargin = SUM(RevenueForMargin)
			,BetCount = SUM(BetCount)
			,NumberOfDeposit = SUM(NumberOfDeposit)	
			,DepositAmount = SUM(DepositAmount)
			,NumberOfWithdrawal = SUM(NumberOfWithdrawal)	
			,WithdrawalAmount = SUM(WithdrawalAmount)
		FROM #__N88_SumWinloss
		GROUP BY
			CASE
				WHEN @GroupBy = 1 THEN CONVERT(VARCHAR(10), rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, rptDate), 0), 103), 7) END
			,GameType
			,CustId
	)
	SELECT
		r.rptDate
		,g.TypeName AS ProductName
		,c.UserName
		,c.TpUserName
		,c.TpSystemUserName
		,ISNULL(tp.ExchangeId, c.CurrencyId) AS CurrencyId
		,s.SiteName
		,r.TurnOver
		,r.NetTurnOver
		,r.Revenue AS GGR
		,r.Winloss AS PlayerWinloss
		,r.ProgressiveWin
		,r.ProgressiveBet
		,r.Commission
		,r.BetCount
		,CASE WHEN ISNULL(BetCount, 0) = 0 THEN 0 ELSE NetTurnOver/BetCount END AS AvgBetAmount
		,CASE WHEN ISNULL(BetCount, 0) = 0 THEN 0 ELSE 1 END AS UniquePlayers
		,CASE WHEN ISNULL(NetTurnOverForMargin, 0) = 0 THEN 0 ELSE RevenueForMargin/NetTurnOverForMargin*100 END AS Margin
		,NumberOfDeposit		
		,DepositAmount
		,NumberOfWithdrawal		
		,WithdrawalAmount	
	FROM CTE_Result r
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
		INNER JOIN dbo.ServerInfo s WITH (NOLOCK) ON c.SiteId = s.SiteId
		INNER JOIN dbo.TpGameType g WITH (NOLOCK) ON r.GameType = g.Type
		LEFT JOIN dbo.TpExchange tp WITH (NOLOCK) ON tp.TpExchangeId = c.CurrencyId
	ORDER BY
		r.rptDate DESC
		,s.SiteName
		,g.TypeName
		,ISNULL(tp.ExchangeId, c.CurrencyId)
		,c.UserName

	DROP TABLE #__TpExchange
	DROP TABLE #__N88_SumWinloss
END
GO