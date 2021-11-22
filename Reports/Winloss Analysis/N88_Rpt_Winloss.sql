/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
USE bodb_N88
GO

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
	,@IsIncludedFreeSpin		BIT = 1
	,@IsNoDrawTicket			BIT
	,@IsIncludedTestData		BIT
	,@IsDetailInOriginalCurr	BIT = 0
	,@TimeZone					SMALLINT = 8
	,@SortbyId					TINYINT = 1
	,@IsSortAsc					BIT = 1
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
		- 20210113@Sol: group by player - group wl and dep/wit into one row - [RedmineID: #147542]
		- 20210223@Percy: Change data source from N88_RptWinloss to N88_SumWinloss to support all time zones [RedmineID: #150398]
		- 20210316@Percy: Include free bet tickets into No draw option [RedmineID: #146210]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - [RedmineID: #155334]
			+ include free spin filter
			+ add closing balance to the report
		- 20210616@Sol: MPA - Hotfix - Incorrect closing balance - [RedmineID: #157073]
		- 20210715@Percy: Exclude Jackpot, Contribition from Win Loss (GGR) [RedmineID: #158438]
		- 20210907@Percy: Enhance code get CustClosingBalance [RedmineID: #161291]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]

	Param's Explanation:
		@SortbyId:
			.  1 = Group
			.  2 = Turnover
			.  3 = Valid Turnover
			.  4 = GGR
			.  5 = Player Win Loss
			.  6 = Progressive Win
			.  7 = Progressive Bet
			.  8 = BetCount
			.  9 = Avg Bet Amount
			. 10 = Unique Players
			. 11 = Margin
			. 12 = Closing Balance
			. 13 = No. Deposit
			. 14 = Total Deposit Amount
			. 15 = No. Withdrawal
			. 16 = Total Withdrawal Amount
			. 17 = Total Bonus Amount
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TotalBasedClosingBalance MONEY
	DECLARE @FDate DATE, @TDate DATE
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
		,TurnoverNoDraw				MONEY
		,Revenue					MONEY
		,RevenueForMargin			MONEY
		,Winloss					MONEY
		,ProgressiveWin				MONEY
		,ProgressiveBet				MONEY
		,BasedTurnOver				MONEY
		,BasedNetTurnOver			MONEY
		,BasedNetTurnOverForMargin	MONEY
		,BasedTurnoverNoDraw		MONEY
		,BasedRevenue				MONEY
		,BasedRevenueForMargin		MONEY
		,BasedWinloss				MONEY
		,BasedProgressiveWin		MONEY
		,BasedProgressiveBet		MONEY
		,NumberOfDeposit			INT
		,DepositAmount				MONEY
		,BasedDepositAmount			MONEY
		,NumberOfWithdrawal			INT
		,WithdrawalAmount			MONEY
		,BasedWithdrawalAmount		MONEY
		,BonusAmount				MONEY
		,BasedBonusAmount			MONEY
		,IsExtraUser				BIT DEFAULT (0) -- for count player who has placed bet
	)
	CREATE CLUSTERED INDEX CIX_N88_SumWinloss ON #__N88_SumWinloss (CustId)

	CREATE TABLE #__Exchange (FromDate DATE, ToDate DATE, ExchangeId TINYINT, Rate FLOAT, MultipleBy FLOAT)
	CREATE CLUSTERED INDEX CIX_Exchange ON #__Exchange (ExchangeId, FromDate)

	--closing balance temp table
	CREATE TABLE #__ClosingBalance (CustId INT, ClosingBalance MONEY, BasedClosingBalance MONEY)
	
	DECLARE @MinDate DATE, @MaxDate DATE, @TicketStatus VARCHAR(50) = '1,2' -- win, loss

	SELECT @TicketStatus = @TicketStatus + CASE WHEN @IsNoDrawTicket = 0 THEN ',4' ELSE '' END -- draw ticket
	SELECT @TicketStatus = @TicketStatus + CASE WHEN @IsIncludedFreeSpin = 1 THEN ',6' ELSE '' END -- free spin ticket
	
	---- by winlostdate
	IF (@FilterBy = 1)
	BEGIN
		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ExchangeId, Rate, CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_SumWinloss
		(
			rptDate, GameType, CustId, CurrencyId
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, TurnoverNoDraw, Revenue, RevenueForMargin, Winloss, ProgressiveWin, ProgressiveBet
			,BasedTurnOver, BasedNetTurnOver, BasedNetTurnOverForMargin, BasedTurnoverNoDraw, BasedRevenue, BasedRevenueForMargin, BasedWinloss, BasedProgressiveWin, BasedProgressiveBet
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(NetTurnOverForMargin)
			,SUM(TurnOverNoDraw)
			,SUM(Revenue)
			,SUM(RevenueForMargin)
			,SUM(Winloss)
			,SUM(ProgressiveWin)
			,SUM(ProgressiveBet)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
			,SUM(NetTurnOverForMargin * e.Rate)
			,SUM(TurnOverNoDraw * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(RevenueForMargin * e.Rate)
			,SUM(Winloss * e.Rate)
			,SUM(ProgressiveWin * e.Rate)
			,SUM(ProgressiveBet * e.Rate)
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,r.CustId
				,r.Currency
				,rptDate				= CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,GameType				= CASE WHEN @GroupBy = 3 THEN r.GameType END
				,TurnOver				= SUM(TurnOver)
				,NetTurnOver			= SUM(ValidBet)
				,NetTurnOverForMargin	= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE ValidBet END)
				,TurnOverNoDraw			= SUM(CASE WHEN StatusId = 4 THEN 0 ELSE TurnOver END)
				,Revenue				= SUM(CASE WHEN r.GameType IN (41, 42) THEN ISNULL(Revenue, 0) ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,RevenueForMargin		= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,Winloss				= SUM(Winloss)
				,ProgressiveWin			= SUM(ISNULL(ProgressiveWin, 0))
				,ProgressiveBet			= SUM(ISNULL(ProgressiveBet, 0))
				,BetCount				= SUM(BetCount)
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
			WHERE r.SettledTime >= @FromDateTimeGMT0 AND r.SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.SiteId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND ',' + @TicketStatus + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.StatusId) + ',%'
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime))
				,r.CustId
				,r.Currency
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,CASE WHEN @GroupBy = 3 THEN r.GameType END
		) r
			INNER JOIN #__Exchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
		GROUP BY rptDate, GameType, CustId, Currency
	END
	---- by transdate
	ELSE 
	BEGIN
		SELECT @MinDate = MIN(CONVERT(DATE, SettledTime)), @MaxDate = MAX(CONVERT(DATE, SettledTime))
		FROM dbo.N88_SumWinloss WITH (NOLOCK) WHERE TransTime >= @FromDateTimeGMT0 AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)

		SELECT @MinDate = DATEADD(DAY, -1, @MinDate), @MaxDate = DATEADD(DAY, 1, @MaxDate)

		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ExchangeId, Rate, CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_SumWinloss
		(
			rptDate, GameType, CustId, CurrencyId
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, TurnoverNoDraw, Revenue, RevenueForMargin, Winloss, ProgressiveWin, ProgressiveBet
			,BasedTurnOver, BasedNetTurnOver, BasedNetTurnOverForMargin, BasedTurnoverNoDraw, BasedRevenue, BasedRevenueForMargin, BasedWinloss, BasedProgressiveWin, BasedProgressiveBet
		)
		SELECT rptDate, GameType, CustId, Currency
			,SUM(BetCount)
			,SUM(TurnOver)
			,SUM(NetTurnOver)
			,SUM(NetTurnOverForMargin)
			,SUM(TurnOverNoDraw)
			,SUM(Revenue)
			,SUM(RevenueForMargin)
			,SUM(Winloss)
			,SUM(ProgressiveWin)
			,SUM(ProgressiveBet)
			,SUM(TurnOver * e.Rate)
			,SUM(NetTurnOver * e.Rate)
			,SUM(NetTurnOverForMargin * e.Rate)
			,SUM(TurnOverNoDraw * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(RevenueForMargin * e.Rate)
			,SUM(Winloss * e.Rate)
			,SUM(ProgressiveWin * e.Rate)
			,SUM(ProgressiveBet * e.Rate)
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,r.CustId
				,r.Currency
				,rptDate				= CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,GameType				= CASE WHEN @GroupBy = 3 THEN r.GameType END
				,TurnOver				= SUM(TurnOver)
				,NetTurnOver			= SUM(ValidBet)
				,NetTurnOverForMargin	= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE ValidBet END)
				,TurnOverNoDraw			= SUM(CASE WHEN StatusId = 4 THEN 0 ELSE TurnOver END)
				,Revenue				= SUM(CASE WHEN r.GameType IN (41, 42) THEN ISNULL(Revenue, 0) ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,RevenueForMargin		= SUM(CASE WHEN r.GameType IN (41, 42) THEN 0 ELSE -(Winloss - ISNULL(ProgressiveWin, 0) + ISNULL(ProgressiveBet, 0)) END)
				,Winloss				= SUM(Winloss)
				,ProgressiveWin			= SUM(ISNULL(ProgressiveWin, 0))
				,ProgressiveBet			= SUM(ISNULL(ProgressiveBet, 0))
				,BetCount				= SUM(BetCount)
			FROM dbo.N88_SumWinloss r WITH (NOLOCK)
			WHERE r.TransTime >= @FromDateTimeGMT0 AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.SiteId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND ',' + @TicketStatus + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.StatusId) + ',%'
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime))
				,r.CustId
				,r.Currency
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,CASE WHEN @GroupBy = 3 THEN r.GameType END
		) r
			INNER JOIN #__Exchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.Currency = e.ExchangeId
		GROUP BY rptDate, GameType, CustId, Currency
	END

	-- Reset Exchange
	DELETE #__Exchange
	INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate, MultipleBy)
	SELECT FromDate, ToDate, ExchangeId, CASE WHEN @IsDetailInOriginalCurr = 0 THEN Rate ELSE 1 END, CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
	WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
	
	-- Deposit/Withdrawal/Bonus
	BEGIN 
		-- Deposit: DepositInfo
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, NumberOfDeposit, DepositAmount, BasedDepositAmount, IsExtraUser)
		SELECT d.rptDate, d.CustId, d.CurrencyId, SUM(d.BetCount), SUM(d.Amount / e.MultipleBy), SUM(d.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,COUNT(1) AS BetCount, SUM(Amount) AS Amount
			FROM dbo.DepositInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 3 -- Approved
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) d
			INNER JOIN #__Exchange e ON d.CurrencyId = e.ExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY d.rptDate, d.CustId, d.CurrencyId
		
		-- Withdrawal: WithdrawalInfo
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, NumberOfWithdrawal, WithdrawalAmount, BasedWithdrawalAmount, IsExtraUser)
		SELECT w.rptDate, w.CustId, w.CurrencyId, SUM(w.BetCount), SUM(w.Amount / e.MultipleBy), SUM(w.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,COUNT(1) AS BetCount, SUM(Amount) AS Amount
			FROM dbo.WithdrawalInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 6 -- Approved
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) w
			INNER JOIN #__Exchange e ON w.CurrencyId = e.ExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY w.rptDate, w.CustId, w.CurrencyId

		-- Bonus: BonusInfo
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, BonusAmount, BasedBonusAmount, IsExtraUser)
		SELECT b.rptDate, b.CustId, b.CurrencyId, SUM(b.Amount / e.MultipleBy), SUM(b.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(BonusAmount) AS Amount
			FROM dbo.BonusInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) b
			INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY b.rptDate, b.CustId, b.CurrencyId

		-- Bonus: RebateMLog
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, BonusAmount, BasedBonusAmount, IsExtraUser)
		SELECT b.rptDate, b.CustId, b.CurrencyId, SUM(b.Amount / e.MultipleBy), SUM(b.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(RedeemAmount) AS Amount
			FROM dbo.RebateMLog WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) b
			INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY b.rptDate, b.CustId, b.CurrencyId

		-- Bonus: DrawLog
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, BonusAmount, BasedBonusAmount, IsExtraUser)
		SELECT b.rptDate, b.CustId, b.CurrencyId, SUM(b.Amount / e.MultipleBy), SUM(b.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, DrawTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, DrawTime)) AS ExchangeDate
				,SUM(Amount) AS Amount
			FROM dbo.DrawLog WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND DrawTime >= @FromDateTimeGMT0 AND DrawTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, DrawTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, DrawTime))
		) b
			INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY b.rptDate, b.CustId, b.CurrencyId

		-- Bonus: AdjustmentInfo
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, BonusAmount, BasedBonusAmount, IsExtraUser)
		SELECT b.rptDate, b.CustId, b.CurrencyId, SUM(b.Amount / e.MultipleBy), SUM(b.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(Amount * CASE
								WHEN AdjustType IN (1, 3) THEN 1 -- Credit, Increase bonus
								WHEN AdjustType IN (2, 4) THEN -1 -- Debit, Decrease bonus
								ELSE 0 END) AS Amount
			FROM dbo.AdjustmentInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 2 -- Approved
				AND 1 = CASE WHEN CreateTime < '2021-10-31 16:00' OR AdjustType IN (3, 4) THEN 1 ELSE 0 END -- From 1 Nov 2021 (GMT+8), just get Increase & Decrease bonus
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) b
			INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY b.rptDate, b.CustId, b.CurrencyId

		-- Bonus: LogAdminAdjustWallet
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, BonusAmount, BasedBonusAmount, IsExtraUser)
		SELECT b.rptDate, b.CustId, b.CurrencyId, SUM(b.Amount / e.MultipleBy), SUM(b.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,SUM(Amount * CASE
								WHEN Direction = 1 THEN 1 -- 3rd Add
								WHEN Direction = 2 THEN -1 -- 3rd Minus
								ELSE 0 END) AS Amount
			FROM dbo.LogAdminAdjustWallet WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 0 -- Success
				AND CreateTime < '2021-10-31 16:00' -- only get data before 1 Nov 2021 (GMT+8)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) b
			INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY b.rptDate, b.CustId, b.CurrencyId

		-- Bonus: VIPUpgradeReview
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, CurrencyId, BonusAmount, BasedBonusAmount, IsExtraUser)
		SELECT b.rptDate, b.CustId, b.CurrencyId, SUM(b.Amount / e.MultipleBy), SUM(b.Amount * e.Rate / e.MultipleBy), 1
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, SettleTime)) AS rptDate, CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, SettleTime)) AS ExchangeDate
				,SUM(UpgradeAmount) AS Amount
			FROM dbo.VIPUpgradeReview WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND SettleTime >= @FromDateTimeGMT0 AND SettleTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 4 -- Settled
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, SettleTime)), CustId, CurrencyId
				,CONVERT(DATE, DATEADD(HOUR, -4, SettleTime))
		) b
			INNER JOIN #__Exchange e ON b.CurrencyId = e.ExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
		GROUP BY b.rptDate, b.CustId, b.CurrencyId
	END
	----end

	IF @IsIncludedTestData = 0 OR ISNULL(@UserName, '') <> ''
		DELETE s
		FROM #__N88_SumWinloss s
		WHERE NOT EXISTS (
			SELECT 1 FROM dbo.Customer c WITH (NOLOCK)
			WHERE c.CustId = s.CustId
				AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
				AND (
					ISNULL(@UserName, '') = ''
					OR @UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
										WHEN @UserNameFilterId = 2 THEN c.TpUserName
										WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
									END
				)
		)

	----cal closing balance
	BEGIN
		;WITH rs AS (
			SELECT 
				CONVERT(DATETIME, MAX(cb.TIME)) AS mTime, 
				CONVERT(DATE, MAX(CONVERT(DATE, DATEADD(HOUR,-4, cb.TIME)))) AS exTime,
				cb.CustId, cb.SiteId, c.CurrencyId
			FROM dbo.CustClosingBalance cb
				INNER JOIN (SELECT DISTINCT CustId, CurrencyId FROM #__N88_SumWinloss) c ON cb.CustId = c.CustId
			WHERE cb.Time >= @FromDateTimeGMT0 AND cb.Time < DATEADD(DAY, 1, @ToDateTimeGMT0)
			GROUP BY cb.CustId, cb.SiteId, c.CurrencyId
		)
		INSERT INTO #__ClosingBalance (CustId, ClosingBalance, BasedClosingBalance)
		SELECT cb.CustId, SUM(cb.Balance / e.MultipleBy), SUM(cb.Balance / e.MultipleBy * e.Rate)
		FROM dbo.CustClosingBalance cb
			INNER JOIN rs ON cb.Time = rs.mTime AND cb.CustId = rs.CustId AND cb.SiteId = rs.SiteId
			INNER JOIN #__Exchange e ON rs.CurrencyId = e.ExchangeId AND rs.exTime BETWEEN e.FromDate AND e.ToDate
		GROUP BY cb.CustId
	END

	DROP TABLE #__Exchange

	-- 2. Calc temp result
	CREATE TABLE #__tmpResult 
	(
		[Group]						VARCHAR(500)
		,CustId						INT
		,SabaId						VARCHAR(50)
		,SabaSystemId				VARCHAR(50)
		,CurrencyId					INT
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
		,ProgressiveWin				MONEY
		,ProgressiveBet				MONEY
		,BasedProgressiveWin		MONEY
		,BasedProgressiveBet		MONEY
		,BetCount					INT
		,AvgBetAmount				MONEY
		,BasedAvgBetAmount			MONEY
		,UniquePlayers				INT
		,NumberOfDeposit			INT
		,DepositAmount				MONEY
		,BasedDepositAmount			MONEY
		,NumberOfWithdrawal			INT
		,WithdrawalAmount			MONEY
		,BasedWithdrawalAmount		MONEY
		,BonusAmount				MONEY
		,BasedBonusAmount			MONEY
		,ClosingBalance				MONEY 
		,BasedClosingBalance		MONEY
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
			,ProgressiveWin
			,ProgressiveBet
			,BasedProgressiveWin
			,BasedProgressiveBet
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
			,BonusAmount
			,BasedBonusAmount
		)
		SELECT 
			CASE WHEN @GroupBy = 1
				THEN CONVERT(VARCHAR(500), rptDate, 101)
				ELSE RIGHT(CONVERT(VARCHAR(10), DATEADD(MONTH, DATEDIFF(MONTH, 0, rptDate), 0), 103), 7)
				END
			,CurrencyId
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
			,SUM(ProgressiveWin)
			,SUM(ProgressiveBet)
			,SUM(BasedProgressiveWin)
			,SUM(BasedProgressiveBet)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT (CASE WHEN IsExtraUser = 0 THEN CustId ELSE NULL END)) AS UniquePlayers
			,SUM(NumberOfDeposit) AS NumberOfDeposit
			,SUM(DepositAmount) AS DepositAmount
			,SUM(BasedDepositAmount) AS BasedDepositAmount
			,SUM(NumberOfWithdrawal) AS NumberOfWithdrawal
			,SUM(WithdrawalAmount) AS WithdrawalAmount
			,SUM(BasedWithdrawalAmount) AS BasedWithdrawalAmount
			,SUM(BonusAmount) AS BonusAmount
			,SUM(BasedBonusAmount) AS BasedBonusAmount
		FROM #__N88_SumWinloss
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
			,ProgressiveWin
			,ProgressiveBet
			,BasedProgressiveWin
			,BasedProgressiveBet
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
		)
		SELECT 
			g.TypeName
			,CurrencyId
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
			,SUM(ProgressiveWin)
			,SUM(ProgressiveBet)
			,SUM(BasedProgressiveWin)
			,SUM(BasedProgressiveBet)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT (CASE WHEN IsExtraUser = 0 THEN CustId ELSE NULL END)) AS UniquePlayers
		FROM #__N88_SumWinloss r
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
			,ProgressiveWin
			,ProgressiveBet
			,BasedProgressiveWin
			,BasedProgressiveBet
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
			,BonusAmount
			,BasedBonusAmount
		)
		SELECT 
			CurrencyId
			,CurrencyId
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
			,SUM(ProgressiveWin)
			,SUM(ProgressiveBet)
			,SUM(BasedProgressiveWin)
			,SUM(BasedProgressiveBet)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT (CASE WHEN IsExtraUser = 0 THEN CustId ELSE NULL END)) AS UniquePlayers
			,SUM(NumberOfDeposit) AS NumberOfDeposit
			,SUM(DepositAmount) AS DepositAmount
			,SUM(BasedDepositAmount) AS BasedDepositAmount
			,SUM(NumberOfWithdrawal) AS NumberOfWithdrawal
			,SUM(WithdrawalAmount) AS WithdrawalAmount
			,SUM(BasedWithdrawalAmount) AS BasedWithdrawalAmount
			,SUM(BonusAmount) AS BonusAmount
			,SUM(BasedBonusAmount) AS BasedBonusAmount
		FROM #__N88_SumWinloss r
		GROUP BY
			CurrencyId
	END
	-- by player
	ELSE IF (@GroupBy = 5)
	BEGIN
		;WITH CTE_Result AS (
			SELECT s.CustId
				,TurnOver = SUM(TurnOver)
				,NetTurnOver = SUM(NetTurnOver)
				,NetTurnOverForMargin = SUM(NetTurnOverForMargin)
				,TurnoverNoDraw = SUM(TurnoverNoDraw)
				,BasedTurnOver = SUM(BasedTurnOver)
				,BasedNetTurnOver = SUM(BasedNetTurnOver)
				,BasedNetTurnOverForMargin = SUM(BasedNetTurnOverForMargin)
				,BasedTurnoverNoDraw = SUM(BasedTurnoverNoDraw)
				,Winloss = SUM(Winloss)
				,BasedWinloss = SUM(BasedWinloss)
				,Revenue = SUM(Revenue)
				,BasedRevenue = SUM(BasedRevenue)
				,RevenueForMargin = SUM(RevenueForMargin)
				,BasedRevenueForMargin = SUM(BasedRevenueForMargin)
				,ProgressiveWin = SUM(ProgressiveWin)
				,ProgressiveBet = SUM(ProgressiveBet)
				,BasedProgressiveWin = SUM(BasedProgressiveWin)
				,BasedProgressiveBet = SUM(BasedProgressiveBet)
				,BetCount = SUM(BetCount)
				,NumberOfDeposit = SUM(NumberOfDeposit)	
				,DepositAmount = SUM(DepositAmount)
				,BasedDepositAmount = SUM(BasedDepositAmount)
				,NumberOfWithdrawal = SUM(NumberOfWithdrawal)	
				,WithdrawalAmount = SUM(WithdrawalAmount)
				,BasedWithdrawalAmount = SUM(BasedWithdrawalAmount)
				,BonusAmount = SUM(BonusAmount)
				,BasedBonusAmount = SUM(BasedBonusAmount)
			FROM #__N88_SumWinloss s
			GROUP BY s.CustId
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
			,ProgressiveWin
			,ProgressiveBet
			,BasedProgressiveWin
			,BasedProgressiveBet
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
			,BonusAmount
			,BasedBonusAmount
			,ClosingBalance
			,BasedClosingBalance
		)
		SELECT 
			c.UserName
			,c.CustId
			,c.TpUserName
			,c.TpSystemUserName
			,c.CurrencyId
			,r.TurnOver
			,r.NetTurnOver
			,r.NetTurnOverForMargin
			,r.TurnoverNoDraw
			,r.BasedTurnOver
			,r.BasedNetTurnOver
			,r.BasedNetTurnOverForMargin
			,r.BasedTurnoverNoDraw
			,r.Revenue
			,r.BasedRevenue
			,r.RevenueForMargin
			,r.BasedRevenueForMargin
			,r.Winloss
			,r.BasedWinloss
			,r.ProgressiveWin
			,r.ProgressiveBet
			,r.BasedProgressiveWin
			,r.BasedProgressiveBet
			,r.BetCount
			,CASE WHEN ISNULL(BetCount, 0) = 0 THEN 0 ELSE NetTurnOver/BetCount END
			,CASE WHEN ISNULL(BetCount, 0) = 0 THEN 0 ELSE BasedNetTurnOver/BetCount END
			,CASE WHEN ISNULL(BetCount, 0) = 0 THEN 0 ELSE 1 END AS UniquePlayers
			,NumberOfDeposit		
			,DepositAmount
			,BasedDepositAmount
			,NumberOfWithdrawal		
			,WithdrawalAmount	
			,BasedWithdrawalAmount
			,BonusAmount
			,BasedBonusAmount
			,CASE WHEN @TimeZone IN (7, 8) THEN ISNULL(cb.ClosingBalance, 0) ELSE 0 END
			,CASE WHEN @TimeZone IN (7, 8) THEN ISNULL(cb.BasedClosingBalance, 0) ELSE 0 END
		FROM CTE_Result r
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			LEFT JOIN #__ClosingBalance cb 
				ON r.CustId = cb.CustId
	END

	-- 3. Final result
	CREATE TABLE #__FinalResult 
	(
		RowNumber					INT
		,GroupId					INT
		,[Group]					VARCHAR(500)
		,CustId						INT
		,SabaId						VARCHAR(50)
		,SabaSystemId				VARCHAR(50)
		,CurrencyId					INT
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
		,ProgressiveWin				MONEY
		,ProgressiveBet				MONEY
		,BasedProgressiveWin		MONEY
		,BasedProgressiveBet		MONEY
		,BetCount					INT
		,AvgBetAmount				MONEY
		,BasedAvgBetAmount			MONEY
		,UniquePlayers				INT
		,NumberOfDeposit			INT
		,DepositAmount				MONEY
		,BasedDepositAmount			MONEY
		,NumberOfWithdrawal			INT
		,WithdrawalAmount			MONEY
		,BasedWithdrawalAmount		MONEY
		,BonusAmount				MONEY
		,BasedBonusAmount			MONEY
		,ClosingBalance				MONEY 
		,BasedClosingBalance		MONEY
	)

	DECLARE @RowStart INT , @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	INSERT INTO #__FinalResult
	(
		GroupId
		,[Group]
		,CustId
		,SabaId
		,SabaSystemId
		,CurrencyId
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
		,ProgressiveWin
		,ProgressiveBet
		,BasedProgressiveWin
		,BasedProgressiveBet
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,NumberOfDeposit
		,DepositAmount
		,BasedDepositAmount
		,NumberOfWithdrawal
		,WithdrawalAmount
		,BasedWithdrawalAmount
		,BonusAmount
		,BasedBonusAmount
		,ClosingBalance
		,BasedClosingBalance
	)
	SELECT
		DENSE_RANK() OVER(ORDER BY [Group] + CASE WHEN @GroupBy = 5 THEN CONVERT(VARCHAR(20), CustId) ELSE '' END) RowNumber,
		[Group]
		,CustId
		,SabaId
		,SabaSystemId
		,CurrencyId
		,ISNULL(Turnover, 0)
		,ISNULL(NetTurnover, 0)
		,ISNULL(NetTurnoverForMargin, 0)
		,ISNULL(TurnoverNoDraw, 0)
		,ISNULL(BasedTurnover, 0)
		,ISNULL(BasedNetTurnover, 0)
		,ISNULL(BasedNetTurnoverForMargin, 0)
		,ISNULL(BasedTurnoverNoDraw, 0)
		,ISNULL(GGR, 0)
		,ISNULL(BasedGGR, 0)
		,ISNULL(GGRForMargin, 0)
		,ISNULL(BasedGGRForMargin, 0)
		,ISNULL(PlayerWinloss, 0)
		,ISNULL(BasedPlayerWinloss, 0)
		,ISNULL(ProgressiveWin, 0)
		,ISNULL(ProgressiveBet, 0)
		,ISNULL(BasedProgressiveWin, 0)
		,ISNULL(BasedProgressiveBet, 0)
		,ISNULL(BetCount, 0)
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,ISNULL(NumberOfDeposit, 0)		
		,ISNULL(DepositAmount, 0)
		,ISNULL(BasedDepositAmount, 0)
		,ISNULL(NumberOfWithdrawal, 0)		
		,ISNULL(WithdrawalAmount, 0)	
		,ISNULL(BasedWithdrawalAmount, 0)
		,ISNULL(BonusAmount, 0)
		,ISNULL(BasedBonusAmount, 0)
		,ISNULL(ClosingBalance, 0)
		,ISNULL(BasedClosingBalance, 0)
	FROM #__tmpResult

	DROP TABLE #__tmpResult

	IF @SortbyId = 1
		UPDATE #__FinalResult
		SET RowNumber = GroupId
	ELSE
		WITH CTE_Result AS (
			SELECT GroupId
				,ROW_NUMBER() OVER( ORDER BY
					 CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN BasedTurnover END ASC
					,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN BasedTurnover END DESC
					,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN BasedNetTurnover END ASC
					,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN BasedNetTurnover END DESC
					,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN BasedGGR END ASC
					,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN BasedGGR END DESC
					,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN BasedPlayerWinloss END ASC
					,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN BasedPlayerWinloss END DESC
					,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN BasedProgressiveWin END ASC
					,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN BasedProgressiveWin END DESC
					,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN BasedProgressiveBet END ASC
					,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN BasedProgressiveBet END DESC
					,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN BetCount END ASC
					,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN BetCount END DESC
					,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 1 THEN BasedAvgBetAmount END ASC
					,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 0 THEN BasedAvgBetAmount END DESC
					,CASE WHEN @SortbyId = 10 AND @IsSortAsc = 1 THEN UniquePlayers END ASC
					,CASE WHEN @SortbyId = 10 AND @IsSortAsc = 0 THEN UniquePlayers END DESC
					,CASE WHEN @SortbyId = 11 AND @IsSortAsc = 1 THEN Margin END ASC
					,CASE WHEN @SortbyId = 11 AND @IsSortAsc = 0 THEN Margin END DESC
					,CASE WHEN @SortbyId = 12 AND @IsSortAsc = 1 THEN BasedClosingBalance END ASC
					,CASE WHEN @SortbyId = 12 AND @IsSortAsc = 0 THEN BasedClosingBalance END DESC
					,CASE WHEN @SortbyId = 13 AND @IsSortAsc = 1 THEN NumberOfDeposit END ASC
					,CASE WHEN @SortbyId = 13 AND @IsSortAsc = 0 THEN NumberOfDeposit END DESC
					,CASE WHEN @SortbyId = 14 AND @IsSortAsc = 1 THEN BasedDepositAmount END ASC
					,CASE WHEN @SortbyId = 14 AND @IsSortAsc = 0 THEN BasedDepositAmount END DESC
					,CASE WHEN @SortbyId = 15 AND @IsSortAsc = 1 THEN NumberOfWithdrawal END ASC
					,CASE WHEN @SortbyId = 15 AND @IsSortAsc = 0 THEN NumberOfWithdrawal END DESC
					,CASE WHEN @SortbyId = 16 AND @IsSortAsc = 1 THEN BasedWithdrawalAmount END ASC
					,CASE WHEN @SortbyId = 16 AND @IsSortAsc = 0 THEN BasedWithdrawalAmount END DESC
					,CASE WHEN @SortbyId = 17 AND @IsSortAsc = 1 THEN BasedBonusAmount END ASC
					,CASE WHEN @SortbyId = 17 AND @IsSortAsc = 0 THEN BasedBonusAmount END DESC) AS RowNumber
			FROM (
				SELECT GroupId
					,SUM(BasedTurnover) AS BasedTurnover
					,SUM(BasedNetTurnover) AS BasedNetTurnover
					,SUM(-BasedGGR) AS BasedGGR
					,SUM(BasedPlayerWinloss) AS BasedPlayerWinloss
					,SUM(BasedProgressiveWin) AS BasedProgressiveWin
					,SUM(BasedProgressiveBet) AS BasedProgressiveBet
					,SUM(BetCount) AS BetCount
					,ISNULL(SUM(BasedNetTurnover)/NULLIF(SUM(BetCount), 0), 0) AS BasedAvgBetAmount
					,SUM(UniquePlayers) AS UniquePlayers
					,ISNULL(SUM(BasedGGRForMargin)/NULLIF(SUM(BasedNetTurnoverForMargin), 0), 0) AS Margin
					,SUM(NumberOfDeposit) AS NumberOfDeposit
					,SUM(BasedDepositAmount) AS BasedDepositAmount
					,SUM(NumberOfWithdrawal) AS NumberOfWithdrawal
					,SUM(BasedWithdrawalAmount) AS BasedWithdrawalAmount
					,SUM(BasedBonusAmount) AS BasedBonusAmount
					,SUM(BasedClosingBalance) AS BasedClosingBalance
				FROM #__FinalResult
				GROUP BY GroupId
			) t
		)
		UPDATE f
		SET f.RowNumber = r.RowNumber
		FROM #__FinalResult f
			INNER JOIN CTE_Result r ON f.GroupId = r.GroupId

	--return data
	SELECT @TotalRows = MAX(GroupId), @TotalBasedClosingBalance = SUM(BasedClosingBalance) FROM #__FinalResult

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
		,BasedNetTurnoverForMargin
		,BasedTurnoverNoDraw
		,GGR
		,BasedGGR
		,BasedGGRForMargin
		,PlayerWinloss
		,BasedPlayerWinloss
		,ProgressiveWin
		,ProgressiveBet
		,BasedProgressiveWin
		,BasedProgressiveBet
		,BetCount
		,AvgBetAmount
		,BasedAvgBetAmount
		,UniquePlayers
		,NumberOfDeposit
		,DepositAmount
		,BasedDepositAmount
		,NumberOfWithdrawal		
		,WithdrawalAmount	
		,BasedWithdrawalAmount
		,BonusAmount
		,BasedBonusAmount
		,ClosingBalance
		,BasedClosingBalance
	FROM #__FinalResult
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 
	ORDER BY RowNumber, CurrencyId

	-- total
	SELECT
		CAST(SUM(BasedTurnover) AS MONEY) AS TotalBasedTurnover
		,CAST(SUM(BasedNetTurnover) AS MONEY) AS TotalBasedNetTurnover
		,CAST(SUM(BasedNetTurnOverForMargin) AS MONEY) AS TotalBasedNetTurnoverForMargin
		,CAST(SUM(BasedTurnoverNoDraw) AS MONEY) AS TotalBasedTurnoverNoDraw
		,CAST(SUM(BasedRevenue) AS MONEY) AS TotalBasedGGR
		,CAST(SUM(BasedRevenueForMargin) AS MONEY) AS TotalBasedGGRForMargin
		,CAST(SUM(BasedWinloss) AS MONEY) AS TotalBasedPlayerWinloss
		,CAST(SUM(BasedProgressiveWin) AS MONEY) AS TotalBasedProgressiveWin
		,CAST(SUM(BasedProgressiveBet) AS MONEY) AS TotalBasedProgressiveBet
		,SUM(BetCount) AS TotalBetCount
		,CAST(ISNULL(SUM(BasedNetTurnover)/NULLIF(SUM(BetCount), 0), 0) AS MONEY) AS TotalBasedAvgBetAmount
		,COUNT(DISTINCT (CASE WHEN IsExtraUser = 0 THEN s.CustId ELSE NULL END)) AS TotalUniquePlayers
		,ISNULL(SUM(NumberOfDeposit), 0) AS TotalNumberOfDeposit
		,ISNULL(CAST(SUM(BasedDepositAmount) AS MONEY), 0) AS TotalBasedDepositAmount
		,ISNULL(SUM(NumberOfWithdrawal), 0) AS TotalNumberOfWithdrawal
		,ISNULL(CAST(SUM(BasedWithdrawalAmount) AS MONEY), 0) AS TotalBasedWithdrawalAmount
		,ISNULL(CAST(SUM(BasedBonusAmount) AS MONEY), 0) AS TotalBasedBonusAmount
		,@TotalBasedClosingBalance AS TotalBasedClosingBalance
	FROM #__N88_SumWinloss s

	DROP TABLE #__FinalResult
	DROP TABLE #__N88_SumWinloss
	DROP TABLE #__ClosingBalance
END
GO