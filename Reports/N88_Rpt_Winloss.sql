/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE N88_Rpt_Winloss
(
	@LicenseeId INT,
	@FilterBy TINYINT,
	@GroupBy TINYINT,
	@FromDate DATE, 
	@ToDate DATE,
	@ProductIds VARCHAR(MAX),
	@UserNameFilterId TINYINT = 1,
	@UserName VARCHAR(30) = '',
	@CurrencyIds VARCHAR(MAX),
	@DisplayCurrency VARCHAR(3),
	@IsNoDrawTicket BIT,
	@IsIncludedTestData BIT,
	@IsDetailInOriginalCurr BIT = 0,
	@TimeZone SMALLINT = 8,
	@PageIndex INT = 1,
	@PageSize INT = 50,
	@TotalRows INT = 0 OUTPUT
)
AS
/*
	Created: 20200508@Sol
	Task : N88 report winloss
	DB: DBN88-bodb_N88
	
	Revisions:
		- 20200508@Sol: Create new report [Redmine:#133254]
		- 20200506@Sol: Remove IsTest column in N88_RptWinloss [RedmineID: #135372]
		- 20200920@Sophia: Fix Issue Divide by zero error encountered [Redmine: #141991]
	
*/
BEGIN
	
	SET NOCOUNT ON;

	CREATE TABLE #tmpN88_RptWinlossTransDate
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
		,SabaId		VARCHAR(50)
		,SabaSystemId VARCHAR(50)
		,WinlostDateGMT	DATE
		,TimeZone	SMALLINT
		,TransDate	DATE
		,TransDateGMT	DATE
		,LicenseeID	INT
	)

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
		,SabaId		VARCHAR(50)
		,SabaSystemId VARCHAR(50)
		,WinlostDateGMT	DATE
		,TimeZone	SMALLINT
		,TransDate	DATE
		,TransDateGMT	DATE
		,LicenseeID	INT
		,Exrate FLOAT
	)

	CREATE TABLE #tmpResult 
	(
		[Group] VARCHAR(500),
		SabaId VARCHAR(50),
		SabaSystemId VARCHAR(50),
		CurrencyId INT,
		Turnover MONEY,
		TurnoverNoDraw MONEY,
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

	CREATE TABLE #tmpResultByGroup 
	(
		RowNumber INT,
		[Group] VARCHAR(500),
		SabaId VARCHAR(50),
		SabaSystemId VARCHAR(50),
		CurrencyId INT,
		Turnover MONEY,
		TurnoverNoDraw MONEY,
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

	CREATE TABLE #Exchange(FromDate SMALLDATETIME, ToDate SMALLDATETIME, ExchangeId INT, Rate FLOAT)
	DECLARE @RowStart INT , @RowEnd INT
	DECLARE @MinDate DATE, @MaxDate DATE

	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	---- by winlostdate
	IF (@FilterBy = 1)
	BEGIN

		-- report
		INSERT INTO #Exchange(FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(DATEADD(DAY,-1,@FromDate), @ToDate, @DisplayCurrency, '') t_ex
	
		-- prepare common data
		INSERT INTO #tmpN88_RptWinlossTransDate
		(
			WinlostDate, CustId, GameTypeName, CurrencyId, TurnOver, Winloss, BetCount, StatusID, UserName, SabaId, SabaSystemId
			, WinlostDateGMT, TimeZone, TransDate, TransDateGMT, LicenseeID
		)
		SELECT 
			WinlostDate	
			,dt.CustId	
			,g.TypeName	
			,dt.Currency	
			,TurnOver	
			,Winloss	
			,BetCount	
			,StatusID	
			,dt.UserName	
			,TpUserName
			,TpSystemUserName
			,WinlostDateGMT	
			,TimeZone	
			,TransDate	
			,TransDateGMT	
			,LicenseeID	
		FROM dbo.N88_RptWinloss dt WITH(NOLOCK)
				INNER JOIN dbo.TpGameType g WITH(NOLOCK)
					ON g.Type = dt.GameType
				INNER JOIN dbo.Customer c WITH(NOLOCK)
					ON c.CustId = dt.CustId
		WHERE 
			dt.TimeZone = @TimeZone
			AND 1 = 
					CASE 
						WHEN @IsNoDrawTicket = 1 AND dt.StatusID IN (1,2) THEN 1
						WHEN @IsNoDrawTicket = 0 AND dt.StatusID IN (1,2,4) THEN 1
						ELSE 0
					END
			AND dt.LicenseeID = @LicenseeId
			AND WinlostDateGMT BETWEEN @FromDate AND @ToDate
			AND 
				(
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			AND dt.GameType IN (SELECT val FROM bodb02.dbo.f_StringSplit(@ProductIds,',') t)
			AND dt.Currency IN (SELECT val FROM bodb02.dbo.f_StringSplit(@CurrencyIds,',') t)
			AND (c.IsTest = 0 OR @IsIncludedTestData = 1)

		-- prepare common data
		INSERT INTO #tmpN88_RptWinloss
		(
			WinlostDate, CustId, GameTypeName, CurrencyId, TurnOver, Winloss, BetCount, StatusID, UserName, SabaId, SabaSystemId
			, WinlostDateGMT, TimeZone, TransDate, TransDateGMT, LicenseeID, Exrate
		)
		SELECT 
			WinlostDate	
			,CustId	
			,dt.GameTypeName	
			,dt.CurrencyId	
			,TurnOver	
			,Winloss	
			,BetCount	
			,StatusID	
			,UserName	
			,SabaId
			,SabaSystemId
			,WinlostDateGMT	
			,TimeZone	
			,TransDate	
			,TransDateGMT	
			,LicenseeID	
			,ex.Rate
		FROM #tmpN88_RptWinlossTransDate dt 
				INNER JOIN #Exchange ex
					ON dt.CurrencyId = ex.exchangeid AND dt.Winlostdate BETWEEN ex.FromDate AND ex.ToDate

	END
	---- by transdate
	ELSE 
	BEGIN
		
		-- prepare common data
		INSERT INTO #tmpN88_RptWinlossTransDate
		(
			WinlostDate, CustId, GameTypeName, CurrencyId, TurnOver, Winloss, BetCount, StatusID, UserName, SabaId, SabaSystemId	
			, WinlostDateGMT, TimeZone, TransDate, TransDateGMT, LicenseeID
		)
		SELECT 
			WinlostDate	
			,dt.CustId	
			,g.TypeName	
			,dt.Currency	
			,TurnOver	
			,Winloss	
			,BetCount	
			,StatusID	
			,dt.UserName	
			,TpUserName
			,TpSystemUserName
			,WinlostDateGMT	
			,TimeZone	
			,TransDate	
			,TransDateGMT	
			,LicenseeID	
		FROM dbo.N88_RptWinloss dt WITH(NOLOCK)
				INNER JOIN dbo.TpGameType g WITH(NOLOCK)
					ON g.Type = dt.GameType
				INNER JOIN dbo.Customer c WITH(NOLOCK)
					ON c.CustId = dt.CustId
		WHERE 
			dt.TimeZone = @TimeZone
			AND 1 = CASE 
					WHEN @IsNoDrawTicket = 1 AND dt.StatusID IN (1,2) THEN 1
					WHEN @IsNoDrawTicket = 0 AND dt.StatusID IN (1,2,4) THEN 1
					ELSE 0
				END
			AND dt.LicenseeID = @LicenseeId
			AND TransDateGMT BETWEEN @FromDate AND @ToDate
			AND 
				(
					ISNULL(@UserName,'') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
			AND dt.GameType IN (SELECT val FROM bodb02.dbo.f_StringSplit(@ProductIds,',') t)
			AND dt.Currency IN (SELECT val FROM bodb02.dbo.f_StringSplit(@CurrencyIds,',') t)
			AND (c.IsTest = 0 OR @IsIncludedTestData = 1)

		---- get min/max winlostdate
		SELECT @MinDate = MIN(WinlostDate), @MaxDate = MAX(WinlostDate)
		FROM #tmpN88_RptWinlossTransDate

		-- report
		INSERT INTO #Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeID, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') t_ex

		-- prepare common data
		INSERT INTO #tmpN88_RptWinloss
		(
			WinlostDate, CustId, GameTypeName, CurrencyId, TurnOver, Winloss, BetCount, StatusID, UserName, SabaId, SabaSystemId
			, WinlostDateGMT, TimeZone, TransDate, TransDateGMT, LicenseeID, Exrate
		)
		SELECT 
			WinlostDate	
			,CustId	
			,dt.GameTypeName	
			,dt.CurrencyId	
			,TurnOver	
			,Winloss	
			,BetCount	
			,StatusID	
			,UserName	
			,SabaId
			,SabaSystemId
			,WinlostDateGMT	
			,TimeZone	
			,TransDate	
			,TransDateGMT	
			,LicenseeID	
			,ex.Rate
		FROM #tmpN88_RptWinlossTransDate dt 
				INNER JOIN #Exchange ex
					ON dt.CurrencyId = ex.exchangeid AND dt.Winlostdate BETWEEN ex.FromDate AND ex.ToDate

	END

	-- by date
	IF (@GroupBy = 1)
	BEGIN
		INSERT INTO #tmpResult 
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
			CONVERT(VARCHAR(500), CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END, 101) AS [Group] 
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver ELSE 0 END) AS TurnoverNoDraw
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
			RIGHT(CONVERT(VARCHAR(10),DATEADD(MONTH, DATEDIFF(MONTH, 0, (CASE WHEN @FilterBy = 1 THEN WinlostDateGMT ELSE TransDateGMT END)), 0), 103),7) AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver ELSE 0 END) AS TurnoverNoDraw
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
			GameTypeName AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver ELSE 0 END) AS TurnoverNoDraw
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
			CurrencyId AS [Group]
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver ELSE 0 END) AS TurnoverNoDraw
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
			UserName AS [Group]
			,SabaId
			,SabaSystemId
			,CurrencyId
			,SUM(TurnOver) AS Turnover  
			,SUM(CASE WHEN StatusID IN (1,2) THEN TurnOver ELSE 0 END) AS TurnoverNoDraw
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
		GROUP BY UserName,SabaId ,SabaSystemId, CurrencyId
	END

	--final result
	INSERT INTO #tmpResultByGroup
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
	FROM #tmpResult

	--return data
	SELECT @TotalRows = MAX(RowNumber) FROM #tmpResultByGroup

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
		--,(-1) * Margin AS Margin
		,(-1) * (CASE WHEN @IsDetailInOriginalCurr = 0 THEN BasedGGR/NULLIF(BasedTurnoverNoDraw,0) ELSE GGR/NULLIF(TurnoverNoDraw,0) END) * 100 AS Margin
	FROM #tmpResultByGroup
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 
	ORDER BY [Group], CurrencyId

	-- total
	SELECT 
		CAST(SUM(Turnover * Exrate) AS MONEY) AS TotalBasedTurnover
		,CAST(SUM(CASE WHEN StatusID IN (1,2) THEN turnover * Exrate END) AS MONEY) AS TotalBasedTurnoverNoDraw
		,(-1) * CAST(SUM(Winloss * Exrate) AS MONEY) AS TotalBasedGGR
		,SUM(BetCount) AS TotalBetCount
		,CAST(ISNULL(SUM(TurnOver * Exrate)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS TotalBasedAvgBetAmount
		,COUNT(DISTINCT CustId) AS TotalUniquePlayers
		--,(-1) * CAST(ISNULL(SUM(Winloss * Exrate)/NULLIF(SUM(CASE WHEN StatusID IN (1,2) THEN turnover * Exrate END),0),0) AS MONEY) * 100 AS TotalMargin
		,(-1) * ISNULL(SUM(CAST(Winloss * Exrate AS MONEY))/NULLIF(SUM(CASE WHEN StatusID IN (1,2) THEN CAST(turnover * Exrate AS MONEY) END),0),0) * 100 AS TotalMargin
	FROM #tmpN88_RptWinloss

	DROP TABLE #tmpResult
	DROP TABLE #tmpN88_RptWinloss
	DROP TABLE #tmpN88_RptWinlossTransDate
	DROP TABLE #tmpResultByGroup
	DROP TABLE #Exchange

END
GO