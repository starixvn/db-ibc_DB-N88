/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetAll]
	@Environment	VARCHAR(10)	= 'UAT',		-- 'UAT, 'LIVE'
	@IsActive		BIT			= NULL
AS

/*
	Created: 20200314@Kos
	Task: Get all sites
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		SiteId,
		SiteName,
		IsLicenseeSite,
		Description,
		IsActive,
		Environment
	FROM dbo.N88_Sites WITH (NOLOCK)
	WHERE 
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND Environment = @Environment))
		AND (@IsActive IS NULL OR (@IsActive IS NOT NULL AND IsActive = @IsActive))
END
GO
