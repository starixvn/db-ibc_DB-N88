/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_Search]
	@Username				NVARCHAR(50)
	,@GroupId				SMALLINT
	,@ExcludeLicenseeUser	BIT			= 1
	,@SiteId				TINYINT
	,@Status				TINYINT
	,@Environment			VARCHAR(10)	= 'UAT'
	,@PageIndex				INT
	,@PageSize				INT
	,@TotalRows				INT			= 0 OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Search user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20201118@Kos: Support default base currency [RedmineID: #145346]

	Param's Explanation:
		- @Environment: UAT or LIVE
		- @Username: Username search text
		- @GroupId: User group ID (0: All groups, Others: specific group)
		- @SiteId: Site ID (0: No site, -9999: All sites, Others: specific site)
		- @Status: Status (0: All, 1: Active, 2: Inactive)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Site TABLE (SiteId TINYINT)

	INSERT INTO @Site
	SELECT SiteId
	FROM dbo.N88_Sites WITH (NOLOCK)
	WHERE @Environment = 'UAT'
		OR Environment = @Environment

	DECLARE @Users TABLE (
		UserId INT
		,Username NVARCHAR(50)
		)

	INSERT INTO @Users
	SELECT u.UserId
		,u.username
	FROM dbo.N88_Users AS u WITH (NOLOCK)
	WHERE (@GroupId = 0 OR u.GroupId = @GroupId )
		AND (@Username IS NULL OR @Username = '' OR u.Username LIKE '%' + REPLACE(REPLACE(@Username, '_', '\_'), '%', '\%') + '%'  ESCAPE '\')

	DECLARE @UserSite TABLE (
		UserId INT
		,SiteId TINYINT
		,IsActive BIT
		,[Level] INT
		)

	INSERT INTO @UserSite
	SELECT us.UserId
		,us.SiteId
		,us.IsActive
		,us.[Level]
	FROM dbo.N88_UserSite AS us WITH (NOLOCK)
	WHERE EXISTS (
			SELECT 1
			FROM @Site
			WHERE SiteId = us.SiteId
			)
		AND (
			(@Status = 1 AND us.IsActive = 1)
			OR (@Status = 2 AND us.IsActive = 0)
			OR @Status IN (0, 3)
			)

	DECLARE @FirstRec INT
		,@LastRec INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1

	SELECT @LastRec = @PageIndex * @PageSize

	-- Gets total rows
	IF @Status IN (0, 3)
	BEGIN
		SET @TotalRows = (
				SELECT DISTINCT COUNT(1)
				FROM @Users AS u
					LEFT JOIN @UserSite AS us ON u.UserId = us.UserId
				WHERE (
						@SiteId = 0
						AND NOT EXISTS (
							SELECT 1
							FROM @UserSite
							WHERE UserId = u.UserId
							)
						) -- No site
					OR (
						@SiteId > 0
						AND us.SiteId = @SiteId
						) -- Specific site
					OR @SiteId < 0 -- All sites
				)
	END
	ELSE IF @Status IN (1, 2)
	BEGIN
		SET @TotalRows = (
				SELECT DISTINCT COUNT(1)
				FROM @Users AS u
					INNER JOIN @UserSite AS us ON u.UserId = us.UserId
				WHERE (
						@SiteId = 0
						AND NOT EXISTS (
							SELECT 1
							FROM @UserSite
							WHERE UserId = u.UserId
							)
						) -- No site
					OR (
						@SiteId > 0
						AND us.SiteId = @SiteId
						) -- Specific site
					OR @SiteId < 0 -- All sites
				)
	END

	-- Get data
	DECLARE @UserSiteStatus TABLE (
		UserId INT
		,SiteId TINYINT
		,RowNum INT
		)

	IF @Status IN (0, 3)
	BEGIN
		INSERT INTO @UserSiteStatus
		SELECT TOP (@PageSize) tmp.UserId
			,tmp.SiteId
			,tmp.RowNum
		FROM (
			SELECT DISTINCT u.UserId
				,us.SiteId
				,ROW_NUMBER() OVER (
					ORDER BY us.IsActive DESC
						,us.[Level] DESC
						,u.username ASC
					) AS RowNum
			FROM @Users AS u
			LEFT JOIN @UserSite AS us ON u.UserId = us.UserId
			WHERE (
					@SiteId = 0
					AND NOT EXISTS (
						SELECT 1
						FROM @UserSite
						WHERE UserId = u.UserId
						)
					) -- No site
				OR (
					@SiteId > 0
					AND us.SiteId = @SiteId
					) -- Specific site
				OR @SiteId < 0 -- All sites
			) AS tmp
		WHERE tmp.RowNum BETWEEN @FirstRec AND @LastRec
		ORDER BY tmp.RowNum
	END
	ELSE IF @Status IN (1, 2)
	BEGIN
		INSERT INTO @UserSiteStatus
		SELECT TOP (@PageSize) tmp.UserId
			,tmp.SiteId
			,tmp.RowNum
		FROM (
			SELECT DISTINCT u.UserId
				,us.SiteId
				,ROW_NUMBER() OVER (
					ORDER BY us.IsActive DESC
						,us.[Level] DESC
						,u.username ASC
					) AS RowNum
			FROM @Users AS u
			INNER JOIN @UserSite AS us ON u.UserId = us.UserId
			WHERE (
					@SiteId = 0
					AND NOT EXISTS (
						SELECT 1
						FROM @UserSite
						WHERE UserId = u.UserId
						)
					) -- No site
				OR (
					@SiteId > 0
					AND us.SiteId = @SiteId
					) -- Specific site
				OR @SiteId < 0 -- All sites
			) AS tmp
		WHERE tmp.RowNum BETWEEN @FirstRec AND @LastRec
		ORDER BY tmp.RowNum
	END

	SELECT u.UserId
		,u.IsLicenseeUser
		,u.SourceSiteId
		,u.username
		,g.GroupId
		,g.GroupName
		,us.SiteId
		,s.SiteName
		,us.[Level]
		,CASE 
			WHEN us.IsActive = 1
				THEN 1
			WHEN us.IsActive = 0
				THEN 2
			
			END AS [Status]
		,u.FirstName
		,u.LastName
		,u.Email
		,u.DefaultBaseCurrencyId
		,e.Code AS DefaultBaseCurrencyCode
		,u.userpwd
		,us.LastLoginDate
		,u.CreatedDate
		,u.ModifiedDate
		,c1.UserId AS CreatorId
		,c1.username AS CreatorUsername
		,c2.UserId AS ModifierId
		,c2.username AS ModifierUsername
		,us.LastLoginDate AS LastLoginDateUserSite
		,us.CreatedBy AS CreatorIdUserSite
		,c3.username AS CreatorUsernameUserSite
		,us.ModifiedBy AS ModifierIdUserSite
		,c4.username AS ModifierUsernameUserSite
		,us.CreatedDate AS CreatedDateUserSite
		,us.ModifiedDate AS ModifiedDateUserSite
	FROM @UserSiteStatus AS tmp
		INNER JOIN dbo.N88_Users AS u WITH (NOLOCK) ON tmp.UserId = u.UserId
		LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN dbo.N88_Users AS c1 WITH (NOLOCK) ON u.CreatedBy = c1.UserId
		LEFT JOIN dbo.N88_Users AS c2 WITH (NOLOCK) ON u.ModifiedBy = c2.UserId
		LEFT JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON tmp.UserId = us.UserId
			AND tmp.SiteId = us.SiteId
		LEFT JOIN dbo.N88_Users AS c3 WITH (NOLOCK) ON us.CreatedBy = c3.UserId
		LEFT JOIN dbo.N88_Users AS c4 WITH (NOLOCK) ON us.ModifiedBy = c4.UserId
		LEFT JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON tmp.SiteId = s.SiteId
		LEFT JOIN CustDB.dbo.exchange AS e WITH (NOLOCK) ON e.ExchangeId = u.DefaultBaseCurrencyId
	ORDER BY tmp.RowNum
END
GO
