/*<info serverAlias="DBN88POL-N88_UserControl" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_GetByUserAndFunctionKeyIncludeGroup]
	@UserId			INT,
	@FunctionKey	NVARCHAR(50),
	@Environment	VARCHAR(10)		= 'UAT'	-- 'UAT', 'LIVE'
AS

/*
	Created: 20200314@Kos
	Task: Get functions by user and function key include group permission
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20250204@Hogan: Get ParentKey [RedmineID: #211934]
*/

BEGIN
	SET NOCOUNT ON

	SELECT 
		uf.FunctionId,
		f.FunctionName,
		f.FunctionKey,
		uf.Policy,
		f.Description,
		f.CRUD,
		f.DisplayOrder,
		f.IsActive,
		f.Environment,
		f.ParentId,			-- parent information
		pf.FunctionKey AS ParentKey,
		f.ParentName,
		f.SiteId,			-- site information
		s.SiteName
	FROM 
		(
			-- Get a highes policy where the same functions
			SELECT
				CASE
					WHEN ISNULL(A.FunctionID, 0) = 0 THEN B.FunctionID 
					ELSE A.FunctionID 
				END AS FunctionID,
				CASE 
					WHEN ISNULL(A.Policy, 0) < ISNULL(B.Policy, 0) THEN ISNULL(B.Policy, 0) 
					ELSE ISNULL(A.Policy, 0)
				END AS Policy
			FROM 
			(
				-- Get function permission of user where equal function key
				SELECT uf.FunctionId, uf.Policy
				FROM 
					dbo.N88_UserFunction AS uf WITH (NOLOCK)
					INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
				WHERE
					uf.UserId = @UserId 
					AND f.FunctionKey = @FunctionKey
					AND f.IsActive = 1
			) AS A
			FULL OUTER JOIN
			(
				-- Get function permission of group which user belong to
				SELECT gf.FunctionId, gf.Policy
				FROM 
					dbo.N88_GroupFunction AS gf WITH (NOLOCK)
					INNER JOIN dbo.N88_Users AS u WITH (NOLOCK) ON u.GroupId = gf.GroupId
					INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
				WHERE 
					u.UserId = @UserId
					AND f.FunctionKey = @FunctionKey
					AND f.IsActive = 1
			) AS B
			ON A.FunctionID = B.FunctionID
		) AS uf
		LEFT JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
		LEFT JOIN dbo.N88_Functions AS pf WITH (NOLOCK) ON f.ParentId IS NOT NULL AND f.ParentId <> 0 AND f.ParentId = pf.FunctionId
		LEFT JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
	WHERE
		(@Environment = 'UAT' OR (@Environment != 'UAT' AND f.Environment = @Environment))
		AND f.IsActive = 1 
		AND s.IsActive = 1
END
GO
