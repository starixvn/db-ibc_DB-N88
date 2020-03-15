/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_GetByUser]
	@UserId			INT,
	@Environment	VARCHAR(10) = 'UAT'
AS

/*
	Created: 20200314@Kos
	Task: Get functions by user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
		- @Environment: UAT or LIVE
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		uf.FunctionId
		,f.FunctionName
		,f.FunctionKey
		,f.CRUD
		,f.DisplayOrder
		,f.IsActive
		,f.Environment
		,uf.Policy
		,uf.CreatedDate
		,uf.ModifiedDate
		,f.[Description]
		,f.ParentId
		,f.ParentName
		,f.SiteId
		,s.SiteName
		,uf.CreatedBy AS CreatorId --creator
		,cb.username AS CreatorUsername
		,uf.ModifiedBy AS ModifierId --modifier
		,mb.username AS ModifierUsername
	FROM dbo.N88_UserFunction AS uf WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON uf.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON uf.ModifiedBy = mb.UserId
	WHERE uf.UserId = @UserId
		AND f.IsActive = 1
		AND s.IsActive = 1
		AND (@Environment = 'UAT'
			OR (@Environment != 'UAT' AND f.Environment = @Environment))
END
GO
