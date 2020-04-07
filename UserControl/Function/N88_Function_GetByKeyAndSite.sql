/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_GetByKeyAndSite]
	@FunctionKey	NVARCHAR(50),
	@SiteId			TINYINT
AS

/*
	Created: 20200314@Kos
	Task: Get function by function key and site
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		@FunctionKey : is unique in each site
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		f.FunctionId
		,f.FunctionName
		,f.FunctionKey
		,f.[Description]
		,f.CRUD
		,f.DisplayOrder
		,f.IsActive
		,f.CreatedDate
		,f.ModifiedDate
		,f.Environment
		,f.ParentId -- parent information
		,f.ParentName
		,f.SiteId -- site information
		,s.SiteName
		,f.CreatedBy AS CreatorId -- creator information
		,cb.username AS CreatorUsername
		,f.ModifiedBy AS ModifierId -- modifier information
		,mb.username AS ModifierUsername
	FROM dbo.N88_Functions AS f WITH (NOLOCK)
		INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		LEFT JOIN dbo.N88_Users AS cb WITH (NOLOCK) ON f.CreatedBy = cb.UserId
		LEFT JOIN dbo.N88_Users AS mb WITH (NOLOCK) ON f.ModifiedBy = mb.UserId
	WHERE f.FunctionKey = @FunctionKey AND f.SiteId = @SiteId
END
GO
