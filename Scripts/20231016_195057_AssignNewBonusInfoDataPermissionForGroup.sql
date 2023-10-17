/*<info serverAlias="DBN88POL-N88_UserControl"></info>*/

/*
	Created: 20231017@HOgan
	DB: DBN88POL.N88_UserControl
	Task: Assign new Bonus Type function to current groups [RedmineID: #195057]
*/

USE N88_UserControl
GO

INSERT INTO dbo.N88_GroupFunction(GroupId, FunctionId, SiteId, Policy, CreatedDate, ModifiedDate)
SELECT BonusInfoGroup.GroupId, BonusTypeFunction.FunctionId, BonusInfoGroup.SiteId, 1 AS Policy, GETDATE() AS CreatedDate, GETDATE() AS ModifiedDate
FROM(
	SELECT gf.GroupId, gf.SiteId, s.SiteName
	FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
		INNER JOIN N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
	WHERE f.FunctionKey = 'BonusInfoReport') AS BonusInfoGroup
	INNER JOIN (
	SELECT f.FunctionId, f.SiteId, f.FunctionKey, f.ParentName
	FROM dbo.N88_Functions AS f WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS pf WITH (NOLOCK) ON f.ParentId = pf.FunctionId
	WHERE pf.FunctionKey IN ('BonusInfoReport', 'BonusReport_BonusType')
	) AS BonusTypeFunction ON BonusInfoGroup.SiteId = BonusTypeFunction.SiteId
WHERE BonusInfoGroup.SiteName IN ('N88 Admin', 'N8B Admin', 'N8G Admin')
	AND NOT EXISTS(SELECT 1 FROM dbo.N88_GroupFunction WITH (NOLOCK) WHERE GroupId = BonusInfoGroup.GroupId AND FunctionId = BonusTypeFunction.FunctionId)

GO