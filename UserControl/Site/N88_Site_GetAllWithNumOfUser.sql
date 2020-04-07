/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetAllWithNumOfUser]
	@Environment	VARCHAR(10)	= 'UAT', -- 'UAT, 'LIVE'
	@IsActive		BIT			= NULL
AS

/*
	Created: 20200314@Kos
	Task: Get all sites with their number of users
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		 s.SiteId
		,s.SiteName
		,s.Description
		,s.IsActive
		,s.IsLicenseeSite
		,s.Environment
		,COUNT(us.UserId) AS NumOfUser
	FROM 
		dbo.N88_Sites AS s WITH (NOLOCK)
		LEFT JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON s.SiteId = us.SiteId
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND s.Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND s.IsActive = @IsActive))
	GROUP BY 
		s.SiteId
		,s.SiteName
		,s.IsLicenseeSite
		,s.Description
		,s.IsActive
		,s.Environment
END
GO
