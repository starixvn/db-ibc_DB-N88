/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_MenuItem_GetByKeyAndSite] @MenuItemKey NVARCHAR(50)
	,@SiteId TINYINT
AS
/*
	Created: 20200319@Tim
	Task: get menu item by key and site
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200319@Tim: Created [RedmineID: #129873]
*/
BEGIN
	SET NOCOUNT ON

	SELECT m.MenuItemId
		,m.MenuItemName
		,m.MenuItemKey
		,m.[Description]
		,m.ParentId
		,m.ParentName
		,m.Policy
		,m.URL
		,m.DisplayOrder
		,m.IsActive
		,m.ModifiedDate
		,m.Environment
		,m.FunctionId
		,f.FunctionName
		,m.SiteId
		,s.SiteName
		,m.CreatedBy AS CreatorId
		,cb.username AS CreatorUsername
		,m.CreatedDate
		,m.ModifiedBy AS ModifierId
		,mb.username AS ModifierUsername
	FROM dbo.N88_MenuItems AS m WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON m.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON m.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON m.ModifiedBy = mb.UserId
	WHERE m.MenuItemKey = @MenuItemKey
		AND f.SiteId = @SiteId
END
GO
