/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_UpdateStatus]
	@GroupId		SMALLINT
	,@IsActive		BIT
	,@ModifiedBy	INT 
	,@ModifiedDate	DATETIME
	,@CurrentUserId	INT
	,@CurrentSiteId	TINYINT
	,@LoginIP		VARCHAR(30)		=	''
	,@LogDate		DATETIME
	,@Language		VARCHAR(20)		=	'en-us'
	,@ErrCode		INT				=	0			OUTPUT 
	,@ErrMsg		NVARCHAR(1000)	=	''			OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Update group status
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
	• Main:	<root><xml path="r" />
				<row item="GroupId" alias="gi" />
				<row item="IsActive" alias="i" />
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

	-- Get log data
	SET @xml = (
		SELECT
			@GroupId	AS '@gi'
			,g.IsActive	AS '@i'
		FROM dbo.N88_Groups AS g WITH (NOLOCK)
		WHERE g.GroupId = @GroupId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')	

	-- Update status of group
	UPDATE dbo.N88_Groups WITH (ROWLOCK, UPDLOCK)
	SET  IsActive		= @IsActive
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE GroupId = @GroupId
	
	-- Check error
	IF @@ERROR>0
	BEGIN
		SELECT 
			@ErrCode	= 1,
			@ErrMsg		= 'Fail to update status of the GroupId ' + CONVERT(VARCHAR(10), @GroupId)
		RETURN
	END		

	-- Write log
	SET @xml = (
		SELECT
			@GroupId	AS '@gi',
			@IsActive	AS '@i'
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun		= GETDATE()
	SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Group_UpdateStatus',
		@ObjectId		= @GroupId,
		@ObjectTypeId	= 2,					-- Object type : Group
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
