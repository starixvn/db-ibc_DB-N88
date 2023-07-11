/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Setting_GetByUser]
	@UserId	INT
AS

/*
	Created: 20230626@Hogan
	Task: Get settings by user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20230626@Hogan: Created [RedmineID: #189299]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		us.SettingKey
		,us.SettingValue
		,us.CreatedDate
		,us.ModifiedDate
		,us.CreatedBy AS CreatorId
		,cb.username AS CreatorUsername
		,us.ModifiedBy AS ModifierId
		,mb.username AS ModifierUsername
	FROM dbo.N88_UserSetting AS us WITH (NOLOCK)
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON us.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON us.ModifiedBy = mb.UserId
	WHERE us.UserId = @UserId
END
GO