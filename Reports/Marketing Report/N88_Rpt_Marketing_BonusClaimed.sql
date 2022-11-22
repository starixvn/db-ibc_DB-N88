/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
USE bodb_N88
GO

ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BonusClaimed]
	@LicenseeId				INT
	,@FromDate				DATE
	,@ToDate				DATE
	,@CompareFromDate		DATE = NULL
	,@CompareToDate			DATE = NULL
	,@CurrencyIds			VARCHAR(MAX)
	,@DisplayCurrency		VARCHAR(3)
	,@TimeZone				SMALLINT = 8
	,@TotalBonusUsers		INT = 0 OUTPUT
	,@TotalBasedBonusAmount MONEY = 0 OUTPUT
AS

/*
	Created: 20200818@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Bonus Info

	Revisions:
		- 20200818@Percy: Initialize SP [RedmineID: #141575]
		- 20201029@Percy: Change Bonus User to Bonus Amount [RedmineID: #143879]
		- 20210113@Percy: Add Rebate & Cashback [RedmineID: #148616]
		- 20210401@Percy: [RedmineID: #150876]
			1. Add Bonus Name column
			2. Breakdown by original currency
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - add currency filter - [RedmineID: #155334]
		- 20211028@Percy: Integrate some bonus types [RedmineID: #161048]
		- 20211118@Percy: Add LogAdminAdjustWallet table [RedmineID: #161048]
		- 20220325@Percy: Integrate new bonus: Verification Reward [RedmineID: #170390]
		- 20220412@Percy: Integrate new bonus: Referral & Rebuild Bonus Structure [RedmineID: #171245]
		- 20221017@Malcolm: Support BDT currency [RedmineId: #178713]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT, @tmpFDate DATE, @tmpTDate DATE

	CREATE TABLE #tmpBonus (BonusDate DATE, DataSource VARCHAR(128), BonusType SMALLINT, BonusCode VARCHAR(100), BonusName VARCHAR(300), BonusStatus TINYINT, CustId INT, CurrencyId INT, BetCount INT, BonusAmount MONEY, BasedBonusAmount MONEY, IsCompared BIT)
	
	-- Get Bonus data
	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		DECLARE @i TINYINT = 1, @IsCompared BIT
		WHILE @i <= 2
		BEGIN
			IF @i = 1 -- Date range
				SELECT @IsCompared = 0, @tmpFDate = @FromDate, @tmpTDate = @ToDate
			ELSE -- Compare date range
				SELECT @IsCompared = 1, @tmpFDate = @CompareFromDate, @tmpTDate = @CompareToDate

			IF @tmpFDate IS NOT NULL AND @tmpTDate IS NOT NULL
			BEGIN
				INSERT INTO #tmpBonus (BonusDate, DataSource, BonusType, BonusCode, BonusName, BonusStatus, CustId, CurrencyId, BetCount, BonusAmount, BasedBonusAmount)
				EXEC dbo.N88_CustBonusSummary_Sel
					@SiteId = @SiteId
					,@FromDate = @tmpFDate
					,@ToDate = @tmpTDate
					,@CurrencyIds = @CurrencyIds
					,@DisplayCurrency = @DisplayCurrency
					,@TimeZone = @TimeZone

				UPDATE #tmpBonus SET IsCompared = @IsCompared WHERE IsCompared IS NULL
			END
			
			SELECT @i = @i + 1
		END

		--Update currency
		UPDATE t
			SET t.CurrencyId = tp.ExchangeId
		FROM #tmpBonus t
			INNER JOIN dbo.TPExchange tp WITH(NOLOCK) ON t.CurrencyId = tp.TPExchangeId

		-- Summary by Currency
		SELECT b.CurrencyId AS Currency
			,SUM(CASE WHEN b.IsCompared = 0 THEN b.BonusAmount ELSE 0 END)		AS BonusAmountClaimeds
			,SUM(CASE WHEN b.IsCompared = 0 THEN b.BasedBonusAmount ELSE 0 END) AS BasedBonusAmountClaimeds
			,SUM(CASE WHEN b.IsCompared = 1 THEN b.BonusAmount ELSE 0 END)		AS CompareBonusAmountClaimeds
			,SUM(CASE WHEN b.IsCompared = 1 THEN b.BasedBonusAmount ELSE 0 END) AS CompareBasedBonusAmountClaimeds
		FROM #tmpBonus b
		GROUP BY b.CurrencyId

		-- Detail by Bonus Code, Currency
		SELECT b.BonusCode, b.CurrencyId AS Currency, b.BonusName, COUNT(DISTINCT CustId) AS BonusUsers, SUM(BonusAmount) AS BonusAmount, SUM(BasedBonusAmount) AS BasedBonusAmount
		FROM #tmpBonus b
		WHERE b.IsCompared = 0
		GROUP BY b.BonusCode, b.CurrencyId, b.BonusName
		ORDER BY CASE WHEN BonusCode IS NULL THEN 1 ELSE 0 END, BonusCode

		-- Total
		SELECT @TotalBonusUsers = COUNT(DISTINCT CustId), @TotalBasedBonusAmount = SUM(BasedBonusAmount) FROM #tmpBonus WHERE IsCompared = 0

		DROP TABLE #tmpBonus
	END
END
GO