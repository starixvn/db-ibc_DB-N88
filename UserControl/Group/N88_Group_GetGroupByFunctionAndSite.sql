/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_GetGroupByFunctionAndSite]
	@FunctionId	SMALLINT, 
	@SiteId		TINYINT = 0
AS

/*
	Created: 20200314@Kos
	Task: Get all group in a site and have permission in function
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON;

	SELECT gf.Policy,
		g.GroupId,
		g.GroupName,
		g.Description,
		g.IsActive,
		g.CreatedDate,
		g.ModifiedDate,
		g.CreatedBy AS CreatorId,
		ci.Username AS CreatorUsername,
		g.ModifiedBy AS ModifierId,
		ci1.Username AS ModifierUsername,
		gf.CreatedBy AS CreatorIdGroupFunction,
		ci3.username AS CreatorUsernameGroupFunction,
		gf.ModifiedBy AS ModifierIdGroupFunction,
		ci4.username AS ModifierUsernameGroupFunction,
		gf.CreatedDate AS CreatedDateGroupFunction,
		gf.ModifiedDate AS ModifiedDateGroupFunction
	FROM dbo.N88_Groups AS g WITH(NOLOCK)
		LEFT JOIN dbo.N88_Users AS ci WITH(NOLOCK) ON g.CreatedBy = ci.UserId
		LEFT JOIN dbo.N88_Users AS ci1 WITH(NOLOCK) ON g.ModifiedBy = ci1.UserId
		INNER JOIN dbo.N88_GroupFunction AS gf WITH(NOLOCK) ON g.GroupId = gf.GroupId
		LEFT JOIN dbo.N88_Users AS ci3 WITH(NOLOCK) ON gf.CreatedBy = ci3.UserId
		LEFT JOIN dbo.N88_Users AS ci4 WITH(NOLOCK) ON gf.ModifiedBy = ci4.UserId
	WHERE gf.FunctionId = @FunctionId
		AND gf.Policy > 0;
END
GO
