/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_SearchExcludeFunction]
	@Username		NVARCHAR(50)
	,@GroupId		SMALLINT
	,@SiteId		TINYINT
	,@FunctionId	SMALLINT
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT	= 0	OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Search user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20220615@Kos: Fix issue [RedmineID: #174035]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec INT, @LastRec INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	-- gets total rows
	SET @TotalRows = (
		SELECT DISTINCT COUNT(1)
		FROM dbo.N88_Users AS u WITH (NOLOCK)
			LEFT JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
		WHERE
			((@SiteId = 0 AND u.UserId NOT IN (SELECT DISTINCT UserId FROM dbo.N88_UserSite WITH (NOLOCK))) OR (@SiteId != 0 AND us.SiteId = @SiteId))
			AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
			AND u.username LIKE '%' + @Username + '%'
			AND u.UserId NOT IN (
				SELECT UserId 
				FROM dbo.N88_UserFunction WITH (NOLOCK) 
				WHERE FunctionId = @FunctionId AND us.SiteId = @SiteId AND Policy > 0
			)
	)

	-- gets data
	SELECT TOP (@PageSize) *
	FROM (
			SELECT DISTINCT
				us.[Level]
				, u.UserId
				, u.firstname
				, u.lastname
				, u.email
				, u.IsLicenseeUser
				, u.SourceSiteId
				, u.username
				, u.userpwd
				, us.LastLoginDate
				, u.CreatedDate
				, u.ModifiedDate
				, g.GroupId
				, g.GroupName
				, c1.UserId AS CreatorId
				, c1.username AS CreatorUsername
				, c2.UserId AS ModifierId
				, c2.username AS ModifierUsername
				, us.IsActive
				, us.LastLoginDate AS LastLoginDateUserSite
				, us.CreatedBy AS CreatorIdUserSite
				, c3.username AS CreatorUsernameUserSite
				, us.ModifiedBy AS ModifierIdUserSite
				, c4.username AS ModifierUsernameUserSite
				, us.CreatedDate AS CreatedDateUserSite
				, us.ModifiedDate AS ModifiedDateUserSite
				, us.SiteId
				, s.SiteName
				, ROW_NUMBER() OVER (ORDER BY us.IsActive DESC, us.[Level] DESC) AS num
			FROM
				dbo.N88_Users AS u WITH (NOLOCK)
				LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK)
					ON g.GroupId = u.GroupId
				LEFT JOIN dbo.N88_Users AS c1 WITH (NOLOCK)
					ON u.CreatedBy = c1.UserId
				LEFT JOIN dbo.N88_Users AS c2 WITH (NOLOCK)
					ON u.ModifiedBy = c2.UserId
				LEFT JOIN dbo.N88_UserSite AS us WITH (NOLOCK)
					ON u.UserId = us.UserId
				LEFT JOIN dbo.N88_Users AS c3 WITH (NOLOCK)
					ON us.CreatedBy = c3.UserId
				LEFT JOIN dbo.N88_Users AS c4 WITH (NOLOCK)
					ON us.ModifiedBy = c4.UserId
				LEFT JOIN dbo.N88_Sites AS s WITH (NOLOCK)
					ON us.SiteId = s.SiteId
			WHERE
				((@SiteId = 0 AND u.UserId NOT IN (SELECT DISTINCT UserId FROM dbo.N88_UserSite WITH (NOLOCK))) OR (@SiteId != 0 AND us.SiteId = @SiteId))
				AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
				AND u.username LIKE '%' + @Username + '%'
				AND u.UserId NOT IN (
					SELECT UserId FROM dbo.N88_UserFunction WITH (NOLOCK) 
					WHERE FunctionId = @FunctionId AND us.SiteId = @SiteId AND Policy > 0)
		) AS Temp
	WHERE Temp.num BETWEEN @FirstRec AND @LastRec
	ORDER BY Temp.num ASC
END
GO
