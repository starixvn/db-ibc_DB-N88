/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_UserActivities]
	@LicenseeId	INT
	,@FromDate	DATE
	,@ToDate	DATE
	,@TimeZone	SMALLINT = 8
	,@ViewBy	TINYINT = 1
	,@CurrencyIds VARCHAR(MAX)
AS

/*
	Created: 20200713@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - User Activity

	Revisions:
		- 20200713@Percy: Initialize SP [RedmineID: #137395]
		- 20200818@Percy: Change output format of daily mode [RedmineID: #137395]
		- 20210525@Sol: MPA - Add more information to Marketing & WL Analysis - change from N88_RptWinloss to N88_SumWinloss - [RedmineID: #155334]

	Param's Explanation:
		. ViewBy:
			1 = Daily
			2 = Weekly
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME

	CREATE TABLE #UserActivities (WinlostDate DATE, CustId INT, IsActive BIT, IsNewlyRegister BIT)
	CREATE CLUSTERED INDEX CIX_WinlostDate ON #UserActivities (WinlostDate, CustId)

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

		INSERT INTO #UserActivities (WinlostDate, CustId, IsActive, IsNewlyRegister)
		SELECT a.WinlostDate, a.CustId, 1, CASE WHEN c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE 0 END
		FROM (
			SELECT WinlostDate, CustId
			FROM (
				SELECT CONVERT(DATE,DATEADD(HOUR, @TimeZone, TransTime)) AS WinlostDate, CustId
				FROM dbo.N88_SumWinloss r WITH (NOLOCK)
				WHERE r.TransTime >= @FromDateTimeGMT AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND r.SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), r.Currency) + ',%'
				GROUP BY DATEADD(HOUR, @TimeZone, TransTime), CustId

				UNION ALL
				SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), t.CustId
				FROM dbo.TpTransferInfo t WITH (NOLOCK)
					INNER JOIN dbo.Customer c WITH(NOLOCK)
						ON t.CustId = c.CustId
				WHERE WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND t.SiteId = @SiteId
					AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
				GROUP BY CONVERT(DATE, DATEADD(HOUR, @TimeZone, CreateTime)), t.CustId
			) AS t
			GROUP BY WinlostDate, CustId
		) AS a
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
		WHERE c.IsTest = 0

		INSERT INTO #UserActivities (WinlostDate, CustId, IsActive, IsNewlyRegister)
		SELECT CONVERT(DATE, DATEADD(HOUR, @TimeZone, RegTime)), CustId, 0, 1
		FROM dbo.Customer c WITH (NOLOCK)
		WHERE c.RegTime >= @FromDateTimeGMT AND c.RegTime < DATEADD(DAY, 1, @ToDateTimeGMT)
			AND c.IsTest = 0
			AND c.SiteId = @SiteId
			AND NOT EXISTS (SELECT 1 FROM #UserActivities u WHERE c.CustId = u.CustId)
			AND ',' + @CurrencyIds + ',' LIKE '%,' + CONVERT(VARCHAR(15), c.CurrencyId) + ',%'
	END

	-- Return data
	;WITH CTE_WinlostDate AS
	(
		SELECT @FromDate AS WinlostDate
		UNION ALL
		SELECT DATEADD(DAY, 1, WinlostDate)
		FROM CTE_WinlostDate
		WHERE WinlostDate < @ToDate
	)
	SELECT
		CASE @ViewBy
			WHEN 1 THEN CONVERT(VARCHAR(6), w.WinlostDate, 106)
			WHEN 2 THEN 'W'
						+ RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(WEEK, w.WinlostDate)), 2)
						+ '/'
						+ CONVERT(VARCHAR(5), DATEPART(YEAR, w.WinlostDate))
			END AS ViewBy
		,COUNT(DISTINCT CASE WHEN u.IsActive = 1 THEN u.CustId END) AS ActiveUsers
		,COUNT(DISTINCT CASE WHEN u.IsNewlyRegister = 1 THEN u.CustId END) AS NewlyRegisterUsers
	FROM CTE_WinlostDate w
		LEFT JOIN #UserActivities u ON w.WinlostDate = u.WinlostDate
	GROUP BY
		DATEPART(YEAR, w.WinlostDate)
		,CASE @ViewBy
			WHEN 1 THEN CONVERT(VARCHAR(6), w.WinlostDate, 106)
			WHEN 2 THEN 'W'
						+ RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(WEEK, w.WinlostDate)), 2)
						+ '/'
						+ CONVERT(VARCHAR(5), DATEPART(YEAR, w.WinlostDate))
			END
		,CASE WHEN @ViewBy = 1 THEN w.WinlostDate END
	ORDER BY
		DATEPART(YEAR, w.WinlostDate)
		,CASE WHEN @ViewBy = 1 THEN w.WinlostDate END
		,ViewBy
	OPTION (MAXRECURSION 0)

	DROP TABLE #UserActivities
END
GO