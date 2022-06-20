/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].N88_Rpt_Winloss_BetList
(
	@FilterBy TINYINT,
	@FromDate DATE,
	@ToDate DATE,
	@ProductId INT,
	@CustId VARCHAR(45),
	@DisplayCurrency VARCHAR(3),
	@IsIncludedFreeSpin BIT,
	@IsNoDrawTicket BIT,
	@TimeZone SMALLINT = -4,
	@PageIndex INT = 1,
	@PageSize INT = 50,
	@SortbyId TINYINT = 2, --default for trans time
	@IsSortAsc BIT = 1,
	@TotalRows INT = 0 OUTPUT
)
AS

/*
	Created: 20210423@Sol
	DB: DBN88-bodb_N88
	Task: N88 report winloss
	
	Revisions:
		- 20210423@Sol: Initial sp - Detail betlist for non-sport - [Redmine:#139333]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - include free spin filter - [RedmineID: #155334]
		- 20210715@Percy: Exclude Jackpot, Contribition from Win Loss (GGR) [RedmineID: #158438]
		- 20220222@Percy: Get data from TpBetRecord_bk [RedmineID: #167823]
		- 20220518@Percy: Set GGR = 0 for 9W Sports [RedmineID: #172917]
		- 20220608@Percy: Update GGR formula for 9W Sports [RedmineID: #173396]

	Param's Explanation:
		@SortbyId:
			.  1 = Ref no (Trans ID)
			.  2 = Trans time
			.  3 = Stake
			.  4 = Player winloss
			.  5 = Progressive Win
			.  6 = Progressive Bet
			.  7 = GGR
			.  8 = Status

*/

BEGIN
	SET NOCOUNT ON
	
	-- Data on GMT+0 --> convert timezone
	DECLARE @FromDateTimeGMT0 DATETIME, @ToDateTimeGMT0 DATETIME
	SELECT  @FromDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
			,@ToDateTimeGMT0		= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, DATEADD(DAY, 1, @ToDate)))

	DECLARE @FDate DATETIME = @FromDateTimeGMT0, @TDate DATETIME = @ToDateTimeGMT0
	DECLARE @ArchiveDate DATETIME = dbo.N88_f_GetSystemSettings('ArchiveData_Date')
	
	-- Get raw data
	CREATE TABLE #__N88_BetList
	(
		RefNo VARCHAR(50)
		,GameType INT
		,TicketStatus VARCHAR(100)
		,ExchangeDate DATE
		,TransTime DATETIME
		,Stake MONEY
		,PlayerWinLoss MONEY
		,ProgressiveWin MONEY
		,ProgressiveBet MONEY
		,GGR MONEY
	)

	-- TpBetRecord
	IF @ToDateTimeGMT0 >= @ArchiveDate
	BEGIN
		SELECT @FDate = CASE WHEN @FromDateTimeGMT0 > @ArchiveDate THEN @FromDateTimeGMT0 ELSE @ArchiveDate END
			,@TDate = @ToDateTimeGMT0
		
		INSERT INTO #__N88_BetList
		(
			RefNo, GameType, TicketStatus, ExchangeDate, TransTime, Stake, PlayerWinLoss, ProgressiveWin, ProgressiveBet, GGR
		)
		SELECT
			r.TransId, r.GameType
			,CASE 
				WHEN r.TicketStatus = 1 THEN 'Won'
				WHEN r.TicketStatus = 2 THEN 'Loss'
				WHEN r.TicketStatus = 4 THEN 'Draw'
				WHEN r.TicketStatus = 6 THEN 'Free Bet Won'
				END AS TicketStatus
			,CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
			,DATEADD(HOUR, @TimeZone, r.TransTime ) AS TransTime
			,r.Stake
			,r.WinlostAmount AS PlayerWinLoss
			,ISNULL(r.ProgressiveWin, 0) AS ProgressiveWin
			,ISNULL(r.ProgressiveBet, 0) AS ProgressiveBet
			,CASE WHEN r.GameType IN (41, 42) THEN r.Revenue ELSE -(r.WinlostAmount - ISNULL(r.ProgressiveWin, 0) + ISNULL(r.ProgressiveBet, 0)) END AS GGR
		FROM dbo.TpBetRecord r WITH (NOLOCK)
		WHERE r.CustId = @CustId
			AND r.GameType = @ProductId
			AND 1 = CASE
						WHEN @IsNoDrawTicket = 0 AND @IsIncludedFreeSpin = 0 AND r.TicketStatus IN (1, 2, 4) THEN 1
						WHEN @IsNoDrawTicket = 0 AND @IsIncludedFreeSpin = 1 AND r.TicketStatus IN (1, 2, 4, 6) THEN 1
						WHEN @IsNoDrawTicket = 1 AND @IsIncludedFreeSpin = 0 AND r.TicketStatus IN (1, 2) THEN 1
						WHEN @IsNoDrawTicket = 1 AND @IsIncludedFreeSpin = 1 AND r.TicketStatus IN (1, 2, 6) THEN 1
						ELSE 0 END
			AND (
				(@FilterBy = 1 AND r.SettledTime >= @FDate AND r.SettledTime < @TDate)
				OR (@FilterBy = 2 AND r.TransTime >= @FDate AND r.TransTime < @TDate)
			)
	END

	-- TpBetRecord_bk
	IF @FromDateTimeGMT0 < @ArchiveDate
	BEGIN
		SELECT @FDate = @FromDateTimeGMT0
			,@TDate = CASE WHEN @ToDateTimeGMT0 < @ArchiveDate THEN @ToDateTimeGMT0 ELSE @ArchiveDate END

		INSERT INTO #__N88_BetList
		(
			RefNo, GameType, TicketStatus, ExchangeDate, TransTime, Stake, PlayerWinLoss, ProgressiveWin, ProgressiveBet, GGR
		)
		SELECT
			r.TransId, r.GameType
			,CASE 
				WHEN r.TicketStatus = 1 THEN 'Won'
				WHEN r.TicketStatus = 2 THEN 'Loss'
				WHEN r.TicketStatus = 4 THEN 'Draw'
				WHEN r.TicketStatus = 6 THEN 'Free Bet Won'
				END AS TicketStatus
			,CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
			,DATEADD(HOUR, @TimeZone, r.TransTime ) AS TransTime
			,r.Stake
			,r.WinlostAmount AS PlayerWinLoss
			,ISNULL(r.ProgressiveWin, 0) AS ProgressiveWin
			,ISNULL(r.ProgressiveBet, 0) AS ProgressiveBet
			,CASE WHEN r.GameType IN (41, 42) THEN r.Revenue ELSE -(r.WinlostAmount - ISNULL(r.ProgressiveWin, 0) + ISNULL(r.ProgressiveBet, 0)) END AS GGR
		FROM bodb_N88_Archive.dbo.TpBetRecord_bk r WITH (NOLOCK)
		WHERE r.CustId = @CustId
			AND r.GameType = @ProductId
			AND 1 = CASE
						WHEN @IsNoDrawTicket = 0 AND @IsIncludedFreeSpin = 0 AND r.TicketStatus IN (1, 2, 4) THEN 1
						WHEN @IsNoDrawTicket = 0 AND @IsIncludedFreeSpin = 1 AND r.TicketStatus IN (1, 2, 4, 6) THEN 1
						WHEN @IsNoDrawTicket = 1 AND @IsIncludedFreeSpin = 0 AND r.TicketStatus IN (1, 2) THEN 1
						WHEN @IsNoDrawTicket = 1 AND @IsIncludedFreeSpin = 1 AND r.TicketStatus IN (1, 2, 6) THEN 1
						ELSE 0 END
			AND (
				(@FilterBy = 1 AND r.SettledTime >= @FDate AND r.SettledTime < @TDate)
				OR (@FilterBy = 2 AND r.TransTime >= @FDate AND r.TransTime < @TDate)
			)
	END

	-- Get Exchange
	DECLARE @CurrencyId INT
	SELECT  @CurrencyId = c.CurrencyId
	FROM dbo.Customer c WITH (NOLOCK)
	WHERE c.CustId = CAST(@CustId AS INT)

	DECLARE @MinDate DATE, @MaxDate DATE
	SELECT  @MinDate = MIN(ExchangeDate), @MaxDate = MAX(ExchangeDate) FROM #__N88_BetList

	CREATE TABLE #__Exchange (FromDate DATE, ToDate DATE, Rate FLOAT, MultipleBy FLOAT, PRIMARY KEY (FromDate))
	
	INSERT INTO #__Exchange (FromDate, ToDate, Rate, MultipleBy)
	SELECT FromDate, ToDate, Rate, CASE WHEN ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
	WHERE e.ExchangeId = @CurrencyId

	-- Return data
	DECLARE @RowStart INT, @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @TotalRows = COUNT(1) FROM #__N88_BetList

	SELECT RowNumber, RefNo, TransTime, TicketStatus, Stake, BasedStake, PlayerWinLoss, BasedPlayerWinLoss, ProgressiveWin, BasedProgressiveWin, ProgressiveBet, BasedProgressiveBet, GGR, BasedGGR
	FROM (
		SELECT
			ROW_NUMBER() OVER
				(
					ORDER BY
						CASE WHEN @SortbyId = 0 AND @IsSortAsc = 1 THEN t.TransTime END ASC,
						CASE WHEN @SortbyId = 0 AND @IsSortAsc = 0 THEN t.TransTime END DESC,
						CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN t.RefNo END ASC,
						CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN t.RefNo END DESC,
						CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN t.TransTime END ASC,
						CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN t.TransTime END DESC,
						CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN t.Stake / e.MultipleBy END ASC,
						CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN t.Stake / e.MultipleBy END DESC,
						CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN t.PlayerWinLoss / e.MultipleBy END ASC,
						CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN t.PlayerWinLoss / e.MultipleBy END DESC,
						CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN t.ProgressiveWin / e.MultipleBy END ASC,
						CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN t.ProgressiveWin / e.MultipleBy END DESC,
						CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN t.ProgressiveBet / e.MultipleBy END ASC,
						CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN t.ProgressiveBet / e.MultipleBy END DESC,
						CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN t.GGR / e.MultipleBy END ASC,
						CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN t.GGR / e.MultipleBy END DESC,
						CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN t.TicketStatus END ASC,
						CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN t.TicketStatus END DESC
				) AS RowNumber
			,t.RefNo, t.TransTime, t.TicketStatus
			,CONVERT(MONEY, t.Stake / e.MultipleBy)						AS Stake
			,CONVERT(MONEY, t.Stake * e.Rate / e.MultipleBy)			AS BasedStake
			,CONVERT(MONEY, t.PlayerWinLoss / e.MultipleBy)				AS PlayerWinLoss
			,CONVERT(MONEY, t.PlayerWinLoss * e.Rate / e.MultipleBy)	AS BasedPlayerWinLoss
			,CONVERT(MONEY, t.ProgressiveWin / e.MultipleBy)			AS ProgressiveWin
			,CONVERT(MONEY, t.ProgressiveWin * e.Rate / e.MultipleBy)	AS BasedProgressiveWin
			,CONVERT(MONEY, t.ProgressiveBet / e.MultipleBy)			AS ProgressiveBet
			,CONVERT(MONEY, t.ProgressiveBet * e.Rate / e.MultipleBy)	AS BasedProgressiveBet
			,CONVERT(MONEY, t.GGR / e.MultipleBy)						AS GGR
			,CONVERT(MONEY, t.GGR * e.Rate / e.MultipleBy)				AS BasedGGR
		FROM #__N88_BetList t
			INNER JOIN #__Exchange e ON t.ExchangeDate BETWEEN e.FromDate AND e.ToDate
	) r
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR RowNumber BETWEEN @RowStart AND @RowEnd
	ORDER BY RowNumber

	-- Total
	SELECT
		CONVERT(MONEY, SUM(t.PlayerWinLoss / e.MultipleBy))				AS TotalPlayerWinLoss
		,CONVERT(MONEY, SUM(t.PlayerWinLoss * e.Rate / e.MultipleBy))	AS TotalBasedPlayerWinLoss
		,CONVERT(MONEY, SUM(t.ProgressiveWin / e.MultipleBy))			AS TotalProgressiveWin
		,CONVERT(MONEY, SUM(t.ProgressiveWin * e.Rate / e.MultipleBy))	AS TotalBasedProgressiveWin
		,CONVERT(MONEY, SUM(t.ProgressiveBet / e.MultipleBy))			AS TotalProgressiveBet
		,CONVERT(MONEY, SUM(t.ProgressiveBet * e.Rate / e.MultipleBy))	AS TotalBasedProgressiveBet
		,CONVERT(MONEY, SUM(t.GGR / e.MultipleBy))						AS TotalGGR
		,CONVERT(MONEY, SUM(t.GGR * e.Rate / e.MultipleBy))				AS TotalBasedGGR
	FROM #__N88_BetList t
		INNER JOIN #__Exchange e ON t.ExchangeDate BETWEEN e.FromDate AND e.ToDate

	DROP TABLE #__Exchange
	DROP TABLE #__N88_BetList
END
GO