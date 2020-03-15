/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetByUser]
	@UserId			INT,
	@Environment	VARCHAR(10) = 'UAT', --There are two values : UAT and LIVE
	@IsActive		BIT			= NULL
AS

/*
	Created: 20200314@Kos
	Task: Get site by user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT us.Level
		,us.IsActive
		,us.ExpiredDate
		,us.IsNeverExpired
		,us.LastLoginDate
		,us.CreatedDate
		,us.ModifiedDate
		,us.SiteId
		,s.SiteName
		,ci.UserId		AS CreatorId
		,ci.username	AS CreatorUsername
		,ci1.UserId		AS ModifierId
		,ci1.username ModifierUsername
	FROM
		dbo.N88_UserSite AS us WITH (NOLOCK)
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON us.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS ci WITH (NOLOCK) ON us.CreatedBy = ci.UserId
		LEFT JOIN dbo.N88_Users AS ci1 WITH (NOLOCK) ON us.ModifiedBy = ci1.UserId
	WHERE
		us.UserId = @UserId
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND s.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND us.IsActive = @IsActive))
		AND s.IsActive = 1
END
GO
