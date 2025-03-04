/*<info serverAlias="DBN88-bodb_N88" executers="wsv_lap" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_BonusInfo_Detail]
	@LicenseeId			INT
	,@BonusTypeId		SMALLINT = 0
	,@BonusInfo			XML 
	,@ClaimedStatusIds	VARCHAR(MAX) = ''
	,@FromDate			DATE
	,@ToDate			DATE
	,@CurrencyIds		VARCHAR(MAX)
	,@DisplayCurrency	VARCHAR(3)
	,@TimeZone			SMALLINT = 8
	,@SortbyId			TINYINT = 1
	,@IsSortAsc			BIT = 1
	,@PageIndex			INT = 1
	,@PageSize			INT = 50
	,@NRows				INT = 0 OUTPUT
AS

/*n
	Created: 20200105@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200105@Percy: Initialize SP [RedmineID: #146759]
		- 20210629@Sol: MPA - Apply Currency permission - [RedmineID: #157588]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
		- 20220214@Percy: Return TransactionType column [RedmineID: #164724]
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Integrate new bonus: Referral [RedmineID: #171245]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
		- 20230301@Malcolm: Add new type: ReferralLog [RedmineID: #183930]
		- 20230327@Malcolm: Add Group by Month [RedmineId: #185268]
		- 20230504@Evan: Fix show wrong currency BDT & USD [RedmineId: #187776]
		- 20230406@Malcolm: Using Actual Deposit instead of Amount for Deposit Info [RedmineId: #186439]
		- 20230704@Sally: Exclude data of Live Streamer [RedmineId: #189299]
		- 20231018@Sally: Missing data of currency USD (3) on details [RedmineId: #195591]
		- 20231020@Sally: Permission to hide sensitive information [RedmineId: #195057]
		- 20250228@Sally: Increase the length of BonusName [RedmineId: #218851]

	Param's Explanation:
		@SortbyId:
			. 1 = Username
			. 2 = SabaId
			. 3 = Currency
			. 4 = BonusCode
			. 5 = BonusType
			. 6 = BonusName
			. 7 = Claim Date
			. 8 = Bonus Amount Claimed
			. 9 = Transaction Type
			. 10 = Deposit Amount
			. 11 = Withdrawal Amount
			. 12 = Status
			. 13 = Percent Completion

		@BonusInfo = <root>
						<r bonuscode="" bonustypeid=""/>
					 </root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @DataSource VARCHAR(100), @TPCurrencyIds VARCHAR(MAX)

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
	DECLARE @tmpFromDate DATE, @tmpToDate DATE
	CREATE TABLE #TPExchange (FromDate DATE, ToDate DATE, TpExchangeId INT, Rate FLOAT, MulipleBy FLOAT)

	CREATE TABLE #BonusInfo (
		CustId INT, CurrencyId INT, BonusCode VARCHAR(50), BonusName VARCHAR(300),BonusTypeId SMALLINT, BonusTypeName VARCHAR(50) ,Status TINYINT, ExchangeDate DATE, ClaimedDate DATETIME, DataSource VARCHAR(128), 
		TransactionType INT, Amount MONEY, PercentagedCompletion FLOAT DEFAULT (1)
	)
	CREATE TABLE #DepositInfo (CustId INT, CurrencyId INT, ExchangeDate DATE, Amount MONEY)
	CREATE TABLE #WithdrawalInfo (CustId INT, CurrencyId INT, ExchangeDate DATE, Amount MONEY)
	CREATE TABLE #BonusInfoDetail (BonusCode VARCHAR(50), BonusTypeId SMALLINT, BonusTypeName VARCHAR(50), DataSource VARCHAR(100))

	BEGIN
		SELECT @TPCurrencyIds = 
		(
			SELECT STRING_AGG(CONVERT(VARCHAR(50), ISNULL(tp.TPExchangeId, t.Value)), ',')
			FROM STRING_SPLIT(@CurrencyIds, ',') t 
				LEFT JOIN dbo.TPExchange tp WITH(NOLOCK) ON tp.ExchangeId = t.value
		)

		--Get BonusInfo	
		INSERT INTO #BonusInfoDetail (BonusCode, BonusTypeId)
		SELECT DISTINCT
			ISNULL(t.c.value('@bonuscode', 'VARCHAR(50)'), '')AS BonusCode
			,t.c.value('@bonustypeid', 'SMALLINT')
		FROM @BonusInfo.nodes('root/r') t(c)

		UPDATE b
			SET b.BonusTypeName = f.BonusTypeName, b.DataSource = f.DataSource
		FROM #BonusInfoDetail b
			INNER JOIN dbo.N88_f_BonusType() f ON f.BonusTypeId = b.BonusTypeId

		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		SELECT @tmpFromDate = DATEADD(DAY, -1, @FromDate), @tmpToDate = DATEADD(DAY, 1, @ToDate)

		INSERT INTO #TPExchange (FromDate, ToDate, TpExchangeId, Rate)
		SELECT FromDate, ToDate, ISNULL(tp.TPExchangeID, e.ExchangeId), Rate / CASE WHEN e.ExchangeId IN (15, 51) THEN 1000.0 ELSE 1.0 END
		FROM bodb02.dbo.Lrf_f_GetExchangeRate(@tmpFromDate, @tmpToDate, @DisplayCurrency, '') e
			LEFT JOIN dbo.TPExchange tp WITH(NOLOCK) ON tp.ExchangeId = e.ExchangeId
		WHERE ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), e.ExchangeId) + ',%'

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		-- BonusInfo
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail b WHERE b.DataSource = 'BonusInfo')
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, Status, ExchangeDate, ClaimedDate, Amount, PercentagedCompletion)
			SELECT b.CustId, b.BonusCode, p.Description AS BonusName, bi.BonusTypeId, bi.BonusTypeName, b.CurrencyId, b.Status, DATEADD(HOUR, -4, b.CreateTime), DATEADD(HOUR, @TimeZone, b.CreateTime), b.BonusAmount
				,CASE
					WHEN cbr.Turnover > cbr.Rollover THEN 1.0
					WHEN cbr.Rollover = 0 THEN 0.0
					ELSE cbr.Turnover / cbr.Rollover 
				END AS PercentagedCompletion
			FROM dbo.BonusInfo b WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.BonusCode = b.BonusCode AND bi.DataSource = 'BonusInfo'
				LEFT JOIN dbo.CustBonusRollover cbr WITH (NOLOCK) ON b.BonusId = cbr.BonusId
				LEFT JOIN dbo.Promotion p WITH(NOLOCK) ON p.BonusCode = b.BonusCode
			WHERE b.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND b.CreateTime >= @FromDateTimeGMT AND b.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND b.SiteId = @SiteId
				AND ',' + @ClaimedStatusIds + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.Status) + ',%'
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), b.CurrencyId) + ',%'
				AND bi.BonusTypeId = CASE WHEN bi.BonusTypeId <> 0 THEN p.PromotionType ELSE bi.BonusTypeId END
		END

		-- RebateMLog
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail b WHERE b.DataSource = 'RebateMLog')
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, Amount)
			SELECT r.CustId, r.BonusCode, p.Description AS BonusName, bi.BonusTypeId, bi.BonusTypeName, r.CurrencyId, DATEADD(HOUR, -4, r.CreateTime), DATEADD(HOUR, @TimeZone, r.CreateTime), r.RedeemAmount
			FROM dbo.RebateMLog r WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.BonusCode = r.BonusCode AND bi.DataSource = 'RebateMLog'
				LEFT JOIN dbo.Promotion p WITH(NOLOCK) ON p.BonusCode = r.BonusCode
			WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND r.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.CurrencyId) + ',%'
		END

		-- DrawLog
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail b WHERE b.DataSource = 'DrawLog')
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, Amount)
			SELECT d.CustId, e.EventName AS BonusCode, e.EventName AS BonusName, bi.BonusTypeId, bi.BonusTypeName, d.CurrencyId, DATEADD(HOUR, -4, d.DrawTime), DATEADD(HOUR, @TimeZone, d.DrawTime), d.Amount
			FROM dbo.DrawLog d WITH (NOLOCK)
				INNER JOIN dbo.EventDraw e WITH (NOLOCK) ON d.EventId = e.EventId
				INNER JOIN #BonusInfoDetail bi ON bi.BonusCode = e.EventName AND bi.DataSource = 'DrawLog'
			WHERE d.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND d.DrawTime >= @FromDateTimeGMT AND d.DrawTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND d.SiteId = @SiteId
				AND e.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
		END

		-- AdjustmentInfo
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail WHERE BonusTypeId = 101 AND BonusCode = BonusTypeName)
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, DataSource, TransactionType, Amount)
			SELECT a.CustId, bi.BonusCode, '' AS BonusName, bi.BonusTypeId, bi.BonusTypeName , a.CurrencyId, DATEADD(HOUR, -4, a.CreateTime), DATEADD(HOUR, @TimeZone, a.CreateTime), 'AdjustmentInfo', AdjustType
				,a.Amount * CASE
							WHEN a.AdjustType IN (1, 3) THEN 1 -- Credit, Increase bonus
							WHEN a.AdjustType IN (2, 4) THEN -1 -- Debit, Decrease bonus
							ELSE 0 END
			FROM dbo.AdjustmentInfo a WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.BonusTypeId = 101
			WHERE a.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND a.CreateTime >= @FromDateTimeGMT AND a.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND a.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), CurrencyId) + ',%'
				AND a.Status = 2 -- Approved
				AND 1 = CASE WHEN a.CreateTime < '2021-10-31 16:00' OR a.AdjustType IN (3, 4) THEN 1 ELSE 0 END -- From 1 Nov 2021 (GMT+8), just get Increase & Decrease bonus
		END

		-- LogAdminAdjustWallet
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail WHERE BonusTypeId = 101 AND BonusCode = BonusTypeName) 
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, DataSource, TransactionType, Amount)
			SELECT l.CustId, bi.BonusCode, '' AS BonusName, bi.BonusTypeId, bi.BonusTypeName, l.CurrencyId, DATEADD(HOUR, -4, l.CreateTime), DATEADD(HOUR, @TimeZone, l.CreateTime), 'LogAdminAdjustWallet', l.Direction
				,l.Amount * CASE
							WHEN l.Direction = 1 THEN 1 -- 3rd Add
							WHEN l.Direction = 2 THEN -1 -- 3rd Minus
							ELSE 0 END
			FROM dbo.LogAdminAdjustWallet l WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.BonusTypeId = 101
			WHERE l.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND l.CreateTime >= @FromDateTimeGMT AND l.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND l.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), l.CurrencyId) + ',%'
				AND l.Status = 0 -- Success
				AND l.CreateTime < '2021-10-31 16:00' -- only get data before 1 Nov 2021 (GMT+8)
		END

		-- VIPUpgradeReview
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail WHERE DataSource = 'VIPUpgradeReview' AND BonusCode = BonusTypeName )
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, Amount)
			SELECT v.CustId, bi.BonusCode, '' AS BonusName, bi.BonusTypeId, bi.BonusTypeName, v.CurrencyId, DATEADD(HOUR, -4, v.SettleTime), DATEADD(HOUR, @TimeZone, v.SettleTime), v.UpgradeAmount
			FROM dbo.VipUpgradeReview v WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.DataSource = 'VIPUpgradeReview'
			WHERE v.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND v.SettleTime >= @FromDateTimeGMT AND v.SettleTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND v.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), v.CurrencyId) + ',%'
				AND v.Status = 4 -- Settled
		END

		-- CustVerificationRewardDetail
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail WHERE DataSource = 'CustVerificationReward' AND BonusCode = BonusTypeName )
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, DataSource, TransactionType, Amount)
			SELECT c.CustId, bi.BonusCode, '' AS BonusName, bi.BonusTypeId, bi.BonusTypeName, c.CurrencyId, DATEADD(HOUR, -4, c.RewardTime), DATEADD(HOUR, @TimeZone, c.RewardTime), 'CustVerificationReward', c.RewardType, c.RewardAmount
			FROM dbo.CustVerificationRewardDetail c WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.DataSource = 'CustVerificationReward'
			WHERE c.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND c.RewardTime >= @FromDateTimeGMT AND c.RewardTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND c.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
		END

		-- Referral (ReferralMLog)
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail WHERE BonusTypeId = 105 AND BonusCode = BonusTypeName ) 
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, Amount, DataSource, TransactionType)
			SELECT r.CustId, bi.BonusCode, '' AS BonusName, bi.BonusTypeId, bi.BonusTypeName, r.CurrencyId, DATEADD(HOUR, -4, r.CreateTime), DATEADD(HOUR, @TimeZone, r.CreateTime), r.ReferralAmount, 'ReferralMLog',-2
			FROM dbo.ReferralMLog r WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.BonusTypeId = 105
			WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND r.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.CurrencyId) + ',%'
		END

		-- Referral (ReferralLog)
		IF EXISTS (SELECT 1 FROM #BonusInfoDetail WHERE BonusTypeId = 105  AND BonusCode = BonusTypeName )
		BEGIN
			INSERT INTO #BonusInfo (CustId, BonusCode, BonusName, BonusTypeId, BonusTypeName, CurrencyId, ExchangeDate, ClaimedDate, Amount, DataSource, TransactionType)
			SELECT r.CustId, bi.BonusCode, '' AS BonusName, bi.BonusTypeId, bi.BonusTypeName, r.CurrencyId, DATEADD(HOUR, -4, r.CreateTime), DATEADD(HOUR, @TimeZone, r.CreateTime), r.ReferralFreeCredit, 'ReferralLog',-1
			FROM dbo.ReferralLog r WITH (NOLOCK)
				INNER JOIN #BonusInfoDetail bi ON bi.BonusTypeId = 105
			WHERE r.WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND r.CreateTime >= @FromDateTimeGMT AND r.CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND r.SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.CurrencyId) + ',%'
				AND r.RewardStatus = 1
		END

		-- Deposit, Withdrawal
		BEGIN
			INSERT INTO #DepositInfo (CustId, CurrencyId, ExchangeDate, Amount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(ActualDeposit)
			FROM dbo.DepositInfo d WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND Status = 3 -- Approved
				AND SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), d.CurrencyId) + ',%'
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))

			INSERT INTO #WithdrawalInfo (CustId, CurrencyId, ExchangeDate, Amount)
			SELECT CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime)), SUM(Amount)
			FROM dbo.WithdrawalInfo w WITH (NOLOCK)
			WHERE WinlostDate BETWEEN @tmpFromDate AND @tmpToDate
				AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
				AND Status = 6 -- Approved
				AND SiteId = @SiteId
				AND ',' + @TPCurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), w.CurrencyId) + ',%'
			GROUP BY CustId, CurrencyId, CONVERT(DATE, DATEADD(HOUR, -4, CreateTime))
		END

		DELETE b
		FROM #BonusInfo b
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON b.CustId = c.CustId
		WHERE c.IsTest = 1
			OR c.MemberType = 3 -- Live Streamer

		DELETE #DepositInfo WHERE CustId NOT IN (SELECT CustId FROM #BonusInfo)
		DELETE #WithdrawalInfo WHERE CustId NOT IN (SELECT CustId FROM #BonusInfo)

		UPDATE b
		SET b.Amount = b.Amount * e.Rate
		FROM #BonusInfo b
			INNER JOIN #TPExchange e ON b.CurrencyId = e.TpExchangeId AND b.ExchangeDate BETWEEN e.FromDate AND e.ToDate

		UPDATE d
		SET d.Amount = d.Amount * e.Rate
		FROM #DepositInfo d
			INNER JOIN #TPExchange e ON d.CurrencyId = e.TpExchangeId AND d.ExchangeDate BETWEEN e.FromDate AND e.ToDate

		UPDATE w
		SET w.Amount = w.Amount * e.Rate
		FROM #WithdrawalInfo w
			INNER JOIN #TPExchange e ON w.CurrencyId = e.TpExchangeId AND w.ExchangeDate BETWEEN e.FromDate AND e.ToDate
	END

	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @RowStart = @PageSize * (@PageIndex - 1) + 1, @RowEnd = @RowStart + @PageSize - 1

	SELECT @NRows = COUNT(1) FROM #BonusInfo

	-- Return
	SELECT RowId, UserName, CurrencyName AS Currency, TpUserName AS [SabaId], BonusCode, BonusName, BonusTypeName AS [BonusType], ClaimedDate, ClaimedAmount, TransactionType, TotalDeposit, TotalWithdrawal, Status, PercentagedCompletion
	FROM (
		SELECT UserName, CurrencyName, TpUserName, BonusCode, BonusName, BonusTypeName, ClaimedDate, ClaimedAmount, TransactionType, TotalDeposit, TotalWithdrawal, Status, PercentagedCompletion
			,ROW_NUMBER() OVER(ORDER BY
							 CASE WHEN @SortbyId = 1 AND @IsSortAsc = 1 THEN UserName END ASC
							,CASE WHEN @SortbyId = 1 AND @IsSortAsc = 0 THEN UserName END DESC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 1 THEN TpUserName END ASC
							,CASE WHEN @SortbyId = 2 AND @IsSortAsc = 0 THEN TpUserName END DESC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 1 THEN CurrencyName END ASC
							,CASE WHEN @SortbyId = 3 AND @IsSortAsc = 0 THEN CurrencyName END DESC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 1 THEN BonusCode END ASC
							,CASE WHEN @SortbyId = 4 AND @IsSortAsc = 0 THEN BonusCode END DESC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 1 THEN BonusTypeName END ASC
							,CASE WHEN @SortbyId = 5 AND @IsSortAsc = 0 THEN BonusTypeName END DESC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 1 THEN BonusName END ASC
							,CASE WHEN @SortbyId = 6 AND @IsSortAsc = 0 THEN BonusName END DESC
							,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 1 THEN ClaimedDate END ASC
							,CASE WHEN @SortbyId = 7 AND @IsSortAsc = 0 THEN ClaimedDate END DESC
							,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 1 THEN ClaimedAmount END ASC
							,CASE WHEN @SortbyId = 8 AND @IsSortAsc = 0 THEN ClaimedAmount END DESC
							,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 1 THEN TransactionType END ASC
							,CASE WHEN @SortbyId = 9 AND @IsSortAsc = 0 THEN TransactionType END DESC
							,CASE WHEN @SortbyId = 10 AND @IsSortAsc = 1 THEN TotalDeposit END ASC
							,CASE WHEN @SortbyId = 10 AND @IsSortAsc = 0 THEN TotalDeposit END DESC
							,CASE WHEN @SortbyId = 11 AND @IsSortAsc = 1 THEN TotalWithdrawal END ASC
							,CASE WHEN @SortbyId = 11 AND @IsSortAsc = 0 THEN TotalWithdrawal END DESC
							,CASE WHEN @SortbyId = 12 AND @IsSortAsc = 1 THEN Status END ASC
							,CASE WHEN @SortbyId = 12 AND @IsSortAsc = 0 THEN Status END DESC
							,CASE WHEN @SortbyId = 13 AND @IsSortAsc = 1 THEN PercentagedCompletion END ASC
							,CASE WHEN @SortbyId = 13 AND @IsSortAsc = 0 THEN PercentagedCompletion END DESC) AS RowId
		FROM (
			SELECT c.UserName
				,CASE
					WHEN e.ExchangeId = 51 THEN 'INH'
					WHEN e.ExchangeId = 20 THEN 'UUS'
					ELSE e.Code 
				 END AS CurrencyName
				, c.TpUserName, b.BonusCode, b.BonusName, b.BonusTypeName, b.ClaimedDate, b.Amount AS ClaimedAmount, ISNULL(d.Amount, 0) AS TotalDeposit, ISNULL(w.Amount, 0) AS TotalWithdrawal, b.Status, ISNULL(b.PercentagedCompletion, 0) AS PercentagedCompletion
				,CONVERT(VARCHAR(100),
					CASE
						WHEN b.DataSource = 'AdjustmentInfo' AND b.TransactionType = 1 THEN 'Credit'
						WHEN b.DataSource = 'AdjustmentInfo' AND b.TransactionType = 2 THEN 'Debit'
						WHEN b.DataSource = 'AdjustmentInfo' AND b.TransactionType = 3 THEN 'Increase bonus'
						WHEN b.DataSource = 'AdjustmentInfo' AND b.TransactionType = 4 THEN 'Decrease bonus'
						WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.TransactionType = 1 THEN '3rd Add'
						WHEN b.DataSource = 'LogAdminAdjustWallet' AND b.TransactionType = 2 THEN '3rd Minus'
						WHEN b.DataSource = 'CustVerificationReward' AND b.TransactionType = 1 THEN 'Phone'
						WHEN b.DataSource = 'CustVerificationReward' AND b.TransactionType = 2 THEN 'Email'
						WHEN b.DataSource = 'ReferralMLog' AND b.TransactionType = -2 THEN 'Referral_Agent'
						WHEN b.DataSource = 'ReferralLog' AND b.TransactionType = -1 THEN 'Referral_Sub'
						END
					) AS TransactionType
			FROM dbo.Customer c WITH (NOLOCK)
				INNER JOIN #BonusInfo b ON b.CustId = c.CustId
				LEFT JOIN dbo.TpExchange tp WITH(NOLOCK) ON tp.TpExchangeId = c.CurrencyId
				INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON ISNULL(tp.ExchangeId, c.CurrencyId) = e.ExchangeId
				LEFT JOIN (
					SELECT d.CustId, SUM(d.Amount) AS Amount
					FROM #DepositInfo d
					GROUP BY d.CustId
				) d ON d.CustId = c.CustId
				LEFT JOIN (
					SELECT w.CustId, SUM(w.Amount) AS Amount
					FROM #WithdrawalInfo w
					GROUP BY w.CustId
				) w ON w.CustId = c.CustId
		) t
	) r
	WHERE RowId BETWEEN @RowStart AND @RowEnd
	ORDER BY RowId

	DROP TABLE #BonusInfo
	DROP TABLE #DepositInfo
	DROP TABLE #TPExchange
	DROP TABLE #WithdrawalInfo
	DROP TABLE #BonusInfoDetail
END
GO