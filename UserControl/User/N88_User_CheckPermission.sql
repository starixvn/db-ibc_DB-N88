/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_CheckPermission]
	@UserId			TINYINT,
	@SiteKey		VARCHAR(50),
	@FunctionKey	NVARCHAR(50),
	@Policy			TINYINT			= 2,
	@ErrCode		INT				= 0		OUTPUT,
	@ErrMsg			NVARCHAR(100)	= ''	OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Check user permission
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
		- @UserId: custid of selected user
		- @SiteKey: site key of the site which the function belong to
		- @FunctionKey: function key of the function
		- @Policy: required function permission (1: Read, 2: Host)
		- @ErrCode: Error code (0: Success, 500: Unauthorized)
		- @ErrMsg: Error message
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SiteId			TINYINT		= 0
	DECLARE @FunctionId		SMALLINT	= 0
	DECLARE @UserPolicy		TINYINT		= 0
	DECLARE @GroupPolicy	TINYINT		= 0

	-- Get site ID
	SELECT @SiteId = SiteId
	FROM dbo.N88_Sites WITH (NOLOCK)
	WHERE SiteKey = @SiteKey

	-- Get function ID
	SELECT @FunctionId = CASE
							WHEN IsActive = 1 THEN FunctionId
							ELSE 0
						END
	FROM dbo.N88_Functions WITH (NOLOCK)
	WHERE SiteId = @SiteId AND FunctionKey = @FunctionKey

	-- Get user permission and group permission
	IF @FunctionId <> 0
	BEGIN
		SELECT @UserPolicy = ISNULL(Policy, 0)
		FROM dbo.N88_UserFunction WITH (NOLOCK)
		WHERE UserId = @UserId AND FunctionId = @FunctionId

		SELECT @GroupPolicy = ISNULL(gf.Policy, 0)
		FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
			INNER JOIN dbo.N88_Users AS u WITH (NOLOCK) ON u.GroupId = gf.GroupId
		WHERE u.UserId = @UserId AND gf.FunctionId = @FunctionId
	END

	-- Check permission
	IF @UserPolicy >= @Policy OR @GroupPolicy >= @Policy
	BEGIN
		SELECT @ErrCode = 0
	END
	ELSE
	BEGIN
		SELECT
			@ErrCode = 500,
			@ErrMsg = N'You are not authorized on this function.'
	END
END
GO
