/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Winloss]
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
	,@IsNoDrawTicket			BIT
	,@IsIncludedTestData		BIT
	,@IsDetailInOriginalCurr	BIT = 0
	,@TimeZone					SMALLINT = 8
	,@PageIndex					INT = 1
	,@PageSize					INT = 50
	,@TotalRows					INT = 0 OUTPUT
AS

/*
	Created: 20200508@Sol
	DB: DBN88-bodb_N88
	Task: N88 report winloss
	
	Revisions:
		- 20200508@Sol: Create new report [Redmine:#133254]
		- 20200506@Sol: Remove IsTest column in N88_RptWinloss [RedmineID: #135372]
		- 20200920@Sophia: Fix Issue Divide by zero error encountered [Redmine: #141991]
		- 20200828@Percy: Support multiple brand [RedmineID: #140362]
		- 20201110@Percy: Enhance code get exchange to improve performance [RedmineID: #144972]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	-- 1. Get raw data
	CREATE TABLE #__N88_RptWinloss
	(
		rptDate					DATE
		,GameType				INT
		,CustId					INT
		,CurrencyId				INT
		,BetCount				INT
		,TurnOver				MONEY
		,TurnoverNoDraw			MONEY
		,Winloss				MONEY
		,BasedTurnOver			MONEY
		,BasedTurnoverNoDraw	MONEY
		,BasedWinloss			MONEY
	)
	CREATE CLUSTERED INDEX CIX_N88_RptWinloss ON #__N88_RptWinloss (CustId)

	CREATE TABLE #__Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
	CREATE CLUSTERED INDEX CIX_Exchange ON #__Exchange (ExchangeId, FromDate)
	
	DECLARE @MinDate DATE, @MaxDate DATE
	
	---- by winlostdate
	IF (@FilterBy = 1)
	BEGIN
		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_RptWinloss
		(
			rptDate, GameType, CustId, CurrencyId
			,BetCount, TurnOver, TurnoverNoDraw, Winloss, BasedTurnOver, BasedTurnoverNoDraw, BasedWinloss
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(TurnOverNoDraw)
			,SUM(Winloss)
			,SUM(TurnOver * e.Rate)
			,SUM(TurnOverNoDraw * e.Rate)
			,SUM(Winloss * e.Rate)
		FROM (
			SELECT
				r.WinlostDate
				,r.CustId
				,r.Currency
				,rptDate		= CASE @FilterBy WHEN 1 THEN r.WinlostDateGMT WHEN 2 THEN r.TransDateGMT END
				,GameType		= CASE WHEN @GroupBy = 3 THEN r.GameType END
				,TurnOver		= SUM(TurnOver)
				,TurnOverNoDraw	= SUM(CASE WHEN StatusId = 4 THEN 0 ELSE TurnOver END)
				,Winloss		= SUM(Winloss)
				,BetCount		= SUM(BetCount)
			FROM dbo.N88_RptWinloss r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.WinlostDate BETWEEN @FDate AND @TDate
				AND r.WinlostDateGMT BETWEEN @FromDate AND @ToDate
				AND r.TimeZone = @TimeZone
				AND ',' + @LicenseeIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.LicenseeId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND 1 = 
						CASE 
							WHEN @IsNoDrawTicket = 1 AND r.StatusId IN (1,2) THEN 1
							WHEN @IsNoDrawTicket = 0 AND r.StatusId IN (1,2,4) THEN 1
							ELSE 0
						END
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND (
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			GROUP BY
				r.WinlostDate
				,r.CustId
				,r.Currency
				,CASE @FilterBy WHEN 1 THEN r.WinlostDateGMT WHEN 2 THEN r.TransDateGMT END
				,CASE WHEN @GroupBy = 3 THEN r.GameType END
		) r
			INNER JOIN #__Exchange e ON r.WinlostDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
		GROUP BY rptDate, GameType, CustId, Currency
	END
	---- by transdate
	ELSE 
	BEGIN
		SELECT @MinDate = MIN(WinlostDate), @MaxDate = MAX(WinlostDate)
		FROM dbo.N88_RptWinloss WITH (NOLOCK) WHERE TransDate BETWEEN @FDate AND @TDate

		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_RptWinloss
		(
			rptDate, GameType, CustId, CurrencyId
			,BetCount, TurnOver, TurnoverNoDraw, Winloss, BasedTurnOver, BasedTurnoverNoDraw, BasedWinloss
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(TurnOverNoDraw)
			,SUM(Winloss)
			,SUM(TurnOver * e.Rate)
			,SUM(TurnOverNoDraw * e.Rate)
			,SUM(Winloss * e.Rate)
		FROM (
			SELECT
				r.WinlostDate
				,r.CustId
				,r.Currency
				,rptDate		= CASE @FilterBy WHEN 1 THEN r.WinlostDateGMT WHEN 2 THEN r.TransDateGMT END
				,GameType		= CASE WHEN @GroupBy = 3 THEN r.GameType END
				,TurnOver		= SUM(TurnOver)
				,TurnOverNoDraw	= SUM(CASE WHEN StatusId = 4 THEN 0 ELSE TurnOver END)
				,Winloss		= SUM(Winloss)
				,BetCount		= SUM(BetCount)
			FROM dbo.N88_RptWinloss r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.TransDate BETWEEN @FDate AND @TDate
				AND r.TransDateGMT BETWEEN @FromDate AND @ToDate
				AND r.TimeZone = @TimeZone
				AND ',' + @LicenseeIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.LicenseeId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND 1 = 
						CASE 
							WHEN @IsNoDrawTicket = 1 AND r.StatusId IN (1,2) THEN 1
							WHEN @IsNoDrawTicket = 0 AND r.StatusId IN (1,2,4) THEN 1
							ELSE 0
						END
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND (
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			GROUP BY
				r.WinlostDate
				,r.CustId
				,r.Currency
				,CASE @FilterBy WHEN 1 THEN r.WinlostDateGMT WHEN 2 THEN r.TransDateGMT END
				,CASE WHEN @GroupBy = 3 THEN r.GameType END
		) r
			INNER JOIN #__Exchange e ON r.WinlostDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
		GROUP BY rptDate, GameType, CustId, Currency
	END

	DROP TABLE #__Exchange

	-- 2. Calc temp result
	CREATE TABLE #__tmpResult 
	(
		[Group]					VARCHAR(500)
		,SabaId					VARCHAR(50)
		,SabaSystemId			VARCHAR(50)
		,CurrencyId				INT
		,Turnover				MONEY
		,TurnoverNoDraw			MONEY
		,BasedTurnover			MONEY
		,BasedTurnoverNoDraw	MONEY
		,GGR					MONEY
		,BasedGGR				MONEY
		,BetCount				INT
		,AvgBetAmount			MONEY
		,BasedAvgBetAmount		MONEY
		,UniquePlayers			INT
		,Margin					MONEY
	)
	
	-- by date/month
	IF (@GroupBy IN (1, 2))
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,CurrencyId
			,Turnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
		)
		SELECT 
			CASE WHEN @GroupBy = 1
				THEN CONVERT(VARCHAR(500), rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, rptDate), 0), 103), 7)
				END
			,CurrencyId
			,SUM(TurnOver) 
			,SUM(TurnoverNoDraw)
			,SUM(BasedTurnOver)
			,SUM(BasedTurnoverNoDraw)
			,SUM(Winloss)
			,SUM(BasedWinloss)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(TurnOverNoDraw),0),0) AS MONEY) * 100 AS Margin
		FROM #__N88_RptWinloss
		GROUP BY
			CASE WHEN @GroupBy = 1
				THEN CONVERT(VARCHAR(500), rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, rptDate), 0), 103), 7)
				END
			,CurrencyId
	END
	-- by product - gametype
	ELSE IF (@GroupBy = 3)
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,CurrencyId
			,Turnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
		)
		SELECT 
			g.TypeName
			,CurrencyId
			,SUM(TurnOver) 
			,SUM(TurnoverNoDraw)
			,SUM(BasedTurnOver)
			,SUM(BasedTurnoverNoDraw)
			,SUM(Winloss)
			,SUM(BasedWinloss)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(TurnOverNoDraw),0),0) AS MONEY) * 100 AS Margin
		FROM #__N88_RptWinloss r
			INNER JOIN dbo.TpGameType g WITH (NOLOCK) ON r.GameType = g.Type
		GROUP BY
			g.TypeName
			,CurrencyId
	END
	-- by currency
	ELSE IF (@GroupBy = 4)
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,CurrencyId
			,Turnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
		)
		SELECT 
			CurrencyId
			,CurrencyId
			,SUM(TurnOver) 
			,SUM(TurnoverNoDraw)
			,SUM(BasedTurnOver)
			,SUM(BasedTurnoverNoDraw)
			,SUM(Winloss)
			,SUM(BasedWinloss)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(TurnOverNoDraw),0),0) AS MONEY) * 100 AS Margin
		FROM #__N88_RptWinloss r
		GROUP BY
			CurrencyId
	END
	-- by player
	ELSE IF (@GroupBy = 5)
	BEGIN
		WITH CTE_Result AS (
			SELECT CustId
				,TurnOver = SUM(TurnOver)
				,TurnoverNoDraw = SUM(TurnoverNoDraw)
				,BasedTurnOver = SUM(BasedTurnOver)
				,BasedTurnoverNoDraw = SUM(BasedTurnoverNoDraw)
				,Winloss = SUM(Winloss)
				,BasedWinloss = SUM(BasedWinloss)
				,BetCount = SUM(BetCount)
			FROM #__N88_RptWinloss
			GROUP BY CustId
		)
		INSERT INTO #__tmpResult
		(
			[Group]
			,SabaId
			,SabaSystemId
			,CurrencyId
			,Turnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
		)
		SELECT 
			c.UserName
			,c.TpUserName
			,c.TpSystemUserName
			,c.CurrencyId
			,r.TurnOver
			,r.TurnoverNoDraw
			,r.BasedTurnOver
			,r.BasedTurnoverNoDraw
			,r.Winloss
			,r.BasedWinloss
			,r.BetCount
			,CASE WHEN BetCount = 0 THEN 0 ELSE TurnOver/BetCount END
			,CASE WHEN BetCount = 0 THEN 0 ELSE BasedTurnOver/BetCount END
			,1 AS UniquePlayers
			,CASE WHEN TurnOverNoDraw = 0 THEN 0 ELSE Winloss/TurnOverNoDraw * 100 END
		FROM CTE_Result r
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
	END

	-- 3. Final result
	CREATE TABLE #__FinalResult 
	(
		RowNumber				INT
		,[Group]				VARCHAR(500)
		,SabaId					VARCHAR(50)
		,SabaSystemId			VARCHAR(50)
		,CurrencyId				INT
		,Turnover				MONEY
		,TurnoverNoDraw			MONEY
		,BasedTurnover			MONEY
		,BasedTurnoverNoDraw	MONEY
		,GGR					MONEY
		,BasedGGR				MONEY
		,BetCount				INT
		,AvgBetAmount			MONEY
		,BasedAvgBetAmount		MONEY
		,UniquePlayers			INT
		,Margin					MONEY
	)

	DECLARE @RowStart INT , @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	INSERT INTO #__FinalResult
	SELECT 
		DENSE_RANK() OVER(ORDER BY [Group]) RowNumber,
		[Group]
		,SabaId
		,SabaSystemId
		,CurrencyId
		,Turnover
		,TurnoverNoDraw
		,BasedTurnover
		,BasedTurnoverNoDraw
		,GGR
		,BasedGGR
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,Margin
	FROM #__tmpResult

	DROP TABLE #__tmpResult

	--return data
	SELECT @TotalRows = MAX(RowNumber) FROM #__FinalResult

	SELECT RowNumber,
		[Group]
		,SabaId
		,SabaSystemId
		,CurrencyId
		,Turnover
		,TurnoverNoDraw
		,BasedTurnover
		,BasedTurnoverNoDraw
		,(-1) * GGR AS GGR
		,(-1) * BasedGGR AS BasedGGR
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,(-1) * (CASE WHEN @IsDetailInOriginalCurr = 0 THEN BasedGGR/NULLIF(BasedTurnoverNoDraw, 0) ELSE GGR/NULLIF(TurnoverNoDraw, 0) END) * 100 AS Margin
	FROM #__FinalResult
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 
	ORDER BY [Group], CurrencyId

	-- total
	SELECT
		CAST(SUM(BasedTurnover) AS MONEY) AS TotalBasedTurnover
		,CAST(SUM(BasedTurnoverNoDraw) AS MONEY) AS TotalBasedTurnoverNoDraw
		,(-1) * CAST(SUM(BasedWinloss) AS MONEY) AS TotalBasedGGR
		,SUM(BetCount) AS TotalBetCount
		,CAST(ISNULL(SUM(BasedTurnOver)/NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS TotalBasedAvgBetAmount
		,COUNT(DISTINCT CustId) AS TotalUniquePlayers
		,(-1) * ISNULL(SUM(CAST(BasedWinloss AS MONEY))/NULLIF(SUM(BasedTurnOverNoDraw), 0), 0) * 100 AS TotalMargin
	FROM #__N88_RptWinloss

	DROP TABLE #__FinalResult
	DROP TABLE #__N88_RptWinloss
END
GO