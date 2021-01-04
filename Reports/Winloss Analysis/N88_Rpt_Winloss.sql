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
		- 20201201@Percy: Add Net TurnOver column and include free bet tickets [RedmineID: #146210]
		- 20201223@Sol: Add new columns to report - [RedmineID: #147542]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FDate DATE, @TDate DATE
	SELECT  @FDate = DATEADD(DAY, -1, @FromDate), @TDate = DATEADD(DAY, 1, @ToDate)

	-- Data on GMT+0 --> convert timezone
	DECLARE @FromDateTimeGMT0 DATETIME, @ToDateTimeGMT0 DATETIME
	SELECT  @FromDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

	-- 1. Get raw data
	CREATE TABLE #__N88_RptWinloss
	(
		rptDate					DATE
		,GameType				INT
		,CustId					INT
		,CurrencyId				INT
		,BetCount				INT
		,TurnOver				MONEY
		,NetTurnOver			MONEY
		,TurnoverNoDraw			MONEY
		,Winloss				MONEY
		,BasedTurnOver			MONEY
		,BasedNetTurnOver		MONEY
		,BasedTurnoverNoDraw	MONEY
		,BasedWinloss			MONEY
		,NumberOfDeposit		INT
		,DepositAmount			MONEY
		,BasedDepositAmount		MONEY
		,NumberOfWithdrawal		INT
		,WithdrawalAmount		MONEY
		,BasedWithdrawalAmount	MONEY
	)
	CREATE CLUSTERED INDEX CIX_N88_RptWinloss ON #__N88_RptWinloss (CustId)

	CREATE TABLE #__Exchange (FromDate DATE, ToDate DATE, ExchangeId INT, Rate FLOAT)
	CREATE CLUSTERED INDEX CIX_Exchange ON #__Exchange (ExchangeId, FromDate)

	--Deposit temp table
	CREATE TABLE #__DepositTable
	(
		rptDate					DATE
		,CustId					INT
		,CurrencyId				INT
		,NumberOfDeposit		INT
		,DepositAmount			MONEY
		,BasedDepositAmount		MONEY
	)

	--withdrawal temp table
	CREATE TABLE #__WithdrawTable
	(
		rptDate					DATE
		,CustId					INT
		,CurrencyId				INT
		,NumberOfWithdrawal		INT
		,WithdrawalAmount		MONEY
		,BasedWithdrawalAmount	MONEY
	)
	
	DECLARE @tblCustId TABLE(CustId INT) 
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
			,BetCount, TurnOver, NetTurnOver, TurnoverNoDraw, Winloss
			,BasedTurnOver, BasedNetTurnOver, BasedTurnoverNoDraw, BasedWinloss
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(TurnOverNoDraw)
			,SUM(Winloss)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
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
				,NetTurnOver	= SUM(ValidBet)
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
							WHEN @IsNoDrawTicket = 0 AND r.StatusId IN (1,2,4,6) THEN 1
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
			,BetCount, TurnOver, NetTurnOver, TurnoverNoDraw, Winloss
			,BasedTurnOver, BasedNetTurnOver, BasedTurnoverNoDraw, BasedWinloss
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(TurnOverNoDraw)
			,SUM(Winloss)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
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
				,NetTurnOver	= SUM(ValidBet)
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
							WHEN @IsNoDrawTicket = 0 AND r.StatusId IN (1,2,4,6) THEN 1
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

	---- list customer by id
	INSERT INTO @tblCustId(CustId)
	SELECT DISTINCT CustId FROM #__N88_RptWinloss

	----deposit/withdraw number/amount
	BEGIN 
		--deposit
		INSERT INTO #__DepositTable
		(
			rptDate, CustId, CurrencyId
			,NumberOfDeposit	
			,DepositAmount		
			,BasedDepositAmount	
			
		)
		SELECT d.CreateTimeGMT, d.CustId, d.CurrencyId, 
			SUM(d.NumberOfDeposit) NumberOfDeposit, 
			SUM(d.DepositAmt) DepositAmt, 
			SUM(d.DepositAmt * e.Rate) AS BasedDepositAmount
		FROM 
		(
			SELECT 
				CONVERT(DATE, DATEADD(HOUR, @TimeZone, d.CreateTime)) AS CreateTimeGMT, c.CustId, c.CurrencyId, 
				CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime)) AS ExchangeDate,
				COUNT(d.DepositId) AS NumberOfDeposit,
				SUM(d.Amount / CASE WHEN d.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS DepositAmt
			FROM dbo.DepositInfo d WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) 
					ON d.CustId = c.CustId
			WHERE d.WinlostDate BETWEEN @FDate AND @ToDate
				AND d.CreateTime >= @FromDateTimeGMT0 
				AND d.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND d.SiteId IN 
								(
									SELECT SiteId
									FROM dbo.ServerInfo s WITH (NOLOCK)
										INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
									WHERE ',' + @LicenseeIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), l.LicenseeId) + ',%'
								)
				AND d.Status = 3
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, d.CreateTime)), c.CustId, c.CurrencyId
				, CONVERT(DATE, DATEADD(HOUR, -4, d.CreateTime))
		) d
		INNER JOIN #__Exchange e 
				ON d.CurrencyId = e.ExchangeId
					AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY d.CreateTimeGMT, d.CustId, d.CurrencyId
		
		--withdraw
		INSERT INTO #__WithdrawTable
		(
			rptDate, CustId, CurrencyId
			,NumberOfWithdrawal	
			,WithdrawalAmount	
			,BasedWithdrawalAmount
		)
		SELECT w.CreateTimeGMT, w.CustId, w.CurrencyId, 
			SUM(w.NumberOfWithdrawal) NumberOfWithdrawal, 
			SUM(w.WithdrawalAmount) WithdrawalAmount, 
			SUM(w.WithdrawalAmount * e.Rate) AS BasedWithdrawalAmount
		FROM 
		(
			SELECT 
				CONVERT(DATE, DATEADD(HOUR, @TimeZone, w.CreateTime)) AS CreateTimeGMT, c.CustId, c.CurrencyId, 
				CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime)) AS ExchangeDate,
				COUNT(w.WithdrawalId) AS NumberOfWithdrawal,
				SUM(w.Amount / CASE WHEN w.CurrencyId IN (15, 51) THEN 1000.0 ELSE 1.0 END) AS WithdrawalAmount
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) 
					ON w.CustId = c.CustId
			WHERE w.WinlostDate BETWEEN @FDate AND @ToDate
				AND w.CreateTime >= @FromDateTimeGMT0 
				AND w.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND w.SiteId IN 
								(
									SELECT SiteId
									FROM dbo.ServerInfo s WITH (NOLOCK)
										INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
									WHERE ',' + @LicenseeIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), l.LicenseeId) + ',%'
								)
				AND w.Status = 6
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, w.CreateTime)), c.CustId, c.CurrencyId
				, CONVERT(DATE, DATEADD(HOUR, -4, w.CreateTime))
		) w
		INNER JOIN #__Exchange e 
				ON w.CurrencyId = e.ExchangeId
					AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY w.CreateTimeGMT, w.CustId, w.CurrencyId

	END
	----end

	DROP TABLE #__Exchange

	-- 2. Calc temp result
	CREATE TABLE #__tmpResult 
	(
		[Group]					VARCHAR(500)
		,CustId					INT
		,SabaId					VARCHAR(50)
		,SabaSystemId			VARCHAR(50)
		,CurrencyId				INT
		,Turnover				MONEY
		,NetTurnover			MONEY
		,TurnoverNoDraw			MONEY
		,BasedTurnover			MONEY
		,BasedNetTurnover		MONEY
		,BasedTurnoverNoDraw	MONEY
		,GGR					MONEY
		,BasedGGR				MONEY
		,BetCount				INT
		,AvgBetAmount			MONEY
		,BasedAvgBetAmount		MONEY
		,UniquePlayers			INT
		,Margin					MONEY
		,NumberOfDeposit		INT
		,DepositAmount			MONEY
		,BasedDepositAmount		MONEY
		,NumberOfWithdrawal		INT
		,WithdrawalAmount		MONEY
		,BasedWithdrawalAmount	MONEY
	)
	
	-- by date/month
	IF (@GroupBy IN (1, 2))
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,CurrencyId
			,Turnover
			,NetTurnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedNetTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
		)
		SELECT 
			CASE WHEN @GroupBy = 1
				THEN CONVERT(VARCHAR(500), r.rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, r.rptDate), 0), 103), 7)
				END
			,r.CurrencyId
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(TurnoverNoDraw)
			,SUM(BasedTurnOver)
			,SUM(BasedNetTurnOver)
			,SUM(BasedTurnoverNoDraw)
			,SUM(Winloss)
			,SUM(BasedWinloss)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT r.CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(NetTurnOver),0),0) AS MONEY) * 100 AS Margin
			,SUM(d.NumberOfDeposit) AS NumberOfDeposit
			,SUM(d.DepositAmount) AS DepositAmount
			,SUM(d.BasedDepositAmount) AS BasedDepositAmount
			,SUM(w.NumberOfWithdrawal) AS NumberOfWithdrawal
			,SUM(w.WithdrawalAmount) AS WithdrawalAmount
			,SUM(w.BasedWithdrawalAmount) AS BasedWithdrawalAmount
		FROM #__N88_RptWinloss r
			LEFT JOIN #__DepositTable d
				ON r.rptDate = d.rptDate AND r.CurrencyId = d.CurrencyId AND r.CustId = d.CustId
			LEFT JOIN #__WithdrawTable w 
				ON r.rptDate = w.rptDate AND r.CurrencyId = w.CurrencyId AND r.CustId = w.CustId
		GROUP BY
			CASE WHEN @GroupBy = 1
				THEN CONVERT(VARCHAR(500), r.rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, r.rptDate), 0), 103), 7)
				END
			,r.CurrencyId
	END
	-- by product - gametype
	ELSE IF (@GroupBy = 3)
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,CurrencyId
			,Turnover
			,NetTurnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedNetTurnover
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
			,SUM(NetTurnOver)
			,SUM(TurnoverNoDraw)
			,SUM(BasedTurnOver)
			,SUM(BasedNetTurnOver)
			,SUM(BasedTurnoverNoDraw)
			,SUM(Winloss)
			,SUM(BasedWinloss)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT CustId) AS UniquePlayers
			,CAST(ISNULL(SUM(Winloss)/NULLIF(SUM(NetTurnOver),0),0) AS MONEY) * 100 AS Margin
		FROM #__N88_RptWinloss r
			INNER JOIN dbo.TpGameType g WITH (NOLOCK) ON r.GameType = g.Type
		GROUP BY
			g.TypeName
			,CurrencyId
	END
	-- by currency
	ELSE IF (@GroupBy = 4)
	BEGIN
		
		;WITH sumTicket AS
		(
			SELECT
				r.CurrencyId AS [Group]
			   ,r.CurrencyId
			   ,SUM(TurnOver) AS TurnOver
			   ,SUM(NetTurnOver) AS NetTurnOver
			   ,SUM(TurnoverNoDraw) AS TurnoverNoDraw
			   ,SUM(BasedTurnOver) AS BasedTurnOver
			   ,SUM(BasedNetTurnOver) AS BasedNetTurnOver
			   ,SUM(BasedTurnoverNoDraw) AS BasedTurnoverNoDraw
			   ,SUM(Winloss) AS Winloss
			   ,SUM(BasedWinloss) AS BasedWinloss
			   ,SUM(BetCount) AS BetCount
			   ,CAST(ISNULL(SUM(NetTurnOver) / NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS AvgBetAmount
			   ,CAST(ISNULL(SUM(BasedNetTurnOver) / NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS BasedAvgBetAmount
			   ,COUNT(DISTINCT r.CustId) AS UniquePlayers
			   ,CAST(ISNULL(SUM(Winloss) / NULLIF(SUM(NetTurnOver), 0), 0) AS MONEY) * 100 AS Margin
			FROM #__N88_RptWinloss r
			GROUP BY r.CurrencyId
		), sumDeposit AS
		(
			SELECT
					CurrencyId
				   ,SUM(d.NumberOfDeposit) AS NumberOfDeposit
				   ,SUM(d.DepositAmount) AS DepositAmount
				   ,SUM(d.BasedDepositAmount) AS BasedDepositAmount
				FROM #__DepositTable d
					INNER JOIN @tblCustId t
						ON d.CustId = t.CustId
				GROUP BY CurrencyId
		), sumWithdraw AS
		(
			SELECT
					CurrencyId
				   ,SUM(w.NumberOfWithdrawal) AS NumberOfWithdrawal
				   ,SUM(w.WithdrawalAmount) AS WithdrawalAmount
				   ,SUM(w.BasedWithdrawalAmount) AS BasedWithdrawalAmount
				FROM #__WithdrawTable w
					INNER JOIN @tblCustId t
						ON w.CustId = t.CustId
				GROUP BY CurrencyId
		)
		INSERT INTO #__tmpResult 
		(
			[Group]
			,CurrencyId
			,Turnover
			,NetTurnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedNetTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
		)
		SELECT 
			r.[Group], r.CurrencyId, r.TurnOver, r.NetTurnOver, r.TurnoverNoDraw, r.BasedTurnOver, r.BasedNetTurnOver, r.BasedTurnoverNoDraw,
			r.Winloss, r.BasedWinloss, r.BetCount, r.AvgBetAmount, r.BasedAvgBetAmount, r.UniquePlayers, r.Margin
			,d.NumberOfDeposit, d.DepositAmount, d.BasedDepositAmount, w.NumberOfWithdrawal, w.WithdrawalAmount, w.BasedWithdrawalAmount
		FROM sumTicket r
			LEFT JOIN sumDeposit d
				ON r.CurrencyId = d.CurrencyId
			LEFT JOIN sumWithdraw w
				ON r.CurrencyId = w.CurrencyId
	END
	-- by player
	ELSE IF (@GroupBy = 5)
	BEGIN
		;WITH CTE_Result AS 
		(
			SELECT r.CustId
				,TurnOver = SUM(TurnOver)
				,NetTurnOver = SUM(NetTurnOver)
				,TurnoverNoDraw = SUM(TurnoverNoDraw)
				,BasedTurnOver = SUM(BasedTurnOver)
				,BasedNetTurnOver = SUM(BasedNetTurnOver)
				,BasedTurnoverNoDraw = SUM(BasedTurnoverNoDraw)
				,Winloss = SUM(Winloss)
				,BasedWinloss = SUM(BasedWinloss)
				,BetCount = SUM(BetCount)
			FROM #__N88_RptWinloss r
			GROUP BY r.CustId
		), sumDeposit AS
		(
			SELECT
					d.CustId
				   ,SUM(d.NumberOfDeposit) AS NumberOfDeposit
				   ,SUM(d.DepositAmount) AS DepositAmount
				   ,SUM(d.BasedDepositAmount) AS BasedDepositAmount
				FROM #__DepositTable d
					INNER JOIN @tblCustId t
						ON d.CustId = t.CustId
				GROUP BY d.CustId
		), sumWithdraw AS
		(
			SELECT
					w.CustId
				   ,SUM(w.NumberOfWithdrawal) AS NumberOfWithdrawal
				   ,SUM(w.WithdrawalAmount) AS WithdrawalAmount
				   ,SUM(w.BasedWithdrawalAmount) AS BasedWithdrawalAmount
				FROM #__WithdrawTable w
					INNER JOIN @tblCustId t
						ON w.CustId = t.CustId
				GROUP BY w.CustId
		)
		INSERT INTO #__tmpResult
		(
			[Group]
			,CustId
			,SabaId
			,SabaSystemId
			,CurrencyId
			,Turnover
			,NetTurnover
			,TurnoverNoDraw
			,BasedTurnover
			,BasedNetTurnover
			,BasedTurnoverNoDraw
			,GGR
			,BasedGGR
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,Margin
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
		)
		SELECT 
			c.UserName
			,c.CustId
			,c.TpUserName
			,c.TpSystemUserName
			,c.CurrencyId
			,r.TurnOver
			,r.NetTurnOver
			,r.TurnoverNoDraw
			,r.BasedTurnOver
			,r.BasedNetTurnOver
			,r.BasedTurnoverNoDraw
			,r.Winloss
			,r.BasedWinloss
			,r.BetCount
			,CASE WHEN BetCount = 0 THEN 0 ELSE NetTurnOver/BetCount END
			,CASE WHEN BetCount = 0 THEN 0 ELSE BasedNetTurnOver/BetCount END
			,1 AS UniquePlayers
			,CASE WHEN NetTurnOver = 0 THEN 0 ELSE Winloss/NetTurnOver * 100 END
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
		FROM CTE_Result r
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			LEFT JOIN sumDeposit d
				ON r.CustId = d.CustId
			LEFT JOIN sumWithdraw w
				ON r.CustId = w.CustId
	END

	-- 3. Final result
	CREATE TABLE #__FinalResult 
	(
		RowNumber				INT
		,[Group]				VARCHAR(500)
		,CustId					INT
		,SabaId					VARCHAR(50)
		,SabaSystemId			VARCHAR(50)
		,CurrencyId				INT
		,Turnover				MONEY
		,NetTurnover			MONEY
		,TurnoverNoDraw			MONEY
		,BasedTurnover			MONEY
		,BasedNetTurnover		MONEY
		,BasedTurnoverNoDraw	MONEY
		,GGR					MONEY
		,BasedGGR				MONEY
		,BetCount				INT
		,AvgBetAmount			MONEY
		,BasedAvgBetAmount		MONEY
		,UniquePlayers			INT
		,Margin					MONEY
		,NumberOfDeposit		INT
		,DepositAmount			MONEY
		,BasedDepositAmount		MONEY
		,NumberOfWithdrawal		INT
		,WithdrawalAmount		MONEY
		,BasedWithdrawalAmount	MONEY
	)

	DECLARE @RowStart INT , @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	INSERT INTO #__FinalResult
	SELECT 
		DENSE_RANK() OVER(ORDER BY [Group] + CASE WHEN @GroupBy = 5 THEN CONVERT(VARCHAR(20), CustId) ELSE '' END) RowNumber,
		[Group]
		,CustId
		,SabaId
		,SabaSystemId
		,CurrencyId
		,Turnover
		,NetTurnover
		,TurnoverNoDraw
		,BasedTurnover
		,BasedNetTurnover
		,BasedTurnoverNoDraw
		,GGR
		,BasedGGR
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,Margin
		,NumberOfDeposit		
		,DepositAmount
		,BasedDepositAmount
		,NumberOfWithdrawal		
		,WithdrawalAmount	
		,BasedWithdrawalAmount
	FROM #__tmpResult

	DROP TABLE #__tmpResult

	--return data
	SELECT @TotalRows = MAX(RowNumber) FROM #__FinalResult

	SELECT RowNumber,
		[Group]
		,CustId
		,SabaId
		,SabaSystemId
		,CurrencyId
		,Turnover
		,NetTurnover
		,TurnoverNoDraw
		,BasedTurnover
		,BasedNetTurnover
		,BasedTurnoverNoDraw
		,(-1) * GGR AS GGR
		,(-1) * BasedGGR AS BasedGGR
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,(-1) * ISNULL((CASE WHEN @IsDetailInOriginalCurr = 0 THEN BasedGGR/NULLIF(BasedNetTurnover, 0) ELSE GGR/NULLIF(NetTurnover, 0) END), 0) * 100 AS Margin
		,ISNULL(NumberOfDeposit, 0) AS NumberOfDeposit
		,ISNULL(DepositAmount, 0) AS DepositAmount
		,ISNULL(BasedDepositAmount, 0) AS BasedDepositAmount
		,ISNULL(NumberOfWithdrawal, 0) AS NumberOfWithdrawal		
		,ISNULL(WithdrawalAmount, 0) AS	WithdrawalAmount	
		,ISNULL(BasedWithdrawalAmount, 0) AS BasedWithdrawalAmount
	FROM #__FinalResult
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 
	ORDER BY [Group], CurrencyId

	-- total
	IF (@GroupBy IN (1,2))
	BEGIN
		SELECT
			CAST(SUM(BasedTurnover) AS MONEY) AS TotalBasedTurnover
			,CAST(SUM(BasedNetTurnover) AS MONEY) AS TotalBasedNetTurnover
			,CAST(SUM(BasedTurnoverNoDraw) AS MONEY) AS TotalBasedTurnoverNoDraw
			,(-1) * CAST(SUM(BasedWinloss) AS MONEY) AS TotalBasedGGR
			,SUM(BetCount) AS TotalBetCount
			,CAST(ISNULL(SUM(BasedNetTurnover)/NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS TotalBasedAvgBetAmount
			,COUNT(DISTINCT r.CustId) AS TotalUniquePlayers
			,(-1) * ISNULL(SUM(CAST(BasedWinloss AS MONEY))/NULLIF(SUM(BasedNetTurnover), 0), 0) * 100 AS TotalMargin
			,ISNULL(SUM(d.NumberOfDeposit), 0) AS TotalNumberOfDeposit
			,ISNULL(CAST(SUM(d.BasedDepositAmount) AS MONEY), 0) AS TotalBasedDepositAmount
			,ISNULL(SUM(w.NumberOfWithdrawal), 0) AS TotalNumberOfWithdrawal
			,ISNULL(CAST(SUM(w.BasedWithdrawalAmount) AS MONEY), 0) AS TotalBasedWithdrawalAmount
		FROM #__N88_RptWinloss r
			LEFT JOIN #__DepositTable d
				ON r.rptDate = d.rptDate AND r.CurrencyId = d.CurrencyId AND r.CustId = d.CustId
			LEFT JOIN #__WithdrawTable w 
				ON r.rptDate = w.rptDate AND r.CurrencyId = w.CurrencyId AND r.CustId = w.CustId
	END
	ELSE IF (@GroupBy IN (4,5))
	BEGIN
		;WITH sumTicket AS
		(
			SELECT
				CAST(SUM(BasedTurnover) AS MONEY) AS TotalBasedTurnover
				,CAST(SUM(BasedNetTurnover) AS MONEY) AS TotalBasedNetTurnover
				,CAST(SUM(BasedTurnoverNoDraw) AS MONEY) AS TotalBasedTurnoverNoDraw
				,(-1) * CAST(SUM(BasedWinloss) AS MONEY) AS TotalBasedGGR
				,SUM(BetCount) AS TotalBetCount
				,CAST(ISNULL(SUM(BasedNetTurnover)/NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS TotalBasedAvgBetAmount
				,COUNT(DISTINCT r.CustId) AS TotalUniquePlayers
				,(-1) * ISNULL(SUM(CAST(BasedWinloss AS MONEY))/NULLIF(SUM(BasedNetTurnover), 0), 0) * 100 AS TotalMargin
			FROM #__N88_RptWinloss r
		), sumDeposit AS
		(
			SELECT
				ISNULL(SUM(d.NumberOfDeposit), 0) AS TotalNumberOfDeposit
				,ISNULL(CAST(SUM(d.BasedDepositAmount) AS MONEY), 0) AS TotalBasedDepositAmount
				FROM #__DepositTable d
					INNER JOIN @tblCustId t
						ON d.CustId = t.CustId
		), sumWithdraw AS
		(
			SELECT
				ISNULL(SUM(w.NumberOfWithdrawal), 0) AS TotalNumberOfWithdrawal
				,ISNULL(CAST(SUM(w.BasedWithdrawalAmount) AS MONEY), 0) AS TotalBasedWithdrawalAmount
				FROM #__WithdrawTable w
					INNER JOIN @tblCustId t
						ON w.CustId = t.CustId
		)
		SELECT *
		FROM sumTicket, sumDeposit, sumWithdraw
	END
	ELSE
	BEGIN
		SELECT
			CAST(SUM(BasedTurnover) AS MONEY) AS TotalBasedTurnover
			,CAST(SUM(BasedNetTurnover) AS MONEY) AS TotalBasedNetTurnover
			,CAST(SUM(BasedTurnoverNoDraw) AS MONEY) AS TotalBasedTurnoverNoDraw
			,(-1) * CAST(SUM(BasedWinloss) AS MONEY) AS TotalBasedGGR
			,SUM(BetCount) AS TotalBetCount
			,CAST(ISNULL(SUM(BasedNetTurnover)/NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS TotalBasedAvgBetAmount
			,COUNT(DISTINCT r.CustId) AS TotalUniquePlayers
			,(-1) * ISNULL(SUM(CAST(BasedWinloss AS MONEY))/NULLIF(SUM(BasedNetTurnover), 0), 0) * 100 AS TotalMargin
			,0 AS TotalNumberOfDeposit
			,0 AS TotalBasedDepositAmount
			,0 AS TotalNumberOfWithdrawal
			,0 AS TotalBasedWithdrawalAmount
		FROM #__N88_RptWinloss r
	END

	DROP TABLE #__FinalResult
	DROP TABLE #__N88_RptWinloss
	DROP TABLE #__DepositTable
	DROP TABLE #__WithdrawTable

END
GO