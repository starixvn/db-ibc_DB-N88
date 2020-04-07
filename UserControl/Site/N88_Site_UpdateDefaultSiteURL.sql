/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_UpdateDefaultSiteURL]
	@SiteUrlId		SMALLINT
	,@SiteId		TINYINT
	,@Environment	VARCHAR(10)
	,@CurrentUserId	INT
	,@CurrentSiteId TINYINT
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)			= ''
	,@Language		VARCHAR(20)			= 'en-us'
	,@ErrCode		INT					= 0			OUTPUT
	,@ErrMsg		NVARCHAR(1000)		= ''		OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Update default site URL
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		*** WRITE LOG template:
		Main: 
			<root><xml path="r" /><row item="SiteId" alias="s" /></root>
		Sub: 
			<root><xml path="r/z" />
					<row item="SiteURLId" alias="si" />				
					<row item="URL" alias="u" />
					<row item="Environment" alias="e" />
					<row item="IsDefault" alias="id" />
					<row item="IsActive" alias="ia" />
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
		SELECT
			@SiteId AS '@s',
			(
				SELECT
					su.SiteURLId	AS '@si'
					,su.URL			AS '@u'	
					,su.Environment	AS '@e'
					,su.IsDefault	AS '@id'
					,su.IsActive	AS '@ia'
				FROM dbo.N88_SiteURL AS su WITH (NOLOCK)
				WHERE SiteId = @SiteId
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Update site url default is one
	UPDATE dbo.N88_SiteURL WITH (ROWLOCK, UPDLOCK)
	SET	IsDefault = 0
	WHERE SiteId = @SiteId AND Environment = @Environment

	UPDATE dbo.N88_SiteURL WITH (ROWLOCK, UPDLOCK)
	SET	IsDefault = 1
	WHERE SiteUrlId = @SiteUrlId

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1, 
			@ErrMsg = 'Failed to update default site url [SiteUrlId = ' + coalesce(cast(@SiteId AS VARCHAR(10)), space(1)) + ']'
		RETURN
	END

	-- for write log
	SET @xml = (
		SELECT
			@SiteId AS '@s',
			(
				SELECT
					su.SiteURLId	AS '@si'
					,su.URL			AS '@u'	
					,su.Environment	AS '@e'
					,su.IsDefault	AS '@id'
					,su.IsActive	AS '@ia'
				FROM dbo.N88_SiteURL AS su WITH (NOLOCK)
				WHERE SiteId = @SiteId
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Site_UpdateDefaultSiteURL',
		@ObjectId		= @SiteId,
		@ObjectTypeId	= 3,			--Object type : Site
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
