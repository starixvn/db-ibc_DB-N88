/*<info serverAlias="DBN88POL-N88_UserControl" executers="wsv_nap,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_Logout_KL]
	@OnUserID INT
AS

/*
	Created: 20200314@Kos
	Task: User logout
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @userId	INT

	SET @userId = 0

	SELECT @userId = UserId
	FROM dbo.N88_OnUser WITH (NOLOCK)
	WHERE Id = @OnUserID AND SiteId = 0
	
	--IF @userId <> 0
	--BEGIN
	--	UPDATE dbo.N88_OnUser WITH (ROWLOCK, UPDLOCK)
	--	SET IsKickedOut = 1
	--	WHERE UserId = @UserId AND SiteId <> 0
	--END

	--DELETE FROM dbo.N88_OnUser WHERE Id = @OnUserID
END

GO
