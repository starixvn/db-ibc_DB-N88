/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_Insert]
	@UserId				INT
	,@Username			VARCHAR(30) = null
	,@GroupId			SMALLINT
	,@CreatedBy			INT
	,@CreatedDate		DATETIME
	,@CurrentUserId		INT
	,@CurrentSiteId		TINYINT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		=   ''
	,@Language			VARCHAR(10)		=   'en-us'
	,@ErrCode			INT				=   0		OUTPUT
	,@ErrMsg			NVARCHAR(1000)	=   ''		OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Create new user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
	WRITE LOG template:
	Main:	<root><xml path="r" />
				<row item="Username" alias="u" />
				<row item="UserId" alias="ui" />
				<row item="GroupId" alias="gi" />
				<row item="GroupName" alias="g" />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPDataOld	NVARCHAR(MAX)
		,@xml			XML

	SET @startRun = GETDATE()

	-- Add new user
	INSERT INTO dbo.N88_Users(UserId, GroupId, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
	VALUES(@UserId, @GroupId, @CreatedBy, @CreatedDate, @CreatedBy, @CreatedDate)

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT
			@ErrCode = 1, 
			@ErrMsg = 'Fail to add new UserId ' + CONVERT(VARCHAR(10), @UserId)
		RETURN
	END

	-- Write log
	SET @xml = (
		SELECT @UserId			AS '@ui'
				,@username		AS '@u'
				,@GroupId		AS '@gi'
				,g.GroupName	AS '@g'
		FROM dbo.N88_Users AS u WITH(NOLOCK)
			INNER JOIN dbo.N88_Groups AS g WITH(NOLOCK) ON u.GroupId = g.GroupId
		WHERE u.userid = @UserId 	
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun	= GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_User_Insert',
		@ObjectId		= @UserId,
		@ObjectTypeId	= 1,					-- Object type : User
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END

GO
