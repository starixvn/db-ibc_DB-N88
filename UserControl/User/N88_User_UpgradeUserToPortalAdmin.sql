/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_UpgradeUserToPortalAdmin]
	@Username	VARCHAR(30) = null
AS

/*
	Created: 20200314@Kos
	Task: Upgrade user to Portal Admin (DBA use only)
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @custId	INT
	
	-- Get custId (UserId) from username
	SELECT @custId = cu.UserId
	FROM dbo.N88_Users AS cu WITH (NOLOCK)
	WHERE cu.username = @username
	
	-- Add user to N88 Admin if not exist
	IF NOT EXISTS (	SELECT 1
					FROM dbo.N88_Users AS u WITH (NOLOCK)
					WHERE u.UserId = @custId)
	BEGIN
		INSERT INTO dbo.N88_Users(UserId, GroupId, LastLoginDate, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
		VALUES(@custId, 0, NULL, NULL, GETDATE(), NULL, GETDATE())
	END
	ELSE
	BEGIN
		UPDATE dbo.N88_Users WITH (ROWLOCK, UPDLOCK)
		SET GroupId = 0 
		WHERE UserId = @custId
	END

	-- Update user to Portal Admin in N88 Admin
	IF NOT EXISTS (	SELECT 1 
					FROM dbo.N88_UserSite AS us WITH (NOLOCK)
					WHERE us.SiteId = 1 AND us.UserId = @custId)
		BEGIN
			INSERT INTO dbo.N88_UserSite(UserId, SiteId, Level, IsActive, LastLoginDate, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
			VALUES(@custId, 1, 100, 1, NULL, NULL, GETDATE(), NULL, GETDATE())
		END
	ELSE
		BEGIN
			UPDATE dbo.N88_UserSite WITH (ROWLOCK, UPDLOCK)
			SET Level = 100
			WHERE UserId = @custId AND SiteId = 1
		END

	-- Update user to Site Admin in all sites
	UPDATE dbo.N88_UserSite WITH (ROWLOCK, UPDLOCK)
	SET Level = 50
	WHERE UserId = @custId AND SiteId <> 1

	INSERT INTO dbo.N88_UserSite(UserId, SiteId, Level, IsActive, LastLoginDate, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
	SELECT @custId, s.SiteId, 50, 1, NULL, NULL, GETDATE(), NULL, GETDATE()
	FROM dbo.N88_Sites AS s WITH (NOLOCK)
	WHERE s.SiteId NOT IN (
							SELECT us.SiteId 
							FROM dbo.N88_UserSite AS us WITH (NOLOCK) 
							WHERE us.UserId = @custId
						)

	UPDATE dbo.N88_UserSite WITH (ROWLOCK, UPDLOCK)
	SET IsActive = 1
	WHERE UserId = @custId AND IsActive = 0

	-- Assign function of all site to user
	INSERT INTO dbo.N88_UserFunction(UserId, FunctionId, SiteId, Policy, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
	SELECT @custId, f.FunctionId, f.SiteId, 0, NULL, GETDATE(), NULL, GETDATE()
	FROM dbo.N88_Functions AS f WITH (NOLOCK)
	WHERE f.FunctionId NOT IN (
								SELECT uf.FunctionId 
								FROM dbo.N88_UserFunction AS uf WITH (NOLOCK) 
								WHERE uf.UserId = @custId
							)	

	-- Grant full permission for user in all site
	UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
	SET Policy = 1
	WHERE
		UserId = @custId
		AND	FunctionId IN (
							SELECT f.FunctionId
							FROM  dbo.N88_Functions AS f 
							WHERE f.CRUD = 0
						)

	UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
	SET Policy = 2
	WHERE
		UserId = @custId
		AND FunctionId IN (
							SELECT f.FunctionId
							FROM  dbo.N88_Functions AS f 
							WHERE f.CRUD = 1
		)
END
GO
