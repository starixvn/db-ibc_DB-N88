/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetUserSiteLevel]
	@UserId	INT,
	@SiteId	TINYINT
AS

/*
	Created: 20200314@Kos
	Task: Get user site level
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		us.Level,
		us.IsActive
	FROM dbo.N88_UserSite AS us WITH (NOLOCK)
	WHERE us.UserId = @UserId AND us.SiteId = @SiteId
END
GO
