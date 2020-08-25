/*<info serverAlias="DBN88-bodb_N88" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[N88_Rpt_Marketing_BusinessPerformance]
	@LicenseeId			INT
	,@FromDate			DATE
	,@ToDate			DATE
	,@CompareFromDate	DATE = NULL
	,@CompareToDate		DATE = NULL
	,@TimeZone			SMALLINT = 8
AS

/*
	Created: 20200713@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Marketing Report - Business Performance

	Revisions:
		- 20200713@Percy: Initialize SP [RedmineID: #137395]
		- 20200818@Percy: Support special date range [RedmineID: #137395]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId INT

	DECLARE @FromDateTimeGMT DATETIME, @ToDateTimeGMT DATETIME
			,@CompareFromDateTimeGMT DATETIME, @CompareToDateTimeGMT DATETIME

	DECLARE @TotalUsers INT, @PaidUsers	INT
			,@UptoTotalUsers INT, @CompareUptoTotalUsers INT
			,@NewlyRegisterUsers INT, @CompareNewlyRegisterUsers INT
			,@ActiveUsers INT, @CompareActiveUsers INT

	BEGIN
		SELECT @SiteId = SiteId
		FROM dbo.ServerInfo s WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.Licensees l WITH (NOLOCK) ON s.LicenseeName = l.LicenseeName
		WHERE l.LicenseeId = @LicenseeId

		-- Data on GMT+0 --> convert timezone
		SELECT  @FromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate))
				,@ToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))
				,@CompareFromDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareFromDate))
				,@CompareToDateTimeGMT = DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @CompareToDate))

		SELECT
			@TotalUsers = COUNT(1)
			,@PaidUsers = COUNT(CASE WHEN ActStatus = 2 THEN 1 ELSE NULL END)
			,@UptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
			,@CompareUptoTotalUsers = COUNT(CASE WHEN RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
			,@NewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @FromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @ToDateTimeGMT) THEN 1 ELSE NULL END)
			,@CompareNewlyRegisterUsers = COUNT(CASE WHEN RegTime >= @CompareFromDateTimeGMT AND RegTime < DATEADD(DAY, 1, @CompareToDateTimeGMT) THEN 1 ELSE NULL END)
		FROM dbo.Customer WITH (NOLOCK)
		WHERE SiteId = @SiteId
			AND IsTest = 0
		
		SELECT @ActiveUsers = COUNT(1)
		FROM (
			SELECT CustId
			FROM (
				SELECT CustId
				FROM dbo.N88_RptWinloss WITH (NOLOCK)
				WHERE TransDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
					AND TransDateGMT BETWEEN @FromDate AND @ToDate
					AND TimeZone = @TimeZone
					AND LicenseeId = @LicenseeId
				GROUP BY CustId

				UNION ALL
				SELECT CustId
				FROM dbo.TpTransferInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN DATEADD(DAY, -1, @FromDate) AND DATEADD(DAY, 1, @ToDate)
					AND CreateTime >= @FromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @ToDateTimeGMT)
					AND SiteId = @SiteId
				GROUP BY CustId
			) AS t
			GROUP BY CustId
		) AS a
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
		WHERE c.IsTest = 0

		SELECT @CompareActiveUsers = COUNT(1)
		FROM (
			SELECT CustId
			FROM (
				SELECT CustId
				FROM dbo.N88_RptWinloss WITH (NOLOCK)
				WHERE TransDate BETWEEN DATEADD(DAY, -1, @CompareFromDate) AND DATEADD(DAY, 1, @CompareToDate)
					AND TransDateGMT BETWEEN @CompareFromDate AND @CompareToDate
					AND TimeZone = @TimeZone
					AND LicenseeId = @LicenseeId
				GROUP BY CustId

				UNION ALL
				SELECT CustId
				FROM dbo.TpTransferInfo WITH (NOLOCK)
				WHERE WinlostDate BETWEEN DATEADD(DAY, -1, @CompareFromDate) AND DATEADD(DAY, 1, @CompareToDate)
					AND CreateTime >= @CompareFromDateTimeGMT AND CreateTime < DATEADD(DAY, 1, @CompareToDateTimeGMT)
					AND SiteId = @SiteId
				GROUP BY CustId
			) AS t
			GROUP BY CustId
		) AS a
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON a.CustId = c.CustId
		WHERE c.IsTest = 0
	END

	-- Return data
	SELECT @TotalUsers AS TotalUsers
			,@UptoTotalUsers AS UptoTotalUsers
			,@CompareUptoTotalUsers AS CompareUptoTotalUsers
			,@PaidUsers	AS PaidUsers
			,@NewlyRegisterUsers AS NewlyRegisterUsers
			,@CompareNewlyRegisterUsers AS CompareNewlyRegisterUsers
			,@ActiveUsers AS ActiveUsers
			,@CompareActiveUsers AS CompareActiveUsers
END
GO