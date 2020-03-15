/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetSiteURLBySiteId]
	@SiteId			TINYINT,
	@Environment	VARCHAR(10) = ''
AS

/*
	Created: 20200314@Kos
	Task: Get site URL by site ID
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT su.SiteURLId
		 , su.URL
		 , su.Environment
		 , su.IsActive
		 , su.IsDefault
		 , s.SiteId			AS Id
		 , s.SiteName		AS [Name]
		 , s.Description
		 , s.IsActive		AS SiteIsActive
		 , s.Environment	AS SiteEnvironment
	FROM
		dbo.N88_SiteURL AS su WITH (NOLOCK)
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON su.SiteId = s.SiteId
	WHERE
		su.SiteId = @SiteId
		AND (LEN(@Environment) = 0 OR  su.Environment = @Environment)
END
GO
