/*<info serverAlias="DBN88-bodb_N88" selecters="bodbLicenseeNet" isFunction="1" isNested="1"></info>*/
USE bodb_N88
GO

ALTER FUNCTION [dbo].[N88_f_SignupURL]()
RETURNS TABLE
AS

/*
	Created: 20220214@Percy
	DB: DBN88-bodb_N88
	Task: MPA - Signup URL Group

	Revisions:
		- 20220214@Percy: Initialize function [RedmineID: #164724]
*/

RETURN
	-- N88
	SELECT CONVERT(INT, 1) AS SiteId, CONVERT(TINYINT, 1) AS GroupId, CONVERT(VARCHAR(100), 'AFF') AS GroupName, CONVERT(VARCHAR(100), NULL) AS SignupURL
	UNION ALL SELECT 1, 2, 'Nova88.com', NULL
	UNION ALL SELECT 1, 3, 'Nova88.net', SignupURL
				FROM (VALUES
						('www.nova88.com'), ('www.nova88.net'), ('m.nova88.net')
					) m (SignupURL)
	UNION ALL SELECT 1, 4, 'APP', 'app.n17881788.com'
	UNION ALL SELECT 1, 5, 'Landing Pages', NULL
	UNION ALL SELECT 1, 6, 'None', NULL
	-- N8G
	UNION ALL SELECT 2, 1, 'AFF', NULL
	UNION ALL SELECT 2, 2, 'Bong88/Viva88', NULL
	UNION ALL SELECT 2, 3, 'Goal123.com', SignupURL
				FROM (VALUES
						('www.goal123.com'), ('m.goal123.com'), ('release.goal123.com'), ('mrelease.goal123.com')
						,('www.sutbong123.com'), ('m.sutbong123.com')
						,('www.duongdenkhungthanh.com'), ('m.duongdenkhungthanh.com'), ('https://www.duongdenkhungthanh.com'), ('https://m.duongdenkhungthanh.com')
					) m (SignupURL)
	UNION ALL SELECT 2, 4, 'APP', 'app.goal123.com'
	UNION ALL SELECT 2, 5, 'Landing Pages', NULL
	UNION ALL SELECT 2, 6, 'None', NULL
	-- N8B
	UNION ALL SELECT 3, 1, 'AFF', NULL
	UNION ALL SELECT 3, 2, 'Bong88/Viva88', NULL
	UNION ALL SELECT 3, 3, 'Bwing.com', SignupURL
				FROM (VALUES
						('www.bwing.com'), ('m.bwing.com'), ('release.bwing.com'), ('mrelease.bwing.com')
						,('www.bwinghotevent.club'), ('m.bwinghotevent.club'), ('https://www.bwinghotevent.club')
						,('www.bomtanhoitu.live'), ('m.bomtanhoitu.live'), ('https://www.bomtanhoitu.live')
						,('www.bwing01.com'), ('www.bwing02.com'), ('www.bwing03.com'), ('www.bwing04.com'), ('www.bwing05.com')
						,('www.bwing06.com'), ('www.bwing07.com'), ('www.bwing08.com'), ('www.bwing09.com'), ('www.bwing10.com')
						,('www.bwing11.com'), ('www.bwing12.com'), ('www.bwing13.com'), ('www.bwing14.com'), ('www.bwing15.com')
						,('www.bwing16.com'), ('www.bwing17.com'), ('www.bwing18.com'), ('www.bwing19.com'), ('www.bwing20.com')
						,('m.bwing01.com'), ('m.bwing02.com'), ('m.bwing03.com'), ('m.bwing04.com'), ('m.bwing05.com')
						,('m.bwing06.com'), ('m.bwing07.com'), ('m.bwing08.com'), ('m.bwing09.com'), ('m.bwing10.com')
						,('m.bwing11.com'), ('m.bwing12.com'), ('m.bwing13.com'), ('m.bwing14.com'), ('m.bwing15.com')
						,('m.bwing16.com'), ('m.bwing17.com'), ('m.bwing18.com'), ('m.bwing19.com'), ('m.bwing20.com')
					) m (SignupURL)
	UNION ALL SELECT 3, 4, 'APP', 'app.bwing.com'
	UNION ALL SELECT 3, 5, 'Landing Pages', NULL
	UNION ALL SELECT 3, 6, 'None', NULL
GO