/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetByType]
	@IsLicenseeSite BIT = 1
	,@IsActive BIT = NULL
AS
/*
	Created: 20200319@Oliver
	Task: Get Site list by type
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200319@Oliver: Created [RedmineID: #130173]
*/
BEGIN
	SET NOCOUNT ON

	SELECT s.SiteId
		  ,s.SiteName
		  ,s.SiteKey
		  ,s.IsActive
		  ,s.IsLicenseeSite
	FROM dbo.N88_Sites s WITH (NOLOCK)
	WHERE s.IsLicenseeSite = @IsLicenseeSite
		AND (
			@IsActive IS NULL
			OR s.IsActive = @IsActive
			)
END
GO
