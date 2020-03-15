/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_MenuItem_GetParentById]
	@MenuItemId		SMALLINT,
	@Environment	VARCHAR(10)	= 'UAT'	-- 'UAT', 'LIVE'
AS

/*
	Created: 20200314@Kos
	Task: Get menu items which are not childs
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	-- SiteId of this menu item
	DECLARE @SiteId INT
	
	-- Get SiteId
	SELECT @SiteId = SiteId
	FROM dbo.N88_MenuItems WITH (NOLOCK)
	WHERE MenuItemId = @MenuItemId

	-- Get all menu item is child of this menu item in site
	;WITH MenuItemChild AS(
		SELECT MenuItemId 
		FROM dbo.N88_MenuItems WITH (NOLOCK)
		WHERE MenuItemId = @MenuItemId

		UNION ALL

		SELECT t.MenuItemId 
		FROM
			dbo.N88_MenuItems AS t WITH (NOLOCK)
			INNER JOIN MenuItemChild AS r ON t.ParentId = r.MenuItemId
	)

	-- Get list menu item not in list menu item child 
	SELECT
		m.MenuItemId,
		m.FunctionId,
		f.FunctionName,
		m.SiteId,
		s.SiteName,
		m.MenuItemName,
		m.Description,
		m.ParentId,
		m.ParentName,
		m.Policy,
		m.URL,
		m.DisplayOrder,
		m.IsActive,
		m.CreatedBy		AS CreatorId,
		cb.username		AS CreatorUsername,
		m.CreatedDate,
		m.ModifiedBy	AS ModifierId,
		mb.username		AS ModifierUsername,
		m.ModifiedDate,
		m.Environment
	FROM
		dbo.N88_MenuItems AS m WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON m.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON m.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON m.ModifiedBy = mb.UserId
	WHERE
		m.MenuItemId NOT IN (SELECT  MenuItemId FROM MenuItemChild) 
		AND m.SiteId = @SiteId
		AND (@Environment = 'UAT' OR (@Environment != 'UAT' AND m.Environment = @Environment))
END
GO
