/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE N88_Rpt_Winloss
(
	@LicenseeId INT,
	@FilterBy TINYINT,
	@GroupBy TINYINT,
	@FromDate DATE, 
	@ToDate DATE,
	@ProductIds VARCHAR(MAX),
	@UserName VARCHAR(30) = '',
	@CurrencyIds VARCHAR(MAX),
	@DisplayCurrency VARCHAR(3),
	@IsIncludedTestData BIT,
	@IsNoDrawTicket BIT,
	@PageIndex INT = 1,
	@PageSize INT = 50,
	@TotalRows INT = 0 OUTPUT
)
AS
/*
	Created: 20200508@Sol
	Task : N88 report winloss
	DB: DBEXT-bodb02
	
	Revisions:
		- 20200508@Sol: Create new report [Redmine:#133254]
	
*/
BEGIN
	
	SET NOCOUNT ON;

	CREATE TABLE #tmpN88_RptWinloss
	(
		WinlostDate	DATE
		,CustId	INT
		,GameTypeName VARCHAR(45)
		,CurrencyId INT
		,TurnOver	MONEY
		,Winloss	MONEY
		,BetCount	INT
		,StatusID	TINYINT
		,UserName	VARCHAR(30)
		,WinlostDateGMT	DATE
		,TimeZone	SMALLINT
		,TransDate	DATE
		,TransDateGMT	DATE
		,LicenseeID	INT
		,Exrate FLOAT
	)

	CREATE TABLE #tmpResult 
	(
		RowNumber INT,
		[Group] VARCHAR(500),
		CurrencyId INT,
		Turnover MONEY,
		BasedTurnover MONEY,
		BasedTurnoverNoDraw MONEY,
		GGR MONEY,
		BasedGGR MONEY,
		BetCount INT,
		AvgBetAmount MONEY,
		BasedAvgBetAmount MONEY,
		UniquePlayers INT,
		Margin MONEY
	)

	DECLARE @Exchange TABLE (FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)
	DECLARE @RowStart INT , @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	IF (@IsIncludedTestData = 1)
	BEGIN
		SET @CurrencyIds = @CurrencyIds + ',20'
	END

	-- report
	INSERT INTO @Exchange (FromDate, ToDate, ExchangeId, Rate)
	SELECT FromDate, ToDate, ExchangeID, Rate
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(DATEADD(DAY,-1,@FromDate), @ToDate, @DisplayCurrency, '') t_ex
	
	-- prepare common data
	INSERT INTO #tmpN88_RptWinloss
	(
		WinlostDate, CustId, GameTypeName, CurrencyId, TurnOver, Winloss, BetCount, StatusID, UserName	
		, WinlostDateGMT, TimeZone, TransDate, TransDateGMT, LicenseeID, Exrate
	)
	SELECT 
		WinlostDate	
		,CustId	
		,g.TypeName	
		,dt.Currency	
		,TurnOver	
		,Winloss	
		,BetCount	
		,StatusID	
		,UserName	
		,WinlostDateGMT	
		,TimeZone	
		,TransDate	
		,TransDateGMT	
		,LicenseeID	
		,ex.Rate
	FROM bodb_LicenseeReport.dbo.N88_RptWinloss dt
			INNER JOIN @Exchange ex
				ON dt.Currency = ex.exchangeid AND dt.Winlostdate BETWEEN ex.FromDate AND ex.ToDate
			INNER JOIN bodb02.dbo.Exchange exCode
				ON ex.ExchangeId = exCode.exchangeid
			INNER JOIN bodb_3rdProduct.dbo.TpGameType g
				ON g.Type = dt.GameType
	WHERE 
		1 = CASE 
				WHEN @IsNoDrawTicket = 1 AND dt.StatusID IN (1,2) THEN 1
				WHEN @IsNoDrawTicket = 0 AND dt.StatusID IN (1,2,4) THEN 1
				ELSE 0
			END
		AND dt.LicenseeID = @LicenseeId
		AND 1 = CASE
					WHEN @FilterBy = 1 AND WinlostDateGMT BETWEEN @FromDate AND @ToDate THEN 1
					WHEN @FilterBy = 2 AND TransDateGMT BETWEEN @FromDate AND @ToDate THEN 1
					ELSE 0
				END
		AND (dt.UserName = @UserName OR ISNULL(@UserName,'') = '')
		AND dt.GameType IN (SELECT val FROM bodb02.dbo.strsplit(@ProductIds,',') t)
		AND dt.Currency IN (SELECT val FROM bodb02.dbo.strsplit(@CurrencyIds,',') t)

	-- by date
	IF (@GroupBy = 1)
	BEGIN
		INSERT INTO #tmpResult 
		(
			RowNumber
			,[Group]
			,CurrencyId
			,Turnover
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
			ROW_NUMBER() OVER(PARTITION BY CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END ORDER BY CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END, CurrencyId) AS RowNumber 
			,CONVERT(VARCHAR(500), CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END, 101) AS [Group] 
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(TurnOver * Exrate) AS BasedTurnover
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver * Exrate END) AS BasedTurnoverNoDraw  
			,SUM(Winloss) AS GGR 
			,SUM(Winloss * Exrate) AS BasedGGR
			,SUM(BetCount) AS BetCount 
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(CASE WHEN statusid IN (1,2) THEN TurnOver ELSE 0 END),0),0) AS MONEY) * 100 AS Margin
		FROM #tmpN88_RptWinloss
		GROUP BY 
			CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END 
			,CurrencyId
	END
	-- by month
	ELSE IF (@GroupBy = 2)
	BEGIN
		INSERT INTO #tmpResult 
		(
			RowNumber
			,[Group]
			,CurrencyId
			,Turnover
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
			ROW_NUMBER() OVER
							(
								PARTITION BY DATEADD(MONTH, DATEDIFF(MONTH, 0, (CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END)), 0)
								ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, (CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END)), 0), CurrencyId
							) AS RowNumber 
			,RIGHT(CONVERT(VARCHAR(10),DATEADD(MONTH, DATEDIFF(MONTH, 0, (CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END)), 0), 103),7) AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(Turnover * Exrate) AS BasedTurnover
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver * Exrate END) AS BasedTurnoverNoDraw
			,SUM(Winloss) AS GGR 
			,SUM(Winloss * Exrate) AS BasedGGR
			,SUM(Betcount) AS [BetCount] 
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(CASE WHEN statusid IN (1,2) THEN TurnOver ELSE 0 END),0),0) AS MONEY) * 100 AS Margin
		FROM #tmpN88_RptWinloss
		GROUP BY 
			DATEADD(MONTH, DATEDIFF(MONTH, 0, (CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END)), 0)
			,CurrencyId
	END
	-- by product - gametype
	ELSE IF (@GroupBy = 3)
	BEGIN
		INSERT INTO #tmpResult 
		(
			RowNumber
			,[Group]
			,CurrencyId
			,Turnover
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
			ROW_NUMBER() OVER(PARTITION By GameTypeName ORDER BY GameTypeName, CurrencyId) AS RowNumber 
			,GameTypeName AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(Turnover * Exrate) AS BasedTurnover
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver * Exrate END) AS BasedTurnoverNoDraw
			,SUM(Winloss) AS GGR 
			,SUM(Winloss * Exrate) AS BasedGGR
			,SUM(Betcount) AS [BetCount] 
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(CASE WHEN statusid IN (1,2) THEN TurnOver ELSE 0 END),0),0) AS MONEY) * 100 AS Margin
		FROM #tmpN88_RptWinloss
		GROUP BY 
			GameTypeName
			,CurrencyId
	END
	-- by currency
	ELSE IF (@GroupBy = 4)
	BEGIN
		INSERT INTO #tmpResult 
		(
			RowNumber
			,[Group]
			,CurrencyId
			,Turnover
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
			ROW_NUMBER() OVER(PARTITION By CurrencyId ORDER BY CurrencyId) AS RowNumber 
			,CurrencyId AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(Turnover * Exrate) AS BasedTurnover
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver * Exrate END) AS BasedTurnoverNoDraw
			,SUM(Winloss) AS GGR 
			,SUM(Winloss * Exrate) AS BasedGGR
			,SUM(Betcount) AS [BetCount] 
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(CASE WHEN statusid IN (1,2) THEN TurnOver ELSE 0 END),0),0) AS MONEY) * 100 AS Margin
		FROM #tmpN88_RptWinloss
		GROUP BY CurrencyId
	END
	-- by player
	ELSE IF (@GroupBy = 5)
	BEGIN
		INSERT INTO #tmpResult 
		(
			RowNumber
			,[Group]
			,CurrencyId
			,Turnover
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
			ROW_NUMBER() OVER(PARTITION By UserName ORDER BY UserName, CurrencyId) AS RowNumber 
			,UserName AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(Turnover * Exrate) AS BasedTurnover
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver * Exrate END) AS BasedTurnoverNoDraw
			,SUM(Winloss) AS GGR 
			,SUM(Winloss * Exrate) AS BasedGGR
			,SUM(Betcount) AS [BetCount] 
			,CAST(ISNULL(SUM(TurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(CASE WHEN statusid IN (1,2) THEN TurnOver ELSE 0 END),0),0) AS MONEY) * 100 AS Margin
		FROM #tmpN88_RptWinloss
		GROUP BY UserName, CurrencyId
	END

	--final result
	SELECT @TotalRows = COUNT(1) FROM #tmpResult

	SELECT 
		[Group]
		,CurrencyId
		,Turnover
		,BasedTurnover
		,BasedTurnoverNoDraw
		,GGR
		,BasedGGR
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,Margin
	FROM #tmpResult
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 

	-- total
	SELECT 
		SUM(Turnover * Exrate) AS TotalBasedTurnover
		,SUM(Winloss * Exrate) AS TotalBasedGGR
		,SUM(BetCount) AS TotalBetCount
		,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS TotalBasedAvgBetAmount
		,COUNT(DISTINCT CustId) AS TotalUniquePlayers
		,CAST(ISNULL(SUM(Winloss * Exrate)/NULLIF(SUM(CASE WHEN StatusID IN (1,2) THEN turnover * Exrate END),0),0) AS MONEY) * 100 AS TotalMargin
	FROM #tmpN88_RptWinloss

	DROP TABLE #tmpResult
	DROP TABLE #tmpN88_RptWinloss

END
GO