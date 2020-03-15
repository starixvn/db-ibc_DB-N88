/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_GetByKey]
	@SiteKey VARCHAR(50)
AS

/*
	Created: 20200314@Kos
	Task: Get site info by site key
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
	WHERE SiteKey = @SiteKey
END
GO
