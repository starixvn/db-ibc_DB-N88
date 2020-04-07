/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_Update]
	@SiteId				TINYINT,
	@SiteName			VARCHAR(50),
	@SiteKey			VARCHAR(50),
	@SecretAccessKey	VARCHAR(200),
	@Description		VARCHAR(200)	= NULL,
	@IsActive			BIT,
	@Environment		VARCHAR(10),	-- Values : UAT,LIVE
	@CurrentUserId		INT,
	@CurrentSiteId		TINYINT,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		= '',
	@Language			VARCHAR(20)		= 'en-us',
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				NVARCHAR(1000)	= ''		OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Update site info
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
	
	*** WRITE LOG template:
	Main: 
		<root><xml path="r" />
			<row item="SiteId" alias="si" />
			<row item="SiteName" alias="s" />
			<row item="Description" alias="d" />
			<row item="IsActive" alias="i" />
			<row item="Environment" alias="e" />
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
	-- write log before update
	SET @xml = (
		SELECT @SiteId			AS '@si'
			,s.SiteName			AS '@s'
			,s.SiteKey			AS '@sk'
			,s.SecretAccessKey	AS '@sak'
			,s.Description		AS '@d'
			,s.Environment		AS '@e'
			,s.IsActive			AS '@i'
		FROM dbo.N88_Sites AS s WITH(NOLOCK)
		WHERE s.SiteId = @SiteId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Update site information
	UPDATE dbo.N88_Sites WITH (ROWLOCK, UPDLOCK)
	SET
		SiteName = @SiteName,
		SiteKey = @SiteKey,
		SecretAccessKey = @SecretAccessKey,
		Description = @Description,
		Environment = @Environment,
		IsActive = @IsActive
	WHERE SiteId = @SiteId

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1, 
			@ErrMsg = 'Fail to insert information of the SiteId ' + CONVERT(VARCHAR(10), @SiteId)
		RETURN
	END

	--write log after update
	SET @xml = (
		SELECT @SiteId			AS '@si'
			,@SiteName			AS '@s'
			,@SiteKey			AS '@sk'
			,@SecretAccessKey	AS '@sak'
			,@Description		AS '@d'
			,@Environment		AS '@e'
			,@IsActive			AS '@i'
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Site_Update',
		@ObjectId		= @SiteId,
		@ObjectTypeId	= 3,			-- Object type : Site
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
