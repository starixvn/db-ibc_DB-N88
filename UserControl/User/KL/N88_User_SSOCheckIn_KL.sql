/*<info serverAlias="DBN88POL-N88_UserControl" executers="wsv_nap,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_SSOCheckIn_KL]
	@UserId				INT
	,@SiteId			TINYINT
	,@CheckOnUserId		INT
	,@NetSessionId		VARCHAR(30)
	,@OnUserId			INT					OUTPUT
	,@IP				VARCHAR(50)	= ''
	,@LoginDate			DATETIME	= NULL
AS

/*
	Created: 20200314@Kos
	Task: User SSO check in
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	-- check for onuser is kicked out
	IF EXISTS (	SELECT TOP(1) * 
				FROM dbo.N88_OnUser WITH (NOLOCK)
				WHERE Id = @CheckOnUserId AND IsKickedOut = 0 )
	BEGIN
		--UPDATE dbo.N88_OnUser WITH (ROWLOCK, UPDLOCK)
		--SET IsKickedOut = 1 
		--WHERE UserId = @UserId
		--AND SiteId = @SiteId

		-- Insert new onuser
		--INSERT INTO dbo.N88_OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
		--VALUES (@UserId, @SiteId, 0, @IP, @NetSessionID)
		
		SET @OnUserId = 1--SCOPE_IDENTITY()

		-- Update last login date
		--IF @SiteId = 0	-- N88 Hub
		--BEGIN
		--	UPDATE dbo.N88_Users WITH (ROWLOCK, UPDLOCK)
		--	SET LastLoginDate = @LoginDate
		--	WHERE UserId = @UserId
		--END
		--ELSE
		--BEGIN
		--	UPDATE dbo.N88_UserSite WITH (ROWLOCK, UPDLOCK)
		--	SET LastLoginDate = @LoginDate
		--	WHERE SiteId = @SiteId AND UserId=@UserId
		--END
	END
END

GO
