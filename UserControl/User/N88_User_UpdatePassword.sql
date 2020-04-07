/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_UpdatePassword] @UserId INT
	,@UserPwd NVARCHAR(50)
	,@CurrentUserId INT
	,@CurrentSiteId TINYINT
	,@LogDate DATETIME
	,@LoginIP VARCHAR(30) = ''
	,@Language VARCHAR(20) = 'en-us'
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(1000) = '' OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Update user password
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
	• @UserId : UserId from table Users
	• @ErrCode:
	• @ErrMsg: Error description.
	• Main:	<root><xml path="r" />
					<row item="UserId" alias="ui" />
					<row item="Password" alias="p" />
				</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun DATETIME = GETDATE()
		,@endRun DATETIME
		,@duration INT
		,@logSPData NVARCHAR(MAX)
		,@logSPDataOld NVARCHAR(MAX)
		,@xml XML

	-- Write log before update
	SET @xml = (
			SELECT UserId AS '@ui'
				,Userpwd AS '@p'
			FROM dbo.N88_Users WITH (NOLOCK)
			WHERE UserId = @UserId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	DECLARE @pwdExpiry DATETIME
		,@oldUserPwd VARCHAR(40)
		,@oldPwdExpiry DATETIME

	SELECT @pwdExpiry = DATEADD(DD, 30, GETDATE())

	SELECT @oldUserPwd = userpwd
		,@oldPwdExpiry = pwdexpiry
	FROM dbo.N88_Users WITH (NOLOCK)
	WHERE UserId = @UserId

	-- Update password
	UPDATE dbo.N88_Users WITH (ROWLOCK, UPDLOCK)
	SET userpwd = @UserPwd
		,pwdexpiry = @PwdExpiry
	WHERE UserId = @UserId

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
			,@ErrMsg = N'Update fail UserId ' + COALESCE(CAST(@UserId AS VARCHAR(10)), SPACE(1))

		RETURN
	END

	-- Write log after update
	SET @xml = (
			SELECT UserId AS '@ui'
				,Userpwd AS '@p'
			FROM dbo.N88_Users WITH (NOLOCK)
			WHERE UserId = @UserId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog @UserId = @CurrentUserId
		,@SPName = 'N88_User_UpdatePassword'
		,@ObjectId = @UserId
		,@ObjectTypeId = 1 -- Object type : User
		,@Language = @Language
		,@SiteID = @CurrentSiteId
		,@IP = @LoginIP
		,@Date = @LogDate
		,@Data = @logSPData
		,@OldData = @logSPDataOld
		,@Duration = @Duration
END

GO
