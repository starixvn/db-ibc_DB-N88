/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_Insert] @UserId INT OUTPUT
	,@Username VARCHAR(30)
	,@UserPwd VARCHAR(40) = ''
	,@SiteId TINYINT = NULL
	,@FirstName NVARCHAR(50) = NULL
	,@LastName NVARCHAR(50) = NULL
	,@Email NVARCHAR(50) = NULL
	,@GroupId SMALLINT
	,@CurrentUserId INT
	,@CurrentSiteId TINYINT
	,@LogDate DATETIME
	,@LoginIP VARCHAR(30) = ''
	,@Language VARCHAR(10) = 'en-us'
	,@IsLicenseeUser BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(1000) = '' OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Create new user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
	• @UserId: UserId from table Users
	• @ErrCode:
		= 0: Insert successfully.
		> 0: Specific Error.
	• @ErrMsg: Error description.

	*** WRITE LOG template:
	Main	:	<root><xml path="r" />
					<row item="Username" alias="u" />
					<row item="UserId" alias="ui" />
					<row item="GroupId" alias="gi" />
					<row item="GroupName" alias="g" />
					<row item="FirstName" alias="f" />
					<row item="LastName" alias="l" />
					<row item="Email" alias="e" />
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

	-- Check duplicate username
	IF EXISTS (
			SELECT 1
			FROM dbo.N88_Users u WITH (NOLOCK)
			LEFT JOIN dbo.N88_UserSite us WITH (NOLOCK) ON u.UserId = us.UserId
			WHERE Username = @Username
				AND (
					(
						@IsLicenseeUser = 0
						AND ISNULL(u.IsLicenseeUser, 0) = @IsLicenseeUser
						)
					OR (
						@IsLicenseeUser = 1
						AND us.SiteId = @SiteId
						)
					)
			)
		OR (
			@IsLicenseeUser = 1
			AND LOWER(@Username) LIKE '%starix%'
			)
	BEGIN
		SELECT @ErrCode = 102
			,@ErrMsg = N'This username is not available.'

		RETURN
	END

	-- create new user
	SELECT @UserId = MAX(UserId) + 1
	FROM dbo.N88_Users WITH (NOLOCK)

	INSERT INTO dbo.N88_Users (
		UserId
		,Username
		,Userpwd
		,GroupId
		,FirstName
		,LastName
		,Email
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
		,IsLicenseeUser
		,SourceSiteId
		)
	VALUES (
		@UserId
		,@Username
		,@UserPwd
		,@GroupId
		,@FirstName
		,@LastName
		,@Email
		,@CurrentUserId
		,@LogDate
		,@CurrentUserId
		,@LogDate
		,@IsLicenseeUser
		,@SiteId
		)

	-- Write log
	SET @xml = (
			SELECT @UserId AS '@ui'
				,@Username AS '@u'
				,@GroupId AS '@gi'
				,g.GroupName AS '@g'
				,@FirstName AS '@f'
				,@LastName AS '@l'
				,@Email AS '@e'
				,@SiteId AS '@si'
				,@IsLicenseeUser AS '@il'
			FROM dbo.N88_Users AS u WITH (NOLOCK)
			INNER JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON u.GroupId = g.GroupId
			WHERE u.userid = @UserId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog @UserId = @CurrentUserId
		,@SPName = 'N88_User_Insert'
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
