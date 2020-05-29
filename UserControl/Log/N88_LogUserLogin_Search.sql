/*<info serverAlias="DBN88LOG-bodb_N88Log" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_LogUserLogin_Search] @Name NVARCHAR(50) = ''
	,@SiteId TINYINT
	,@From DATETIME
	,@To DATETIME
	,@IsExcludeIT BIT = 0
	,@PageIndex INT
	,@PageSize INT
	,@TotalRows INT = 0 OUTPUT
AS
/*
	Created: 20200314@Kos
	Task: Search new login log
	DB: DBN88LOG.bodb_N88Log

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20200407@Oliver: Add param @IsExcludeIT BIT [RedmineID: #129873]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec INT
		,@LastRec INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1

	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	-- gets total rows
	SET @TotalRows = (
			SELECT COUNT(1)
			FROM dbo.N88Log_UserLogin AS lu WITH (NOLOCK)
			INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lu.UserId = u.UserId
			WHERE u.username LIKE '%' + @Name + '%'
				AND lu.LogDate BETWEEN @From
					AND @To
				AND lu.SiteId = @SiteId
				AND (
					@IsExcludeIT = 0
					OR (@IsExcludeIT = 1 AND u.IsLicenseeUser = 1)
					)
			)

	-- gets data
	SELECT TOP (@PageSize) *
	FROM (
		SELECT lu.Id
			,lu.IP
			,lu.LogDate
			,lu.DomainName
			,lu.BrowserName
			,lu.Platform
			,lu.CountryCode
			,lu.Duration
			,lu.UserId
			,u.username
			,lu.SiteId
			,s.SiteName
			,ROW_NUMBER() OVER (
				ORDER BY lu.LogDate DESC
				) AS num
		FROM dbo.N88Log_UserLogin AS lu WITH (NOLOCK)
		INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lu.UserId = u.UserId
		LEFT JOIN DBPOL.N88_UserControl.dbo.N88_Sites AS s WITH (NOLOCK) ON lu.SiteId = s.SiteId
		WHERE u.username LIKE '%' + @Name + '%'
			AND lu.LogDate BETWEEN @From
				AND @To
			AND lu.SiteId = @SiteId
			AND (
				@IsExcludeIT = 0
				OR (@IsExcludeIT = 1 AND u.IsLicenseeUser = 1)
				)
		) AS TEMP
	WHERE TEMP.num BETWEEN @FirstRec
			AND @LastRec
	ORDER BY TEMP.num ASC
END
GO
