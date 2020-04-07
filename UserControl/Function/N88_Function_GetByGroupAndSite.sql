/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_GetByGroupAndSite]
	@GroupId		SMALLINT,
	@SiteId			TINYINT,
	@Environment	VARCHAR(10) = 'UAT'
AS

/*
	Created: 20200314@Kos
	Task: Get function by group and site
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
		• @Environment: UAT or LIVE
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		gf.FunctionId
		,f.FunctionName
		,f.FunctionKey
		,gf.Policy
		,gf.CreatedDate
		,gf.ModifiedDate
		,f.[Description]
		,f.CRUD
		,f.DisplayOrder
		,f.IsActive
		,f.Environment
		,f.ParentId -- parent information
		,f.ParentName
		,f.SiteId -- site information
		,s.SiteName
		,gf.CreatedBy AS CreatorId -- creator information
		,cb.username AS CreatorUsername
		,gf.ModifiedBy AS ModifierId -- modifier information
		,mb.username AS ModifierUsername
	FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON gf.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON gf.ModifiedBy = mb.UserId
	WHERE gf.GroupId = @GroupId
		AND s.SiteId = @SiteId
		AND f.IsActive = 1
		AND s.IsActive = 1 -- check with site is active
		AND (@Environment = 'UAT'
			OR (@Environment != 'UAT' AND f.Environment = @Environment))
END
GO
