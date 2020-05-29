/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/

USE bodb_N88

GO

ALTER PROCEDURE [dbo].Task_N88_ImportData_3rdProducts
	@WinlostDate SMALLDATETIME
AS

/*
	Created: 20200506@Sol
	DB: DBN88-bodb_N88
	Task: Job - Import data of 3rd Products

	Revisions:
		- 20200506@Sol: Initialize SP [RedmineID: #133254]
*/

BEGIN 
	
	SET NOCOUNT ON

	-- Get data
	BEGIN

		CREATE TABLE #tmpN88_RptWinloss
		(
			WinlostDate	DATE NOT NULL,
			CustId	INT NOT NULL,
			GameType	INT NOT NULL,
			Currency	INT NOT NULL,
			TurnOver	MONEY NULL,
			Winloss	MONEY NULL,
			BetCount	INT NULL,
			LicenseeID	INT NOT NULL,
			StatusID	TINYINT NOT NULL,
			UserName	VARCHAR(30) NOT NULL,
			WinlostDateGMT	DATE NOT NULL,
			[TimeZone]	SMALLINT NOT NULL,
			TransDate DATE NOT NULL,
			TransDateGMT DATE NOT NULL,
			IsTest	BIT NOT NULL
		)
		
		;WITH rs AS 
		(
			SELECT 
				CAST(DATEADD(hh, -4, transtime) AS DATE) transdate , 
				CAST(DATEADD(hh, 8, transtime) AS DATE) transdateGMT, 
				CAST(DATEADD(hh, -4, SettledTime) AS DATE) WinlostDate, 
				td.CustId, td.UserName, GameType, td.CurrencyId, 
				CASE WHEN exCode.Code IN ('INH', 'IDR') THEN Stake/1000 ELSE Stake END Stake, 
				CASE WHEN exCode.Code IN ('INH', 'IDR') THEN winlostamount/1000 ELSE winlostamount END winlostamount,
				transid , l.LicenseeID, TicketStatus, 
				CAST(DATEADD(hh, 8, SettledTime) AS DATE) WinlostDateGMT, 8 AS timezone,
				c.IsTest
			FROM dbo.TpBetRecord td WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Exchange exCode WITH(NOLOCK)
					ON td.CurrencyId = exCode.exchangeid
				INNER JOIN dbo.ServerInfo s WITH(NOLOCK)
					ON td.SiteId = s.SiteId
				INNER JOIN bodb_licensee.dbo.Licensees l WITH(NOLOCK)
					ON l.LicenseeName = s.LicenseeName
				INNER JOIN Customer c WITH(NOLOCK)
					ON td.CustId = c.CustId
			WHERE 
				WinlostDate BETWEEN DATEADD(DAY, -1, @WinlostDate) AND DATEADD(DAY, 1, @WinlostDate)
				AND TicketStatus in (1,2,4) 
				AND CAST(DATEADD(hh, -4, SettledTime) as date) = @WinlostDate
		)

		INSERT INTO #tmpN88_RptWinloss 
		(
			TransDate, TransDateGMT, WinlostDate, WinlostDateGMT, CustId, UserName, GameType, 
			Currency, TurnOver, Winloss, BetCount, LicenseeID, TimeZone, StatusID, IsTest
		)
		SELECT transdate, transdateGMT, WinlostDate ,WinlostDateGMT, CustId, UserName, GameType, CurrencyId, 
			SUM(stake) AS turnover, SUM(winlostamount) ggr, COUNT(transid) betcount, rs.LicenseeID,  8 AS timezone
			,TicketStatus, IsTest
		FROM rs
		GROUP BY transdate, transdateGMT, WinlostDate ,WinlostDateGMT, CustId, UserName, GameType, CurrencyId, LicenseeID,TicketStatus, IsTest

	END

	-- Gen data into N88_RptWinloss
	MERGE dbo.N88_RptWinloss AS TARGET
	USING #tmpN88_RptWinloss AS SOURCE
	ON 
			TARGET.TransDate = SOURCE.TransDate
		AND TARGET.TransDateGMT = SOURCE.TransDateGMT
		AND TARGET.WinlostDate = SOURCE.WinlostDate
		AND TARGET.WinlostDateGMT = SOURCE.WinlostDateGMT
		AND TARGET.CustId = SOURCE.CustId
		AND TARGET.GameType = SOURCE.GameType
		AND TARGET.LicenseeID = SOURCE.LicenseeID
		AND TARGET.StatusID = SOURCE.StatusID
	WHEN MATCHED THEN 
		UPDATE 
			SET
				TARGET.Currency			= SOURCE.Currency
				,TARGET.TurnOver		= SOURCE.TurnOver
				,TARGET.Winloss			= SOURCE.Winloss
				,TARGET.BetCount		= SOURCE.BetCount
				,TARGET.UserName		= SOURCE.UserName
				,TARGET.TimeZone		= SOURCE.TimeZone
				,TARGET.IsTest			= SOURCE.IsTest
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT (TransDate, TransDateGMT, WinlostDate, WinlostDateGMT, CustId, UserName, GameType, Currency, TurnOver, Winloss, BetCount, LicenseeID, TimeZone, StatusID, IsTest)
		VALUES 
		(
			SOURCE.TransDate, 
			SOURCE.TransDateGMT, 
			SOURCE.WinlostDate, 
			SOURCE.WinlostDateGMT, 
			SOURCE.CustId, 
			SOURCE.UserName, 
			SOURCE.GameType, 
			SOURCE.Currency, 
			SOURCE.TurnOver, 
			SOURCE.Winloss, 
			SOURCE.BetCount, 
			SOURCE.LicenseeID, 
			SOURCE.TimeZone, 
			SOURCE.StatusID,
			SOURCE.IsTest
		)
	WHEN NOT MATCHED BY SOURCE AND TARGET.WinlostDate = @Winlostdate THEN
		DELETE
	;
		
	--DROP TABLE #_CheckData
	DROP TABLE #tmpN88_RptWinloss

END
