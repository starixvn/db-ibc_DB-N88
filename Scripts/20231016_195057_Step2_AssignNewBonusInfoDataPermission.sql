/*<info serverAlias="DBN88POL-N88_UserControl"></info>*/

/*
	Created: 20231016@HOgan
	DB: DBN88POL.N88_UserControl
	Task: Assign new Bonus Type function to current users [RedmineID: #195057]
*/

USE N88_UserControl
GO

INSERT INTO dbo.N88_UserFunction (UserId, FunctionId, SiteId, Policy, CreatedDate, ModifiedDate)
SELECT BonusInfoUser.UserId, BonusTypeFunction.FunctionId, BonusInfoUser.SiteId, 1 AS Policy, GETDATE() AS CreatedDate, GETDATE() AS ModifiedDate
FROM(
	SELECT uf.UserId, uf.SiteId, s.SiteName
	FROM dbo.N88_UserFunction AS uf  WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
		INNER JOIN N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
	WHERE f.FunctionKey = 'BonusInfoReport') AS BonusInfoUser
	INNER JOIN (
	SELECT f.FunctionId, f.SiteId, f.FunctionKey, f.ParentName
	FROM dbo.N88_Functions AS f WITH (NOLOCK)
		INNER JOIN dbo.N88_Functions AS pf WITH (NOLOCK) ON f.ParentId = pf.FunctionId
	WHERE pf.FunctionKey IN ('BonusInfoReport', 'BonusReport_BonusType')
	) AS BonusTypeFunction ON BonusInfoUser.SiteId = BonusTypeFunction.SiteId
WHERE BonusInfoUser.SiteName IN ('N88 Admin', 'N8B Admin', 'N8G Admin')
	AND NOT EXISTS(SELECT 1 FROM dbo.N88_UserFunction WITH (NOLOCK) WHERE UserId = BonusInfoUser.UserId AND FunctionId = BonusTypeFunction.FunctionId)

GO