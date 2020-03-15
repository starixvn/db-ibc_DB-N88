/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_GetById]
	@UserId INT
AS

/*
	Created: 20200314@Kos
	Task: Get user by user ID
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		u.UserId
		,u.firstname
		,u.lastname
		,u.email
		,u.username
		,u.userpwd
		,u.IsLicenseeUser
		,u.SourceSiteId
		,u.LastLoginDate
		,u.CreatedDate
		,u.ModifiedDate
		,g.GroupId
		,g.GroupName
		,ci1.UserId		AS CreatorId
		,ci1.username	AS CreatorUsername
		,ci2.UserId		AS ModifierId
		,ci2.username	AS ModifierUsername
	FROM
		dbo.N88_Users AS u WITH (NOLOCK)
		LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN dbo.N88_Users AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.UserId
		LEFT JOIN dbo.N88_Users AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.UserId
	WHERE u.UserId = @UserId
END

GO
