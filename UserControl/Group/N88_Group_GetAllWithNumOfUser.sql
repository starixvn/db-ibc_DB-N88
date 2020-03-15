/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_GetAllWithNumOfUser]
	@GroupName			VARCHAR(50)	= NULL,
	@Environment		VARCHAR(10)	= 'UAT',
	@IsActive			BIT			= NULL,
	@IsLicenseeGroup	BIT			= 0,
	@SiteId				TINYINT		= NULL
AS

/*
	Created: 20200314@Kos
	Task: Get all group with number of user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT g.GroupId
		,g.GroupName
		,g.Description
		,g.IsActive
		,g.CreatedDate
		,g.ModifiedDate
		,(
			SELECT COUNT(TEMP.UserId)
			FROM (
				SELECT DISTINCT u.UserId
				FROM dbo.N88_Users AS u WITH (NOLOCK)
					LEFT JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON u.UserId = us.UserId
					LEFT JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON us.SiteId = s.SiteId
				WHERE ( @Environment = 'UAT' OR s.Environment = @Environment )
					AND u.GroupId = g.GroupId

				UNION

				SELECT DISTINCT u.UserId
				FROM dbo.N88_Users AS u WITH (NOLOCK)
				WHERE u.UserId NOT IN (
						SELECT DISTINCT UserId
						FROM dbo.N88_UserSite WITH (NOLOCK)
						)
					AND u.GroupId = g.GroupId
				) AS TEMP
			) AS NumOfUser
		,g.CreatedBy AS CreatorId
		,ci.Username AS CreatorUsername
		,g.ModifiedBy AS ModifierId
		,ci1.Username AS ModifierUsername
	FROM dbo.N88_Groups AS g WITH (NOLOCK)
		LEFT JOIN dbo.N88_Users AS ci WITH (NOLOCK) ON g.CreatedBy = ci.UserId
		LEFT JOIN dbo.N88_Users AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.UserId
	WHERE (@IsActive IS NULL OR g.IsActive = @IsActive )
		AND (@GroupName IS NULL OR g.GroupName LIKE '%' + @GroupName + '%')
		AND (( @isLicenseeGroup = 1 AND ISNULL(g.SourceSiteId,0) = ISNULL(@SiteId, 0))
			OR (@isLicenseeGroup = 0 AND ISNULL(g.IsLicenseeGroup, 0) = @isLicenseeGroup ))
END
GO
