/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_GetByGroupAndSite]
	@GroupId	SMALLINT,
	@SiteId		TINYINT,
	@IsActive	BIT		= NULL
AS

/*
	Created: 20200314@Kos
	Task: Get users by group and site
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT
		u.UserId
		,c.firstname
		,c.lastname
		,c.email
		,ci.username
		,c.userpwd
		,u.LastLoginDate
		,u.CreatedDate
		,u.ModifiedDate
		,g.GroupId
		,g.GroupName
		,ci1.UserId		AS CreatorId
		,ci1.username	AS CreatorUsername
		,ci2.UserId		AS ModifierId
		,ci2.username	AS ModifierUsername
	FROM
		dbo.N88_Users AS u WITH (NOLOCK)
		INNER JOIN dbo.N88_Users AS C WITH (NOLOCK) ON u.UserId = c.UserId
		INNER JOIN dbo.N88_Users AS ci WITH (NOLOCK) ON u.UserId = ci.UserId
		LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN dbo.N88_Users AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.UserId
		LEFT JOIN dbo.N88_Users AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.UserId
		LEFT JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
	WHERE
		(@SiteId = 0 OR (@SiteId != 0 AND us.SiteId = @SiteId) )
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND us.IsActive = @IsActive))
		AND (@GroupId = 0 OR (@GroupId != 0 AND u.GroupId = @GroupId))
END
GO
