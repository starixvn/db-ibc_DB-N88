/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetById]
	@SiteId TINYINT
AS

/*
	Created: 20200314@Kos
	Task: Get site info
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		SiteId,
		SiteName,
		SiteKey,
		SecretAccessKey,
		Description,
		IsActive,
		Environment
	FROM dbo.N88_Sites WITH (NOLOCK)
	WHERE SiteId = @SiteId
END
GO
