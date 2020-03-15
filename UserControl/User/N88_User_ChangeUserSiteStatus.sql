/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_ChangeUserSiteStatus]
	@UserId		INT,
	@SiteId		TINYINT,
	@IsActive	BIT
AS

/*
	Created: 20200314@Kos
	Task: Update user site status
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	UPDATE dbo.N88_UserSite WITH (ROWLOCK, UPDLOCK)
	SET IsActive = @IsActive
	WHERE UserId = @UserId AND SiteId = @SiteId
END
GO
