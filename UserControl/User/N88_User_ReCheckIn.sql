/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_ReCheckIn]
	@OnUserId		INT ,
	@IsKickedOut	BIT = 0 OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: User recheckin
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	IF EXISTS (	SELECT 1 
				FROM dbo.N88_OnUser WITH (NOLOCK)
				WHERE Id = @OnUserId AND IsKickedOut = 1 )
	BEGIN
		SET @IsKickedOut = 1
	END
	ELSE
	BEGIN
		SET @IsKickedOut = 0

		UPDATE dbo.N88_OnUser WITH (ROWLOCK, UPDLOCK)
		SET ReloadTime = GETDATE()
		WHERE Id = @OnUserId

		IF @@ROWCOUNT = 0
			SELECT @IsKickedOut = 1
	END
END

GO
