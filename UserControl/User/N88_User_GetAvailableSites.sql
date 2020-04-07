/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_GetAvailableSites]
	@UserId			INT,
	@Environment	VARCHAR(10) = 'UAT', --There are two values : UAT and LIVE
	@IsActive		BIT	= NULL
AS

/*
	Created: 20200314@Kos
	Task: Get available sites for user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		SiteId,
		SiteName,
		Description,
		IsActive,
		Environment
	FROM dbo.N88_Sites WITH (NOLOCK)
	WHERE 
		SiteId NOT IN (SELECT SiteId FROM dbo.N88_UserSite WITH (NOLOCK) WHERE UserId = @userid)
		AND (@Environment = 'UAT' OR Environment = @Environment)
		AND (@IsActive IS NULL OR IsActive = @IsActive)
END
GO
