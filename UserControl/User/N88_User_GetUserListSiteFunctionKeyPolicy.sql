/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_GetUserListSiteFunctionKeyPolicy]
	@UserId			INT,
	@Site			NVARCHAR(MAX)	= '',
	@FunctionKey	NVARCHAR(50)
AS

/*
	Created: 20200314@Kos
	Task: Get user permissions in a list of sites
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON    

	-- Read information from @Site and insert into temp table
	DECLARE @TableSite TABLE(SiteId INT)

	IF @Site != ''
	BEGIN
		DECLARE @DocHandle int

		EXEC sp_xml_preparedocument @DocHandle OUTPUT, @Site

		INSERT INTO @TableSite (SiteId)	
		SELECT Data.SiteId
		FROM OPENXML (@DocHandle, '/ROOT/Site',1) 
		WITH ( SiteId INT) AS Data

		EXEC sp_xml_removedocument @DocHandle    
	END

	-- get data

	SELECT
		CASE
			WHEN ISNULL(A.Policy, 0) < ISNULL(B.Policy, 0) THEN ISNULL(B.Policy, 0)
			ELSE ISNULL(A.Policy, 0)
		END AS Policy, 
		A.SiteId
	FROM
		(
			-- Get function permission of user in a site
			SELECT
				uf.FunctionId,
				uf.Policy,
				f.SiteId
			FROM
				dbo.N88_UserFunction AS uf WITH (NOLOCK)
				INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON uf.FunctionId = f.FunctionId
			WHERE 
				uf.UserId = @UserId 
				AND f.SiteId IN (SELECT SiteId FROM @TableSite )
				AND f.FunctionKey = @FunctionKey
				AND f.IsActive = 1
		) AS A
		FULL OUTER JOIN
		(
			-- Get function permission of group of user in a site
			SELECT 
				gf.FunctionId,
				gf.Policy,
				f.SiteId
			FROM
				dbo.N88_GroupFunction AS gf WITH (NOLOCK)
				INNER JOIN dbo.N88_Users AS u WITH (NOLOCK) ON u.GroupId = gf.GroupId
				INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON gf.FunctionId = f.FunctionId
			WHERE
				u.UserId = @UserId
				AND f.SiteId IN (SELECT SiteId FROM @TableSite )
				AND f.FunctionKey = @FunctionKey
				AND f.IsActive = 1
		) AS B
		ON A.FunctionId = B.FunctionId
END
GO
