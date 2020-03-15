/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_UpdateStatus]
	@SiteId			TINYINT
	,@IsActive		BIT
	,@CurrentUserId	INT
	,@CurrentSiteId	TINYINT
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)			= ''
	,@Language		VARCHAR(20)			= 'en-us'
	,@ErrCode		INT					= 0			OUTPUT 
	,@ErrMsg		NVARCHAR(1000)		= ''		OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Update site status
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		Main: 
		<root><xml path="r" /><row item="SiteId" alias="s" /><row item="IsActive" alias="i" /></root>
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
			@SiteId		AS '@s',
			s.IsActive	AS '@i'
		FROM dbo.N88_Sites AS s WITH(NOLOCK)
		WHERE s.SiteId = @SiteId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')	

	-- Update site information
	UPDATE dbo.N88_Sites WITH (ROWLOCK, UPDLOCK)
	SET IsActive = @IsActive
	WHERE SiteId = @SiteId

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1, 
			@ErrMsg = 'Fail to update status of the SiteId ' + CONVERT(VARCHAR(10), @SiteId)
		RETURN
	END

	-- write log after update
	SET @xml = (
		SELECT
			@SiteId		AS '@s',
			@IsActive	AS '@i'
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)   

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Site_UpdateStatus',
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
