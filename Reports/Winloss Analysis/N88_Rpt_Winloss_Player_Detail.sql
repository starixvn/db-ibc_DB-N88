/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].N88_Rpt_Winloss_Player_Detail
	@FilterBy					TINYINT
	,@FromDate					DATE
	,@ToDate					DATE
	,@ProductIds				VARCHAR(MAX)
	,@CustId					INT
	,@DisplayCurrency			VARCHAR(3)
	,@IsNoDrawTicket			BIT
	,@TimeZone					SMALLINT = 8
	
AS

/*
	Created: 20210423@Sol
	DB: DBN88-bodb_N88
	Task: N88 report winloss
	
	Revisions:
		- 20210423@Sol: Initial sp - Add player detail section - [Redmine:#139333]

	Param's Explanation:
		@SortbyId:
			.  1 = Group
			.  2 = Turnover
			.  3 = Valid Turnover
			.  4 = GGR
			.  5 = Player Win Loss
			.  6 = BetCount
			.  7 = Avg Bet Amount
			.  8 = Unique Players
			.  9 = Margin
			. 10 = No. Deposit
			. 11 = Total Deposit Amount
			. 12 = No. Withdrawal
			. 13 = Total Withdrawal Amount
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	-- Data on GMT+0 --> convert timezone
	DECLARE @FromDateTimeGMT0 DATETIME, @ToDateTimeGMT0 DATETIME
	SELECT  @FromDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

	DECLARE @SiteId INT, @CurrencyId INT
	SELECT  @SiteId = c.SiteId, @CurrencyId = c.CurrencyId
	FROM dbo.Customer c WITH(NOLOCK)
	WHERE c.CustId = @CustId

	-- 1. Get raw data
	CREATE TABLE #__N88_SumWinloss
	(
		GameType					INT
		,BetCount					INT
		,TurnOver					MONEY
		,NetTurnOver				MONEY
		,NetTurnOverForMargin		MONEY
		,TurnoverNoDraw				MONEY
		,Revenue					MONEY
		,RevenueForMargin			MONEY
		,Winloss					MONEY
		,BasedTurnOver				MONEY
		,BasedNetTurnOver			MONEY
		,BasedNetTurnOverForMargin	MONEY
		,BasedTurnoverNoDraw		MONEY
		,BasedRevenue				MONEY
		,BasedRevenueForMargin		MONEY
		,BasedWinloss				MONEY
	)

	CREATE CLUSTERED INDEX CIX_N88_SumWinloss ON #__N88_SumWinloss (GameType)

	CREATE TABLE #__Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
	CREATE CLUSTERED INDEX CIX_Exchange ON #__Exchange (ExchangeId, FromDate)
	
	DECLARE @MinDate DATE, @MaxDate DATE
	
	---- by winlostdate
	IF (@FilterBy = 1)
	BEGIN
		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		WHERE e.ExchangeId = @CurrencyId

		INSERT INTO #__N88_SumWinloss
		(
			GameType 
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, TurnoverNoDraw, Revenue, RevenueForMargin, Winloss
			,BasedTurnOver, BasedNetTurnOver, BasedNetTurnOverForMargin, BasedTurnoverNoDraw, BasedRevenue, BasedRevenueForMargin, BasedWinloss
		)
		SELECT GameType
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(NetTurnOverForMargin)
			,SUM(TurnOverNoDraw)
			,SUM(Revenue)
			,SUM(RevenueForMargin)
			,SUM(Winloss)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
			,SUM(NetTurnOverForMargin * e.Rate)
			,SUM(TurnOverNoDraw * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(RevenueForMargin * e.Rate)
			,SUM(Winloss * e.Rate)
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,Currency				= r.Currency
				,GameType				= r.GameType
				,TurnOver				= SUM(TurnOver)
				,NetTurnOver			= SUM(ValidBet)
				,NetTurnOverForMargin	= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE ValidBet END)
				,TurnOverNoDraw			= SUM(CASE WHEN StatusId = 4 THEN 0 ELSE TurnOver END)
				,Revenue				= SUM(CASE WHEN r.GameType IN (41, 42) THEN Revenue ELSE -Winloss END)
				,RevenueForMargin		= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE -Winloss END)
				,Winloss				= SUM(Winloss)
				,BetCount				= SUM(BetCount)
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.SettledTime >= @FromDateTimeGMT0 AND r.SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND r.SiteId = @SiteId
				AND r.CustId = @CustId
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND r.Currency = @CurrencyId
				AND 1 = 
						CASE 
							WHEN @IsNoDrawTicket = 1 AND r.StatusId IN (1,2,6) THEN 1
							WHEN @IsNoDrawTicket = 0 AND r.StatusId IN (1,2,4,6) THEN 1
							ELSE 0
						END
			GROUP BY CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)), r.Currency, r.GameType
		) r
			INNER JOIN #__Exchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
		GROUP BY GameType
	END
	---- by transdate
	ELSE 
	BEGIN
		SELECT @MinDate = MIN(CONVERT(DATE, SettledTime)), @MaxDate = MAX(CONVERT(DATE, SettledTime))
		FROM dbo.N88_SumWinloss WITH (NOLOCK) WHERE TransTime >= @FromDateTimeGMT0 AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)

		SELECT @MinDate = DATEADD(DAY, -1, @MinDate), @MaxDate = DATEADD(DAY, 1, @MaxDate)

		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
		WHERE e.ExchangeId = @CurrencyId

		INSERT INTO #__N88_SumWinloss
		(
			GameType
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, TurnoverNoDraw, Revenue, RevenueForMargin, Winloss
			,BasedTurnOver, BasedNetTurnOver, BasedNetTurnOverForMargin, BasedTurnoverNoDraw, BasedRevenue, BasedRevenueForMargin, BasedWinloss
		)
		SELECT GameType
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(NetTurnOverForMargin)
			,SUM(TurnOverNoDraw)
			,SUM(Revenue)
			,SUM(RevenueForMargin)
			,SUM(Winloss)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
			,SUM(NetTurnOverForMargin * e.Rate)
			,SUM(TurnOverNoDraw * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(RevenueForMargin * e.Rate)
			,SUM(Winloss * e.Rate)
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,Currency				= r.Currency
				,GameType				= r.GameType
				,TurnOver				= SUM(TurnOver)
				,NetTurnOver			= SUM(ValidBet)
				,NetTurnOverForMargin	= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE ValidBet END)
				,TurnOverNoDraw			= SUM(CASE WHEN StatusId = 4 THEN 0 ELSE TurnOver END)
				,Revenue				= SUM(CASE WHEN r.GameType IN (41, 42) THEN Revenue ELSE -Winloss END)
				,RevenueForMargin		= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE -Winloss END)
				,Winloss				= SUM(Winloss)
				,BetCount				= SUM(BetCount)
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.TransTime >= @FromDateTimeGMT0 AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND r.SiteId = @SiteId
				AND r.CustId = @CustId
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND r.Currency = @CurrencyId
				AND 1 = 
						CASE 
							WHEN @IsNoDrawTicket = 1 AND r.StatusId IN (1,2,6) THEN 1
							WHEN @IsNoDrawTicket = 0 AND r.StatusId IN (1,2,4,6) THEN 1
							ELSE 0
						END
			GROUP BY CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)),r.Currency, r.GameType
		) r
			INNER JOIN #__Exchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
		GROUP BY GameType
	END

	DROP TABLE #__Exchange

	-- 2. Calc temp result
	CREATE TABLE #__tmpResult 
	(
		ProductId					INT
		,ProductName				VARCHAR(50)
		,CustId						INT
		,SabaId						VARCHAR(50)
		,SabaSystemId				VARCHAR(50)
		,Turnover					MONEY
		,NetTurnover				MONEY
		,NetTurnoverForMargin		MONEY
		,TurnoverNoDraw				MONEY
		,BasedTurnover				MONEY
		,BasedNetTurnover			MONEY
		,BasedNetTurnoverForMargin	MONEY
		,BasedTurnoverNoDraw		MONEY
		,GGR						MONEY
		,BasedGGR					MONEY
		,GGRForMargin				MONEY
		,BasedGGRForMargin			MONEY
		,PlayerWinloss				MONEY
		,BasedPlayerWinloss			MONEY
		,BetCount					INT
		,AvgBetAmount				MONEY
		,BasedAvgBetAmount			MONEY
		,UniquePlayers				INT
	)
	
	-- by product - gametype
	BEGIN
		INSERT INTO #__tmpResult 
		(
			ProductId
			,ProductName
			,CustId
			,Turnover
			,NetTurnover
			,NetTurnoverForMargin
			,TurnoverNoDraw
			,BasedTurnover
			,BasedNetTurnover
			,BasedNetTurnoverForMargin
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,GGRForMargin
			,BasedGGRForMargin
			,PlayerWinloss
			,BasedPlayerWinloss
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
		)
		SELECT
			g.[Type]
			,g.TypeName
			,@CustId
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(NetTurnOverForMargin)
			,SUM(TurnoverNoDraw)
			,SUM(BasedTurnOver)
			,SUM(BasedNetTurnOver)
			,SUM(BasedNetTurnOverForMargin)
			,SUM(BasedTurnoverNoDraw)
			,SUM(Revenue)
			,SUM(BasedRevenue)
			,SUM(RevenueForMargin)
			,SUM(BasedRevenueForMargin)
			,SUM(Winloss)
			,SUM(BasedWinloss)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,1 AS UniquePlayers
		FROM #__N88_SumWinloss r
			INNER JOIN dbo.TpGameType g WITH (NOLOCK) ON r.GameType = g.Type
		GROUP BY g.[Type], g.TypeName
	END

	SELECT 
		t.ProductId
		,t.ProductName
		,t.CustId
		,c.TpUserName AS SabaId
		,c.TpSystemUserName AS SabaSystemId
		,Turnover
		,NetTurnover
		,TurnoverNoDraw
		,BasedTurnover
		,BasedNetTurnover
		,BasedNetTurnoverForMargin
		,BasedTurnoverNoDraw
		,GGR
		,BasedGGR
		,BasedGGRForMargin
		,PlayerWinloss
		,BasedPlayerWinloss
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,0 NumberOfDeposit
		,0 DepositAmount
		,0 BasedDepositAmount
		,0 NumberOfWithdrawal		
		,0 WithdrawalAmount	
		,0 BasedWithdrawalAmount
	FROM #__tmpResult t
		INNER JOIN dbo.Customer c WITH (NOLOCK) ON t.CustId = c.CustId
	ORDER BY t.ProductId

	DROP TABLE #__tmpResult
	DROP TABLE #__N88_SumWinloss
END
GO