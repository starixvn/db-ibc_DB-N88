/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_Update]
	@UserId INT
	,@FirstName NVARCHAR(50) = NULL
	,@LastName NVARCHAR(50) = NULL
	,@Email NVARCHAR(50) = NULL
	,@DefaultBaseCurrencyId INT = NULL
	,@GroupId SMALLINT
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
	Task: Update user info
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20201118@Kos: Support default base currency [RedmineID: #145346]
		- 20210715@Hogan: Apply Date Range permission [RedmineID: #158257]
		- 20230615@Hogan: Remove Date Range permission [RedmineID: #189299]

	Param's Explanation:
		• @UserId: UserId from table Users
		• @ErrCode: 
		• @ErrMsg: Error description.

		• Main:	<root><xml path="r" />
					<row item="Username" alias="u" />
					<row item="UserId" alias="ui" />
					<row item="GroupId" alias="gi" />
					<row item="GroupName" alias="g" />
					<row item="FirstName" alias="f" />
					<row item="LastName" alias="l" />
					<row item="Email" alias="e" />
					<row item="DefaultBaseCurrencyId" alias="bc" />
					<row item="DefaultBaseCurrencyCode" alias="bcc" />
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
			SELECT u.UserId AS '@ui'
				,u.Username AS '@u'
				,g.GroupId AS '@gi'
				,g.GroupName AS '@g'
				,u.FirstName AS '@f'
				,u.LastName AS '@l'
				,u.Email AS '@e'
				,u.DefaultBaseCurrencyId AS '@bc'
				,e.Code AS '@bcc'
			FROM dbo.N88_Users AS u WITH (NOLOCK)
				LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON u.GroupId = g.GroupId
				LEFT JOIN CustDB.dbo.exchange AS e WITH (NOLOCK) ON e.ExchangeId = u.DefaultBaseCurrencyId
			WHERE u.UserId = @UserId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Get old group before update
	DECLARE @dbGroupID INT

	SELECT @dbGroupID = GroupId
	FROM dbo.N88_Users WITH (NOLOCK)
	WHERE UserId = @UserId

	-- Update user group if change group
	IF @dbGroupID <> @GroupId
	BEGIN
		UPDATE dbo.N88_Users WITH (ROWLOCK, UPDLOCK)
		SET GroupId = @GroupId
		WHERE UserId = @UserId
	END

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
			,@ErrMsg = N'Update fail UserId ' + COALESCE(CAST(@UserId AS VARCHAR(10)), SPACE(1))

		RETURN
	END

	-- Update customer information
	UPDATE dbo.N88_Users WITH (ROWLOCK, UPDLOCK)
	SET
		FirstName = @FirstName,
		LastName = @LastName,
		Email = @Email,
		DefaultBaseCurrencyId = @DefaultBaseCurrencyId
	WHERE UserId = @UserId

	-- Write log after update
	SET @xml = (
			SELECT u.UserId AS '@ui'
				,u.Username AS '@u'
				,g.GroupId AS '@gi'
				,g.GroupName AS '@g'
				,u.FirstName AS '@f'
				,u.LastName AS '@l'
				,u.Email AS '@e'
				,u.DefaultBaseCurrencyId AS '@bc'
				,e.Code AS '@bcc'
			FROM dbo.N88_Users AS u WITH (NOLOCK)
				LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON u.GroupId = g.GroupId
				LEFT JOIN CustDB.dbo.exchange AS e WITH (NOLOCK) ON e.ExchangeId = u.DefaultBaseCurrencyId
			WHERE u.UserId = @UserId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog @UserId = @CurrentUserId
		,@SPName = 'N88_User_Update'
		,@ObjectId = @UserId
		,@ObjectTypeId = 1	-- Object type : User
		,@Language = @Language
		,@SiteID = @CurrentSiteId
		,@IP = @LoginIP
		,@Date = @LogDate
		,@Data = @logSPData
		,@OldData = @logSPDataOld
		,@Duration = @Duration
END
GO
