/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_GetById]
	@GroupId SMALLINT
AS

/*
	Created: 20200314@Kos
	Task: Get group info by ID
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT g.GroupId
		,g.GroupName
		,g.Description
		,g.IsActive
		,g.CreatedDate
		,g.ModifiedDate
		,g.CreatedBy	AS CreatorId
		,ci.Username	AS CreatorUsername
		,g.ModifiedBy	AS ModifierId
		,ci1.Username	AS ModifierUsername
	FROM
		dbo.N88_Groups AS g WITH (NOLOCK)
		LEFT JOIN dbo.N88_Users AS ci WITH (NOLOCK) ON g.CreatedBy = ci.UserId
		LEFT JOIN dbo.N88_Users AS ci1 WITH (NOLOCK) ON g.ModifiedBy = ci1.UserId
	WHERE g.GroupId = @GroupId
END
GO
