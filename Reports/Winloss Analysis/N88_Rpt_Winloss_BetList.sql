/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/
ALTER PROCEDURE [dbo].N88_Rpt_Winloss_BetList
(
	@FilterBy TINYINT,
	@FromDate DATE,
	@ToDate DATE,
	@ProductId INT,
	@CustId INT,
	@DisplayCurrency VARCHAR(3),
	@IsNoDrawTicket BIT,
	@TimeZone SMALLINT = -4,
	@PageIndex INT = 1,
	@PageSize INT = 50,
	@TotalRows INT = 0 OUTPUT
)
AS

/*
	Created: 20210423@Sol
	DB: DBN88-bodb_N88
	Task: N88 report winloss
	
	Revisions:
		- 20210423@Sol: Initial sp - Detail betlist for non-sport - [Redmine:#139333]

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
	CREATE TABLE #__N88_BetList
	(
		RowNumber INT,
		RefNo VARCHAR(50),
		TransTime DATETIME,
		Stake MONEY,
		PlayerWinLoss MONEY,
		GGR MONEY,
		TicketStatus VARCHAR(100)
	)

	CREATE CLUSTERED INDEX CIX_N88_BetList ON #__N88_BetList (RowNumber)

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

		INSERT INTO #__N88_BetList
		(
			RowNumber, RefNo, TransTime, Stake, PlayerWinLoss, GGR, TicketStatus
		)
		SELECT 
			ROW_NUMBER() OVER(ORDER BY r.rptDate) AS RowNumber,
			r.TransId AS RefNo,
			r.rptDate AS TransTime,
			r.Stake,
			r.WinlostAmount AS PlayerWinLoss,
			r.Revenue AS GGR,
			CASE 
				WHEN r.TicketStatus = 1 THEN 'Won'
				WHEN r.TicketStatus = 2 THEN 'Loss'
				WHEN r.TicketStatus = 4 THEN 'Draw'
				WHEN r.TicketStatus = 6 THEN 'Free Bet Won'
			END AS TicketStatus
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				, DATEADD(HOUR, @TimeZone, r.TransTime ) AS rptDate
				, r.CurrencyId
				, r.TransId
				, r.Stake
				, r.WinlostAmount
				, r.Revenue
				, r.TicketStatus
			FROM dbo.TpBetRecord r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.SettledTime >= @FromDateTimeGMT0 AND r.SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND r.CustId = @CustId
				AND r.GameType = @ProductId
				AND 1 = 
						CASE 
							WHEN @IsNoDrawTicket = 1 AND r.TicketStatus IN (1,2,6) THEN 1
							WHEN @IsNoDrawTicket = 0 AND r.TicketStatus IN (1,2,4,6) THEN 1
							ELSE 0
						END
		) r
			INNER JOIN #__Exchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.CurrencyId = e.ExchangeId
	END
	---- by transdate
	ELSE 
	BEGIN
		SELECT @MinDate = MIN(CONVERT(DATE, SettledTime)), @MaxDate = MAX(CONVERT(DATE, SettledTime))
		FROM dbo.TpBetRecord WITH (NOLOCK) WHERE TransTime >= @FromDateTimeGMT0 AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)

		SELECT @MinDate = DATEADD(DAY, -1, @MinDate), @MaxDate = DATEADD(DAY, 1, @MaxDate)

		INSERT INTO #__Exchange (FromDate, ToDate, ExchangeId, Rate)
		SELECT FromDate, ToDate, ExchangeId, Rate
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
		WHERE e.ExchangeId = @CurrencyId

		INSERT INTO #__N88_BetList
		(
			RowNumber, RefNo, TransTime, Stake, PlayerWinLoss, GGR, TicketStatus
		)
		SELECT
			ROW_NUMBER() OVER(ORDER BY r.rptDate) AS RowNumber,
			r.TransId AS RefNo,
			r.rptDate AS TransTime,
			r.Stake,
			r.WinlostAmount AS PlayerWinLoss,
			r.Revenue AS GGR,
			CASE 
				WHEN r.TicketStatus = 1 THEN 'Won'
				WHEN r.TicketStatus = 2 THEN 'Loss'
				WHEN r.TicketStatus = 4 THEN 'Draw'
				WHEN r.TicketStatus = 6 THEN 'Free Bet Won'
			END AS TicketStatus
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				, DATEADD(HOUR, @TimeZone, r.TransTime ) AS rptDate
				, r.CurrencyId
				, r.TransId
				, r.Stake
				, r.WinlostAmount
				, r.Revenue
				, r.TicketStatus
			FROM dbo.TpBetRecord r WITH (NOLOCK)
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON r.CustId = c.CustId
			WHERE r.TransTime >= @FromDateTimeGMT0 AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND r.CustId = @CustId
				AND r.GameType = @ProductId
				AND 1 = 
						CASE 
							WHEN @IsNoDrawTicket = 1 AND r.TicketStatus IN (1,2,6) THEN 1
							WHEN @IsNoDrawTicket = 0 AND r.TicketStatus IN (1,2,4,6) THEN 1
							ELSE 0
						END
		) r
			INNER JOIN #__Exchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.CurrencyId = e.ExchangeId
	END

	DROP TABLE #__Exchange

	--return data
	DECLARE @RowStart INT , @RowEnd INT
	SELECT @PageIndex = @PageIndex - 1, @RowStart =  @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @TotalRows = MAX(RowNumber) FROM #__N88_BetList

	SELECT t.RowNumber, t.RefNo, t.TransTime, t.Stake, t.PlayerWinLoss, t.GGR, t.TicketStatus
	FROM #__N88_BetList t
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 

	DROP TABLE #__N88_BetList

END
GO