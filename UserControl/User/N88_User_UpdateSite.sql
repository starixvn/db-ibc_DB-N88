/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_UpdateSite]
	@UserId				INT
	,@SiteId			TINYINT
	,@Level				TINYINT
	,@IsActive			BIT
	,@ExpiredDate		SMALLDATETIME	= NULL
	,@IsNeverExpired	BIT
	,@ModifiedBy		INT
	,@ModifiedDate		DATETIME
	,@CurrentUserId		INT
	,@CurrentSiteId		TINYINT
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30)		=	''
	,@Language			VARCHAR(20)		=	'en-us'
	,@ErrCode			INT				=	0		OUTPUT
	,@ErrMsg			NVARCHAR(1000)	=	''		OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Assign site to user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation:
	WRITE LOG template:
	main:
		<root><xml path="r" />
			<row item="UserId" alias="u" />
			<row item="SiteId" alias="si" />
			<row item="SiteName" alias="s" />
			<row item="Level" alias="l" />
			<row item="IsActive" alias="i" />
			<row item="ExpiredDate" alias="ed" />
			<row item="IsNeverExpired" alias="ine" />
		</root>
*/

BEGIN
	SET NOCOUNT ON

	IF EXISTS (
			SELECT 1
			FROM dbo.N88_Users WITH (NOLOCK)
			WHERE UserId = @UserId
				AND IsLicenseeUser = 1
				AND SourceSiteId <> @SiteId
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Cannot update site for this user.'

		RETURN;
	END

	-- For write log
	DECLARE 
		@startRun		DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPDataOld	NVARCHAR(MAX)
		,@xml			XML
		,@oldLevel		INT

	SET @startRun = GETDATE()

	-- Write log before update
	SET @xml = (
		SELECT 
			@UserId			AS '@u'
			,@SiteId		AS '@si'
			,s.SiteName		AS '@s'
			,us.[Level]		AS '@l'
			,us.IsActive	AS '@i'
			,us.ExpiredDate	AS '@ed'
			,us.IsNeverExpired	AS '@ine'
		FROM dbo.N88_Sites AS s WITH (NOLOCK)
			INNER JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON s.SiteId = us.SiteId
		WHERE s.SiteId = @SiteId AND us.UserId = @UserId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SELECT @oldLevel = [Level]
	FROM dbo.N88_UserSite WITH (NOLOCK)
	WHERE UserId = @UserId AND SiteId = @SiteId

	-- Remove all user function permissions if downgrade
	IF @Level < @oldLevel
	BEGIN
		UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
		SET Policy = 0
		WHERE UserId = @UserId AND SiteId = @SiteId
	END

	-- Update information
	UPDATE dbo.N88_UserSite WITH (ROWLOCK, UPDLOCK)
	SET
		[Level]			= @Level
		,IsActive		= @IsActive
		,ExpiredDate	= @ExpiredDate
		,IsNeverExpired	= @IsNeverExpired
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE UserId = @UserId AND SiteId = @SiteId

	-- If user is site admin then assign all functions to him/her
	IF @Level > 0 AND @oldLevel = 0
	BEGIN
		UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
		SET Policy = 1
		WHERE
			UserId = @UserId
			AND FunctionId IN (	SELECT FunctionId
								FROM dbo.N88_Functions WITH (NOLOCK)
								WHERE SiteId = @SiteId AND CRUD = 0 )

		UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
		SET Policy = 2
		WHERE
			UserId = @UserId
			AND FunctionId IN (	SELECT FunctionId
								FROM dbo.N88_Functions WITH (NOLOCK)
								WHERE SiteId = @SiteId AND CRUD = 1 )

		INSERT dbo.N88_UserFunction (
			UserId,
			FunctionId,
			SiteId,
			Policy,
			CreatedDate,
			ModifiedDate )
		SELECT
			@UserId,
			f.FunctionId,
			f.SiteId,
			policy = CASE f.CRUD
						WHEN 0 THEN 1
						WHEN 1 THEN 2
					END,
			@startRun,
			@startRun
		FROM dbo.N88_Functions AS f WITH (NOLOCK)
		WHERE
			f.SiteId = @SiteId
			AND NOT EXISTS (	SELECT 1
								FROM dbo.N88_UserFunction AS uf WITH (NOLOCK)
								WHERE uf.UserId = @UserId AND uf.FunctionId = f.FunctionId )
	END

	IF @@ERROR > 0
	BEGIN
		SELECT
			@ErrCode = 1,
			@ErrMsg = 'Failed to edit user site UserId '+ CONVERT(VARCHAR(10), @UserId)
		RETURN
	END

	-- Write log
	SET @xml = (
		SELECT 
			@UserId			AS '@u'
			,@SiteId		AS '@si'
			,s.SiteName		AS '@s'
			,us.[Level]		AS '@l'
			,us.IsActive	AS '@i'
			,us.ExpiredDate		AS '@ed'
			,us.IsNeverExpired	AS '@ine'
		FROM dbo.N88_Sites AS s WITH (NOLOCK)
			INNER JOIN dbo.N88_UserSite AS us WITH (NOLOCK) ON s.SiteId = us.SiteId
		WHERE s.SiteId = @SiteId AND us.UserId = @UserId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_User_UpdateSite',
		@ObjectId		= @UserId,
		@ObjectTypeId	= 1,			--Object type : User
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
