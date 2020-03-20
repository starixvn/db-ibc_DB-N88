/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_MenuItem_GetAll] @Environment VARCHAR(10) = 'UAT' -- 'UAT', 'LIVE'
	,@IsActive BIT = NULL
AS
/*
	Created: 20200314@Kos
	Task: Get all menu items
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20200319@Tim: get MenuItemKey [RedmineId: #129873]
*/
BEGIN
	SET NOCOUNT ON

	SELECT m.MenuItemId
		,m.FunctionId
		,f.FunctionName
		,m.SiteId
		,s.SiteName
		,m.MenuItemName
		,m.MenuItemKey
		,m.[Description]
		,m.ParentId
		,m.ParentName
		,m.Policy
		,m.URL
		,m.DisplayOrder
		,m.IsActive
		,m.CreatedBy AS CreatorId
		,cb.username AS CreatorUsername
		,m.CreatedDate
		,m.ModifiedBy AS ModifierId
		,mb.username AS ModifierUsername
		,m.ModifiedDate
		,m.Environment
	FROM dbo.N88_MenuItems AS m WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON m.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON m.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON m.ModifiedBy = mb.UserId
	WHERE (
			@Environment = 'UAT'
			OR (
				@Environment != 'UAT'
				AND m.Environment = @Environment
				)
			)
		AND (
			@IsActive IS NULL
			OR (
				@IsActive IS NOT NULL
				AND m.IsActive = @IsActive
				)
			)
END
GO
