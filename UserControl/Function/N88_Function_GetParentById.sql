/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_GetParentById]
	@FunctionId SMALLINT
AS

/*
	Created: 20200314@Kos
	Task: Get function info by parent
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	-- Get SiteId of FunctionId
	DECLARE @SiteId TINYINT

	SELECT @SiteId = SiteId
	FROM dbo.N88_Functions WITH (NOLOCK)
	WHERE FunctionId = @FunctionId

	-- Get all function is parent of FunctionId
	;WITH FunctionChild
	AS (
		SELECT FunctionId
		FROM dbo.N88_Functions WITH (NOLOCK)
		WHERE FunctionId = @FunctionId
		
		UNION ALL
		SELECT f.FunctionId
		FROM dbo.N88_Functions AS f WITH (NOLOCK)
			INNER JOIN FunctionChild fc ON f.ParentId = fc.FunctionId
		)

	-- Select information of list function can be parent of functionId
	SELECT f.FunctionId
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
	WHERE f.FunctionId NOT IN ( SELECT FunctionId FROM FunctionChild)
		AND f.SiteId = @SiteId
END
GO
