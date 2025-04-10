/*<info serverAlias="DBN88-bodb_N88" executers="wsv_lap" isFunction="0" isNested="0"></info>*/
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
	,@DataLimitBy				INT= 0
	,@IsDataLimitDesc			INT = 0
	,@DataLimitValue			INT = 0
	,@ReportSettingTypeId		INT = 0
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
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Integrate new bonus: Referral & Rebuild Bonus Structure [RedmineID: #171245]
		- 20220518@Percy: Add Commission for 9W Sports [RedmineID: #172917]
		- 20220608@Percy: Update GGR formula for 9W Sports & Add Group By Brand (Site) [RedmineID: #173396]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230406@Malcolm: Using Actual Deposit instead of Amount for Deposit Info [RedmineId: #186439]
		- 20230704@Sally: Exclude data of Live Streamer [RedmineId: #189299]
		- 20230710@Sally: Data Limits by top/bottom X player [RedmineId: #189299]
		- 20231011@Sally: Merging USD (72) currency into  USD (3) currency to a row
		- 20231023@Sally: Separate USD (3) and USDKH (72)
		- 20231201@Sally: Get only data players based on ticket data if having limits data [RedmineId: #197493]
		- 20240401@Sally: Support House Win Loss [RedmineID: #201107]
		- 20250408@Kelvin: Upgrade ExchangeId Datatype [RedmineID: #222339]

	Param's Explanation:
		@GroupBy:
			.  1 = Date
			.  2 = Month
			.  3 = Product
			.  4 = Currency
			.  5 = Player
			.  6 = Brand (Site)
		@SortbyId:
			.  1 = Group
			.  2 = Turnover
			.  3 = Valid Turnover
			.  4 = GGR
			.  5 = Player Win Loss
			.  6 = Progressive Win
			.  7 = Progressive Bet
			.  8 = Commission
			.  9 = BetCount
			. 10 = Avg Bet Amount
			. 11 = Unique Players
			. 12 = Margin
			. 13 = Closing Balance
			. 14 = No. Deposit
			. 15 = Total Deposit Amount
			. 16 = No. Withdrawal
			. 17 = Total Withdrawal Amount
			. 18 = Total Bonus Amount
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
		@ReportSettingTypeId: SettingTypeId
			. 0 = No filter by ReportSetting
			. 1 = DataView Full (Default)
			. 2 = DataView House
			. 3 = Dataview ShareHolder
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TotalBasedClosingBalance MONEY, @TpCurrencyIds VARCHAR(MAX)
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
		,TpCurrencyId				INT
		,SiteId						INT
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
		,Commission					MONEY
		,BasedTurnOver				MONEY
		,BasedNetTurnOver			MONEY
		,BasedNetTurnOverForMargin	MONEY
		,BasedTurnoverNoDraw		MONEY
		,BasedRevenue				MONEY
		,BasedRevenueForMargin		MONEY
		,BasedWinloss				MONEY
		,BasedProgressiveWin		MONEY
		,BasedProgressiveBet		MONEY
		,BasedCommission			MONEY
		,NumberOfDeposit			INT
		,DepositAmount				MONEY
		,BasedDepositAmount			MONEY
		,NumberOfWithdrawal			INT
		,WithdrawalAmount			MONEY
		,BasedWithdrawalAmount		MONEY
		,BonusAmount				MONEY
		,BasedBonusAmount			MONEY			
		,BasedTurnOverSort			MONEY 
		,BasedRevenueSort			MONEY 
		,BasedNetTurnOverSort		MONEY 
		,IsExtraUser				BIT DEFAULT (0) -- for count player who has placed bet
		,IsTicketData				BIT DEFAULT (1) -- default for ticket data
	)
	CREATE CLUSTERED INDEX CIX_N88_SumWinloss ON #__N88_SumWinloss (CustId)

	CREATE TABLE #__TpExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT, MultipleBy FLOAT)
	CREATE CLUSTERED INDEX CIX_Exchange ON #__TpExchange (TpExchangeId, FromDate)

	--closing balance temp table
	CREATE TABLE #__ClosingBalance (CustId INT, ClosingBalance MONEY, BasedClosingBalance MONEY)

	-- Report setting
	CREATE TABLE #__ReportSetting(
		[SiteId] INT NOT NULL,
		[CurrencyId] INT NULL,
		[PercentageValue] DECIMAL(9,8) NOT NULL,
		[FromDate] DATETIME NOT NULL,
		[ToDate] DATETIME NOT NULL
	) 
	CREATE CLUSTERED INDEX [CIX_ReportSetting_ReportSettingType] ON #__ReportSetting
	(
		[SiteId] ASC,
		[CurrencyId] ASC,
		[FromDate] ASC
	)

	DECLARE @MinDate DATE, @MaxDate DATE, @TicketStatus VARCHAR(50) = '1,2' -- win, loss
		,@ListCustFilter VARCHAR(MAX) = NULL
		,@IsFilterCustId BIT = CASE WHEN ISNULL(@UserName, '') <> '' THEN 1 ELSE 0 END

	SELECT @TicketStatus = @TicketStatus + CASE WHEN @IsNoDrawTicket = 0 THEN ',4' ELSE '' END -- draw ticket
	SELECT @TicketStatus = @TicketStatus + CASE WHEN @IsIncludedFreeSpin = 1 THEN ',6' ELSE '' END -- free spin ticket
	
	SELECT @TpCurrencyIds = 
	(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(tp.TpExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = t.value
	)

	-- Get CustFilter Info
	IF (@IsFilterCustId = 1)
	BEGIN
		SELECT @ListCustFilter = STRING_AGG(CONVERT(VARCHAR(50), c.CustId), ',')  
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.MemberType <> 3 -- Exlude data of Live Streamer
			AND (c.IsTest = 0 OR @IsIncludedTestData = 1)
			AND (@UserName = CASE WHEN @UserNameFilterId = 1 THEN c.UserName
									WHEN @UserNameFilterId = 2 THEN c.TpUserName
									WHEN @UserNameFilterId = 3 THEN c.TpSystemUserName
							END
			)			
	END

	-- Get Report Setting filter
	IF(@ReportSettingTypeId <> 0)
	BEGIN
		;WITH CTE_ReportSetting AS (
			SELECT CONVERT(DATE, DATEADD(HOUR, -4, FromDate)) AS FromDate
				,CONVERT(DATE, DATEADD(HOUR, -4, ToDate)) AS ToDate
				,SiteId
				,CurrencyType
				,CurrencyId
				,PercentageValue
			FROM dbo.N88_f_GetReportSetting(@ReportSettingTypeId, @SiteIds) nfgrs
			WHERE (@FromDateTimeGMT0 BETWEEN FromDate AND ToDate)
				OR (@ToDateTimeGMT0  BETWEEN FromDate AND ToDate)
		),
		CTE_ReportSetting_ID AS(
		SELECT FromDate
			,ToDate
			,SiteId
			,CurrencyId
			,PercentageValue
		FROM CTE_ReportSetting
		WHERE CurrencyType = 'ID'
		)
		INSERT INTO #__ReportSetting (FromDate, ToDate, CurrencyId, PercentageValue, SiteId)
			SELECT  FromDate
				,ToDate
				,CurrencyId
				,Percentagevalue
				,SiteId
			FROM CTE_ReportSetting_ID
			UNION ALL
			SELECT t.FromDate
				,t.ToDate
				,h.CurrencyId
				,t.Percentagevalue
				,t.SiteId
			FROM CTE_ReportSetting t
				CROSS JOIN(
						SELECT CONVERT(INT, t.value) AS CurrencyId
						FROM  STRING_SPLIT(@TpCurrencyIds, ',') t  
					)h
				LEFT JOIN CTE_ReportSetting_ID a ON a.CurrencyId = h.CurrencyId AND t.SiteId = a.SiteId
												AND a.FromDate = t.FromDate AND a.ToDate = t.ToDate
			WHERE CurrencyType = 'OTHER'
				AND a.CurrencyId IS NULL
	END
	---- by winlostdate
	IF (@FilterBy = 1)
	BEGIN
		INSERT INTO #__TpExchange (FromDate, ToDate, TpExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), Rate, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_SumWinloss
		(
			rptDate, GameType, CustId, TpCurrencyId, SiteId
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, TurnoverNoDraw, Revenue, RevenueForMargin, Winloss, ProgressiveWin, ProgressiveBet
			,BasedTurnOver, BasedNetTurnOver, BasedNetTurnOverForMargin, BasedTurnoverNoDraw, BasedRevenue, BasedRevenueForMargin, BasedWinloss, BasedProgressiveWin, BasedProgressiveBet
			,BasedTurnOverSort, BasedRevenueSort, BasedNetTurnOverSort	
		)
		SELECT rptDate, GameType, CustId, r.TpCurrencyId, r.SiteId
			,SUM(BetCount)
			,SUM(TurnOver * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOver * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOverForMargin * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOverNoDraw * ISNULL(rs.PercentageValue, 1))
			,SUM(Revenue * ISNULL(rs.PercentageValue, 1))
			,SUM(RevenueForMargin * ISNULL(rs.PercentageValue, 1))
			,SUM(Winloss * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveWin * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveBet * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOver * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOver * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOverForMargin * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOverNoDraw * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(Revenue * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(RevenueForMargin * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(Winloss * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveWin * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveBet * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOver * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(NetTurnOver * e.Rate)	
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,r.CustId
				,r.Currency AS TpCurrencyId
				,r.SiteId
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
				AND (',' + @ListCustFilter + ',' LIKE '%,' + CONVERT(VARCHAR(50), r.CustId) + ',%' OR @IsFilterCustId = 0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.SiteId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND ',' + @TicketStatus + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.StatusId) + ',%'
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime))
				,r.CustId
				,r.Currency
				,r.SiteId
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,CASE WHEN @GroupBy = 3 THEN r.GameType END
		) r
			INNER JOIN #__TpExchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.TpCurrencyId = e.TpExchangeId
			LEFT JOIN #__ReportSetting rs ON r.ExchangeDate BETWEEN rs.FromDate AND rs.ToDate 
										AND r.TpCurrencyId = rs.CurrencyId 
										AND r.SiteId = rs.SiteId
		WHERE rs.CurrencyId IS NOT NULL OR @ReportSettingTypeId = 0
		GROUP BY rptDate, GameType, CustId, r.TpCurrencyId, r.SiteId

		-- Get commission for 9W (filter by winlostdate only)
		IF ',' + @ProductIds + ',' LIKE '%,51,%'
		BEGIN
			DECLARE @FromDateTimeGMT8 DATETIME, @ToDateTimeGMT8 DATETIME -- data on GMT+8
			SELECT  @FromDateTimeGMT8		= DATEADD(HOUR, 8 - @TimeZone, CONVERT(DATETIME, @FromDate))
					,@ToDateTimeGMT8		= DATEADD(HOUR, 8 - @TimeZone, CONVERT(DATETIME, @ToDate))
			
			CREATE TABLE #__9W (CustId INT, rptDate DATE, Commission MONEY, BasedCommission MONEY)
			INSERT INTO #__9W (CustId, rptDate, Commission, BasedCommission)
			SELECT t.CustId, t.rptDate, SUM(t.Commission * ISNULL(rs.PercentageValue, 1) / e.MultipleBy), SUM(t.Commission * e.Rate * ISNULL(rs.PercentageValue, 1) / e.MultipleBy)
			FROM (
				SELECT SiteId, CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -12, settledDate)) AS ExchangeDate, CONVERT(DATE, DATEADD(HOUR, @TimeZone - 8, settledDate)) AS rptDate, SUM(Commission) AS Commission
				FROM dbo.TpReport9W WITH (NOLOCK)
				WHERE settledDate >= @FromDateTimeGMT8 AND settledDate < DATEADD(DAY, 1, @ToDateTimeGMT8)
					AND (',' + @ListCustFilter + ',' LIKE '%,' + CONVERT(VARCHAR(50), CustId) + ',%'  OR @IsFilterCustId = 0)
				GROUP BY SiteId,CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -12, settledDate)), CONVERT(DATE, DATEADD(HOUR, @TimeZone - 8, settledDate))
			) t
				INNER JOIN #__TpExchange e ON t.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND t.CurrencyId = e.TpExchangeId
				LEFT JOIN #__ReportSetting rs ON t.ExchangeDate BETWEEN rs.FromDate AND rs.ToDate 
											AND t.CurrencyId = rs.CurrencyId
											AND t.SiteId = rs.SiteId
			WHERE rs.CurrencyId IS NOT NULL OR @ReportSettingTypeId = 0
			GROUP BY t.CustId, t.rptDate

			UPDATE t
			SET t.Commission = -w.Commission, t.BasedCommission = -w.BasedCommission
				,t.Revenue = t.Revenue - w.Commission, t.BasedRevenue = t.BasedRevenue - w.BasedCommission
				,t.RevenueForMargin = t.RevenueForMargin - w.Commission, t.BasedRevenueForMargin = t.BasedRevenueForMargin - w.BasedCommission
			FROM #__N88_SumWinloss t
				INNER JOIN #__9W w ON t.CustId = w.CustId AND t.rptDate = w.rptDate
			WHERE @GroupBy <> 3 OR t.GameType = 51 -- @GroupBy = 3 not group by GameType (GameType is null)

			DROP TABLE #__9W
		END
	END
	---- by transdate
	ELSE 
	BEGIN
		SELECT @MinDate = MIN(CONVERT(DATE, SettledTime)), @MaxDate = MAX(CONVERT(DATE, SettledTime))
		FROM dbo.N88_SumWinloss WITH (NOLOCK) WHERE TransTime >= @FromDateTimeGMT0 AND TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)

		SELECT @MinDate = DATEADD(DAY, -1, @MinDate), @MaxDate = DATEADD(DAY, 1, @MaxDate)

		INSERT INTO #__TpExchange (FromDate, ToDate, TpExchangeId, Rate, MultipleBy)
		SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), Rate, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@MinDate, @MaxDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		INSERT INTO #__N88_SumWinloss
		(
			rptDate, GameType, CustId, TpCurrencyId, SiteId
			,BetCount, TurnOver, NetTurnOver, NetTurnOverForMargin, TurnoverNoDraw, Revenue, RevenueForMargin, Winloss, ProgressiveWin, ProgressiveBet
			,BasedTurnOver, BasedNetTurnOver, BasedNetTurnOverForMargin, BasedTurnoverNoDraw, BasedRevenue, BasedRevenueForMargin, BasedWinloss, BasedProgressiveWin, BasedProgressiveBet
			,BasedTurnOverSort, BasedRevenueSort, BasedNetTurnOverSort
		)
		SELECT rptDate, GameType, CustId, r.TpCurrencyId, r.SiteId
			,SUM(BetCount)
			,SUM(TurnOver * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOver * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOverForMargin * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOverNoDraw * ISNULL(rs.PercentageValue, 1))
			,SUM(Revenue * ISNULL(rs.PercentageValue, 1))
			,SUM(RevenueForMargin * ISNULL(rs.PercentageValue, 1))
			,SUM(Winloss * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveWin * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveBet * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOver * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOver * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(NetTurnOverForMargin * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOverNoDraw * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(Revenue * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(RevenueForMargin * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(Winloss * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveWin * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(ProgressiveBet * e.Rate * ISNULL(rs.PercentageValue, 1))
			,SUM(TurnOver * e.Rate)
			,SUM(Revenue * e.Rate)
			,SUM(NetTurnOver * e.Rate)	
		FROM (
			SELECT
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime)) AS ExchangeDate
				,r.CustId
				,r.Currency AS TpCurrencyId
				,r.SiteId
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
				AND (',' + @ListCustFilter + ',' LIKE '%,' + CONVERT(VARCHAR(50), r.CustId) + ',%'  OR @IsFilterCustId = 0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.SiteId) + ',%'
				AND ',' + @ProductIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.GameType) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				AND ',' + @TicketStatus + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.StatusId) + ',%'
			GROUP BY
				CONVERT(DATE, DATEADD(HOUR, -4, r.SettledTime))
				,r.CustId
				,r.Currency
				,r.SiteId
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, CASE @FilterBy WHEN 1 THEN r.SettledTime WHEN 2 THEN r.TransTime END))
				,CASE WHEN @GroupBy = 3 THEN r.GameType END
		) r
			INNER JOIN #__TpExchange e ON r.ExchangeDate BETWEEN e.FromDate AND e.ToDate AND r.TpCurrencyId = e.TpExchangeId
			LEFT JOIN #__ReportSetting rs ON r.ExchangeDate BETWEEN rs.FromDate AND rs.ToDate 
											AND r.TpCurrencyId = rs.CurrencyId
											AND r.SiteId = rs.SiteId
		WHERE rs.CurrencyId IS NOT NULL OR @ReportSettingTypeId = 0
		GROUP BY rptDate, GameType, CustId, r.TpCurrencyId, r.SiteId
	END

	-- Reset Exchange
	DELETE #__TpExchange
	INSERT INTO #__TpExchange (FromDate, ToDate, TpExchangeId, Rate, MultipleBy)
	SELECT FromDate, ToDate, ISNULL(tp.TpExchangeID, e.ExchangeId), CASE WHEN @IsDetailInOriginalCurr = 0 THEN Rate ELSE 1 END, CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
	FROM bodb02.dbo.Lrf_f_GetExchangeRate(@FDate, @TDate, @DisplayCurrency, '') e
		LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
	WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'
	
	-- Deposit/Withdrawal/Bonus
	BEGIN 
		-- Deposit: DepositInfo
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, TpCurrencyId, SiteId, NumberOfDeposit, DepositAmount, BasedDepositAmount, IsExtraUser, IsTicketData)
		SELECT d.rptDate, d.CustId, d.CurrencyId, d.SiteId, SUM(d.BetCount), SUM(d.Amount * ISNULL(rs.PercentageValue, 1) / e.MultipleBy), SUM(d.Amount * ISNULL(rs.PercentageValue, 1) * e.Rate / e.MultipleBy), 1, 0
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId, SiteId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,COUNT(1) AS BetCount, SUM(ActualDeposit) AS Amount
			FROM dbo.DepositInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 3 -- Approved
				AND (',' + @ListCustFilter + ',' LIKE '%,' + CONVERT(VARCHAR(50), CustId) + ',%'  OR @IsFilterCustId = 0)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId, SiteId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) d
			INNER JOIN #__TpExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN #__ReportSetting rs ON d.ExchangeDate BETWEEN rs.FromDate AND rs.ToDate 
											AND d.CurrencyId = rs.CurrencyId
											AND d.SiteId = rs.SiteId
		WHERE rs.CurrencyId IS NOT NULL OR @ReportSettingTypeId = 0
		GROUP BY d.rptDate, d.CustId, d.CurrencyId, d.SiteId
		
		-- Withdrawal: WithdrawalInfo
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, TpCurrencyId, SiteId, NumberOfWithdrawal, WithdrawalAmount, BasedWithdrawalAmount, IsExtraUser, IsTicketData)
		SELECT w.rptDate, w.CustId, w.CurrencyId, w.SiteId, SUM(w.BetCount), SUM(w.Amount * ISNULL(rs.PercentageValue, 1) / e.MultipleBy), SUM(w.Amount * ISNULL(rs.PercentageValue, 1) * e.Rate / e.MultipleBy), 1, 0
		FROM (
			SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)) AS rptDate, CustId, CurrencyId, SiteId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)) AS ExchangeDate
				,COUNT(1) AS BetCount, SUM(Amount) AS Amount
			FROM dbo.WithdrawalInfo WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @FDate AND @TDate
				AND CreateTime >= @FromDateTimeGMT0 AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), SiteId) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND Status = 6 -- Approved
				AND (',' + @ListCustFilter + ',' LIKE '%,' + CONVERT(VARCHAR(50), CustId) + ',%'  OR @IsFilterCustId = 0)
			GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), CustId, CurrencyId, SiteId
				,CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		) w
			INNER JOIN #__TpExchange e ON w.CurrencyId = e.TpExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN #__ReportSetting rs ON w.ExchangeDate BETWEEN rs.FromDate AND rs.ToDate 
											AND w.CurrencyId = rs.CurrencyId
											AND w.SiteId = rs.SiteId
		WHERE rs.CurrencyId IS NOT NULL OR @ReportSettingTypeId = 0
		GROUP BY w.rptDate, w.CustId, w.CurrencyId, w.SiteId

		-- Bonus: CustBonusSummary
		INSERT INTO #__N88_SumWinloss (rptDate, CustId, TpCurrencyId, SiteId, BonusAmount, BasedBonusAmount, IsExtraUser, IsTicketData)
		SELECT b.rptDate, b.CustId, b.CurrencyId, b.SiteId, SUM(b.Amount * ISNULL(rs.PercentageValue, 1)), SUM(b.Amount  * ISNULL(rs.PercentageValue, 1) * e.Rate), 1, 0
		FROM (
			SELECT b.DataSource, b.BonusType
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.BonusTime)) AS rptDate
				,b.CustId, b.CurrencyId, b.SiteId
				,CONVERT(DATE, DATEADD(HOUR, -4, b.BonusTime)) AS ExchangeDate
				,SUM(b.BonusAmount * CASE
									WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusType IN (1, 3) THEN 1 -- Credit, Increase bonus
									WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusType IN (2, 4) THEN -1 -- Debit, Decrease bonus
									WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusType = 1 THEN 1 -- 3rd Add
									WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusType = 2 THEN -1 -- 3rd Minus
									ELSE 1 END) AS Amount
			FROM dbo.CustBonusSummary b WITH (NOLOCK)
			WHERE b.BonusTime >= @FromDateTimeGMT0 AND b.BonusTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
				AND ',' + @SiteIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.SiteId) + ',%'
				AND ',' + @TpCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.CurrencyId) + ',%'
				AND (',' + @ListCustFilter + ',' LIKE '%,' + CONVERT(VARCHAR(50), CustId) + ',%'  OR @IsFilterCustId = 0)
				AND 1 = CASE
						WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusStatus <> 2 THEN 0 -- 2 = Approved
						WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusStatus <> 0 THEN 0 -- 0 = Success
						WHEN b.DataSource = 'VipUpgradeReview' AND b.BonusStatus <> 4 THEN 0 -- 4 = Settled
						ELSE 1 END
				AND 1 = CASE WHEN b.DataSource = 'AdjustmentInfo' AND b.BonusTime >= '2021-10-31 16:00' AND b.BonusType IN (1, 2) THEN 0 ELSE 1 END -- From 1 Nov 2021 (GMT+8), don't get Credit & Debit
				AND 1 = CASE WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.BonusTime >= '2021-10-31 16:00' THEN 0 ELSE 1 END -- only get LogAdminAdjustWallet data before 1 Nov 2021 (GMT+8)
			GROUP BY b.DataSource, b.BonusType
				,CONVERT(DATE, DATEADD(HOUR, @TimeZone, b.BonusTime))
				,b.CustId, b.CurrencyId, b.SiteId
				,CONVERT(DATE, DATEADD(HOUR, -4, b.BonusTime))
		) b
			INNER JOIN #__TpExchange e ON b.CurrencyId = e.TpExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate
			LEFT JOIN dbo.N88_f_BonusType() bt ON b.DataSource = bt.DataSource AND ISNULL(b.BonusType, 0) = bt.DBTypeId
			LEFT JOIN #__ReportSetting rs ON b.ExchangeDate BETWEEN rs.FromDate AND rs.ToDate 
										AND b.CurrencyId = rs.CurrencyId 
										AND b.SiteId = rs.SiteId
		WHERE (b.DataSource IN ('BonusInfo', 'RebateMLog', 'DrawLog') OR bt.DataSource IS NOT NULL)
			AND (rs.CurrencyId IS NOT NULL OR @ReportSettingTypeId = 0)
		GROUP BY b.rptDate, b.CustId, b.CurrencyId, b.SiteId
	END

	--- Exlude data of Live Streamer and filter IsIncludeTestData
	BEGIN
		DELETE s
		FROM #__N88_SumWinloss s
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON s.CustId = c.CustId 
		WHERE c.MemberType = 3 --- Exlude data of Live Streamer
			OR (c.IsTest = 1 AND @IsIncludedTestData = 0)
	END
	
	--Get data limits player base on ticket data
	CREATE TABLE #_ListPlayer (CustId INT)
	IF (@DataLimitBy <> 0)
	BEGIN
		;WITH CTE_Cust AS (
			SELECT CustId
				,CASE @DataLimitBy WHEN 1 THEN SUM(BasedTurnOverSort)
									WHEN 2 THEN SUM(BasedRevenueSort)
									WHEN 3 THEN SUM(BetCount)
									WHEN 4 THEN ISNULL(SUM(BasedNetTurnOverSort)/SUM(NULLIF(BetCount,0)), 0)
				END AS GroupAmount
			FROM  #__N88_SumWinloss
			WHERE IsTicketData = 1 -- just get only ticket data
			GROUP BY CustId
		)
		INSERT INTO #_ListPlayer(CustId)
		SELECT TOP(@DataLimitValue) c.CustId	
		FROM CTE_Cust c
		ORDER BY
			CASE WHEN @IsDataLimitDesc =1 THEN GroupAmount END DESC
			,CASE WHEN @IsDataLimitDesc = 0 THEN GroupAmount END ASC
			,c.CustId 	

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

	----cal closing balance
	BEGIN
		;WITH rs AS (
			SELECT 
				CONVERT(DATETIME, MAX(cb.TIME)) AS mTime, 
				CONVERT(DATE, MAX(CONVERT(DATE, DATEADD(HOUR,-4, cb.TIME)))) AS exTime,
				cb.CustId, cb.SiteId, c.TpCurrencyId
			FROM dbo.CustClosingBalance cb
				INNER JOIN (SELECT DISTINCT CustId, TpCurrencyId  FROM #__N88_SumWinloss) c ON cb.CustId = c.CustId
			WHERE cb.Time >= @FromDateTimeGMT0 AND cb.Time < DATEADD(DAY, 1, @ToDateTimeGMT0)
			GROUP BY cb.CustId, cb.SiteId, c.TpCurrencyId
		)
		INSERT INTO #__ClosingBalance (CustId, ClosingBalance, BasedClosingBalance)
		SELECT cb.CustId, SUM(cb.Balance / e.MultipleBy), SUM(cb.Balance / e.MultipleBy * e.Rate)
		FROM dbo.CustClosingBalance cb
			INNER JOIN rs ON cb.Time = rs.mTime AND cb.CustId = rs.CustId AND cb.SiteId = rs.SiteId
			INNER JOIN #__TpExchange e ON rs.TpCurrencyId = e.TpExchangeId AND rs.exTime BETWEEN e.FromDate AND e.ToDate
		GROUP BY cb.CustId
	END

	-- 2. Calc temp result
	CREATE TABLE #__tmpResult 
	(
		[Group]						VARCHAR(500)
		,CustId						INT
		,SabaId						VARCHAR(50)
		,SabaSystemId				VARCHAR(50)
		,TpCurrencyId				INT
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
		,Commission					MONEY
		,BasedCommission			MONEY
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
			,TpCurrencyId
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
			,Commission
			,BasedCommission
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
			,TpCurrencyId
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
			,SUM(Commission)
			,SUM(BasedCommission)
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
			,TpCurrencyId
	END
	-- by product - gametype
	ELSE IF (@GroupBy = 3)
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,TpCurrencyId
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
			,Commission
			,BasedCommission
			,BetCount
			,AvgBetAmount
			,BasedAvgBetAmount
			,UniquePlayers
		)
		SELECT 
			g.TypeName
			,TpCurrencyId
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
			,SUM(Commission)
			,SUM(BasedCommission)
			,SUM(BetCount)
			,CAST(ISNULL(SUM(NetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS AvgBetAmount
			,CAST(ISNULL(SUM(BasedNetTurnOver)/NULLIF(SUM(BetCount),0),0) AS MONEY) AS BasedAvgBetAmount
			,COUNT(DISTINCT (CASE WHEN IsExtraUser = 0 THEN CustId ELSE NULL END)) AS UniquePlayers
		FROM #__N88_SumWinloss r
			INNER JOIN dbo.TpGameType g WITH (NOLOCK) ON r.GameType = g.Type
		GROUP BY
			g.TypeName
			,TpCurrencyId
	END
	-- by currency
	ELSE IF (@GroupBy = 4)
	BEGIN
		INSERT INTO #__tmpResult 
		(
			[Group]
			,TpCurrencyId
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
			,Commission
			,BasedCommission
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
			ISNULL(t.ExchangeId, r.TpCurrencyId) AS CurrencyId -- group by currency maindb
			,TpCurrencyId
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
			,SUM(Commission)
			,SUM(BasedCommission)
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
			LEFT JOIN dbo.TpExchange t WITH(NOLOCK) ON t.TpExchangeId = r.TpCurrencyId
		GROUP BY
			ISNULL(t.ExchangeId, r.TpCurrencyId)
			,r.TpCurrencyId
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
				,Commission = SUM(Commission)
				,BasedCommission = SUM(BasedCommission)
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
			,TpCurrencyId
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
			,Commission
			,BasedCommission
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
			,r.Commission
			,r.BasedCommission
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
	-- by brand (site)
	ELSE IF (@GroupBy = 6)
	BEGIN
		;WITH CTE_Result AS (
			SELECT SiteId, TpCurrencyId
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
				,Commission = SUM(Commission)
				,BasedCommission = SUM(BasedCommission)
				,BetCount = SUM(BetCount)
				,NumberOfDeposit = SUM(NumberOfDeposit)	
				,DepositAmount = SUM(DepositAmount)
				,BasedDepositAmount = SUM(BasedDepositAmount)
				,NumberOfWithdrawal = SUM(NumberOfWithdrawal)	
				,WithdrawalAmount = SUM(WithdrawalAmount)
				,BasedWithdrawalAmount = SUM(BasedWithdrawalAmount)
				,BonusAmount = SUM(BonusAmount)
				,BasedBonusAmount = SUM(BasedBonusAmount)
				,UniquePlayers = COUNT(DISTINCT (CASE WHEN IsExtraUser = 0 THEN CustId ELSE NULL END))
			FROM #__N88_SumWinloss
			GROUP BY SiteId, TpCurrencyId
		)
		INSERT INTO #__tmpResult
		(
			[Group]
			,TpCurrencyId
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
			,Commission
			,BasedCommission
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
			s.LicenseeName
			,r.TpCurrencyId
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
			,r.Commission
			,r.BasedCommission
			,r.BetCount
			,CASE WHEN ISNULL(r.BetCount, 0) = 0 THEN 0 ELSE r.NetTurnOver/r.BetCount END
			,CASE WHEN ISNULL(r.BetCount, 0) = 0 THEN 0 ELSE r.BasedNetTurnOver/r.BetCount END
			,r.UniquePlayers
			,r.NumberOfDeposit		
			,r.DepositAmount
			,r.BasedDepositAmount
			,r.NumberOfWithdrawal		
			,r.WithdrawalAmount	
			,r.BasedWithdrawalAmount
			,r.BonusAmount
			,r.BasedBonusAmount
		FROM CTE_Result r
			INNER JOIN dbo.ServerInfo s WITH (NOLOCK) ON r.SiteId = s.SiteId
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
		,TpCurrencyId				INT
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
		,Commission					MONEY
		,BasedCommission			MONEY
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
		,TpCurrencyId
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
		,Commission
		,BasedCommission
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
		,ISNULL(t.ExchangeId, r.TpCurrencyId) AS CurrencyId
		,r.TpCurrencyId
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
		,ISNULL(Commission, 0)
		,ISNULL(BasedCommission, 0)
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
	FROM #__tmpResult r
		LEFT JOIN dbo.TpExchange t WITH(NOLOCK) ON t.TpExchangeId = r.TpCurrencyId

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
					,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN BasedCommission END ASC
					,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN BasedCommission END DESC
					,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 1 THEN BetCount END ASC
					,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 0 THEN BetCount END DESC
					,CASE WHEN @SortbyId = 10 AND @IsSortAsc = 1 THEN BasedAvgBetAmount END ASC
					,CASE WHEN @SortbyId = 10 AND @IsSortAsc = 0 THEN BasedAvgBetAmount END DESC
					,CASE WHEN @SortbyId = 11 AND @IsSortAsc = 1 THEN UniquePlayers END ASC
					,CASE WHEN @SortbyId = 11 AND @IsSortAsc = 0 THEN UniquePlayers END DESC
					,CASE WHEN @SortbyId = 12 AND @IsSortAsc = 1 THEN Margin END ASC
					,CASE WHEN @SortbyId = 12 AND @IsSortAsc = 0 THEN Margin END DESC
					,CASE WHEN @SortbyId = 13 AND @IsSortAsc = 1 THEN BasedClosingBalance END ASC
					,CASE WHEN @SortbyId = 13 AND @IsSortAsc = 0 THEN BasedClosingBalance END DESC
					,CASE WHEN @SortbyId = 14 AND @IsSortAsc = 1 THEN NumberOfDeposit END ASC
					,CASE WHEN @SortbyId = 14 AND @IsSortAsc = 0 THEN NumberOfDeposit END DESC
					,CASE WHEN @SortbyId = 15 AND @IsSortAsc = 1 THEN BasedDepositAmount END ASC
					,CASE WHEN @SortbyId = 15 AND @IsSortAsc = 0 THEN BasedDepositAmount END DESC
					,CASE WHEN @SortbyId = 16 AND @IsSortAsc = 1 THEN NumberOfWithdrawal END ASC
					,CASE WHEN @SortbyId = 16 AND @IsSortAsc = 0 THEN NumberOfWithdrawal END DESC
					,CASE WHEN @SortbyId = 17 AND @IsSortAsc = 1 THEN BasedWithdrawalAmount END ASC
					,CASE WHEN @SortbyId = 17 AND @IsSortAsc = 0 THEN BasedWithdrawalAmount END DESC
					,CASE WHEN @SortbyId = 18 AND @IsSortAsc = 1 THEN BasedBonusAmount END ASC
					,CASE WHEN @SortbyId = 18 AND @IsSortAsc = 0 THEN BasedBonusAmount END DESC) AS RowNumber
			FROM (
				SELECT GroupId
					,SUM(BasedTurnover) AS BasedTurnover
					,SUM(BasedNetTurnover) AS BasedNetTurnover
					,SUM(-BasedGGR) AS BasedGGR
					,SUM(BasedPlayerWinloss) AS BasedPlayerWinloss
					,SUM(BasedProgressiveWin) AS BasedProgressiveWin
					,SUM(BasedProgressiveBet) AS BasedProgressiveBet
					,SUM(BasedCommission) AS BasedCommission
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

	SELECT r.RowNumber,
		r.[Group]
		,r.CustId
		,r.SabaId
		,r.SabaSystemId
		,r.CurrencyId
		,r.TpCurrencyId
		,r.Turnover
		,r.NetTurnover
		,r.TurnoverNoDraw
		,r.BasedTurnover
		,r.BasedNetTurnover
		,r.BasedNetTurnoverForMargin
		,r.BasedTurnoverNoDraw
		,r.GGR
		,r.BasedGGR
		,r.BasedGGRForMargin
		,r.PlayerWinloss
		,r.BasedPlayerWinloss
		,r.ProgressiveWin
		,r.ProgressiveBet
		,r.BasedProgressiveWin
		,r.BasedProgressiveBet
		,r.Commission
		,r.BasedCommission
		,r.BetCount
		,r.AvgBetAmount
		,r.BasedAvgBetAmount
		,r.UniquePlayers
		,r.NumberOfDeposit
		,r.DepositAmount
		,r.BasedDepositAmount
		,r.NumberOfWithdrawal		
		,r.WithdrawalAmount	
		,r.BasedWithdrawalAmount
		,r.BonusAmount
		,r.BasedBonusAmount
		,r.ClosingBalance
		,r.BasedClosingBalance
	FROM #__FinalResult r
	WHERE @PageIndex < 0 OR @PageSize <= 0 OR (RowNumber BETWEEN @RowStart AND @RowEnd) 
	ORDER BY RowNumber, r.CurrencyId

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
		,CAST(SUM(BasedCommission) AS MONEY) AS TotalBasedCommission
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
	DROP TABLE #_ListPlayer		
	DROP TABLE #__TpExchange
	DROP TABLE #__ReportSetting
END
GO