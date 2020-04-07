/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_AssignNewSite]
	@UserId			INT
	,@SiteId		TINYINT
	,@Level			TINYINT
	,@IsActive		BIT
	,@ExpiredDate	SMALLDATETIME = NULL
	,@IsNeverExpired BIT
	,@CreatedBy		INT
	,@CreatedDate	DATETIME
	,@CurrentUserId	INT
	,@CurrentSiteId	TINYINT
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30) = ''
	,@Language		VARCHAR(20) = 'en-us'
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(1000) = '' OUTPUT
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

	-- For write log
	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPDataOld	NVARCHAR(MAX)
		,@xml			XML

	SET @startRun = GETDATE()

	-- Assign new site to user
	IF EXISTS (	SELECT 1
				FROM dbo.N88_Users WITH (NOLOCK)
				WHERE UserId = @UserId
					AND IsLicenseeUser = 1
					AND SourceSiteId <> @SiteId	)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Cannot assign this user to site.'

		RETURN;
	END

	INSERT INTO dbo.N88_UserSite (
		UserId
		,SiteId
		,[Level]
		,IsActive
		,ExpiredDate
		,IsNeverExpired
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
		)
	VALUES (
		@UserId
		,@SiteId
		,@Level
		,@IsActive
		,@ExpiredDate
		,@IsNeverExpired
		,@CreatedBy
		,@CreatedDate
		,@CreatedBy
		,@CreatedDate
		)

	-- For each site, if user is site admin then assign all functions to him/her
	IF @Level = 50
		OR @Level = 100
	BEGIN
		INSERT dbo.N88_UserFunction (
			UserId
			,FunctionId
			,SiteId
			,Policy
			,CreatedDate
			,ModifiedDate
			)
		SELECT @UserId
			,f.FunctionId
			,f.SiteId
			,policy = CASE f.CRUD
						WHEN 0 THEN 1
						WHEN 1 THEN 2
					END
			,@startRun
			,@startRun
		FROM dbo.N88_Functions AS f WITH (NOLOCK)
		WHERE f.SiteId = @SiteId
	END

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Failed to assign site UserId ' + CONVERT(VARCHAR(10), @UserId)

		RETURN
	END

	-- Write log
	SET @xml = (
			SELECT @UserId AS '@u'
				,@SiteId AS '@si'
				,s.SiteName AS '@s'
				,@Level AS '@l'
				,@IsActive AS '@i'
				,@ExpiredDate AS '@ed'
				,@IsNeverExpired AS '@ine'
			FROM dbo.N88_Sites AS s WITH (NOLOCK)
			WHERE s.SiteId = @SiteId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog @UserId = @CurrentUserId
		,@SPName = 'N88_User_AssignNewSite'
		,@ObjectId = @UserId
		,@ObjectTypeId = 1
		,--Object type : User
		@Language = @Language
		,@SiteID = @CurrentSiteId
		,@IP = @LoginIP
		,@Date = @LogDate
		,@Data = @logSPData
		,@OldData = @logSPDataOld
		,@Duration = @Duration
END
GO
