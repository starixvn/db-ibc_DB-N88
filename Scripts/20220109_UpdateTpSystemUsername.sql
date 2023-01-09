/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20230109@Malcolm
	Task: Update TpSystemUserName [RedmineId: 182738]
	DB: DBN88/bodb_N88
*/

USE bodb_N88
GO

UPDATE c WITH(ROWLOCK, UPDLOCK)
	SET c.TpSystemUserName = ct.username
FROM Customer c 
INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON 'N88$Nova88_' + CONVERT(VARCHAR(20), c.CustId) = ct.Username2
WHERE c.SiteId = 1 AND ISNULL(c.TpSystemUserName, '') = '' 

UPDATE c WITH(ROWLOCK, UPDLOCK)
	SET c.TpSystemUserName = ct.username
FROM Customer c 
INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON 'N8G$Goal123_' + CONVERT(VARCHAR(20), c.CustId) = ct.Username2
WHERE c.SiteId = 2 AND ISNULL(c.TpSystemUserName, '') = '' 

UPDATE c WITH(ROWLOCK, UPDLOCK)
	SET c.TpSystemUserName = ct.username
FROM Customer c 
INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON 'N8B$Bwing_' + CONVERT(VARCHAR(20), c.CustId) = ct.Username2
WHERE c.SiteId = 3 AND ISNULL(c.TpSystemUserName, '') = '' 
