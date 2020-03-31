/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_Update]
	@GroupId		SMALLINT
	,@GroupName		VARCHAR(50)
	,@Description	VARCHAR(200) = NULL
	,@IsActive		BIT
	,@ModifiedBy	INT
	,@ModifiedDate	DATETIME
	,@CurrentUserId	INT
	,@CurrentSiteId	TINYINT
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30) = ''
	,@Language		VARCHAR(20) = 'en-us'
	,@SiteId		TINYINT = NULL
	,@IsLicenseeGroup BIT = 0
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(1000) = '' OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Update group info
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
	• Main	:	<root><xml path="r" />
					<row item="GroupId" alias="gi" />
					<row item="GroupName" alias="g" />
					<row item="Description" alias="d" />
					<row item="IsActive" alias="i" />
				</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPDataOld	NVARCHAR(MAX)
		,@xml			XML

	SET @startRun = GETDATE()

	-- Get log data before update
	SET @xml = (
			SELECT @GroupId AS '@gi'
				,g.GroupName AS '@g'
				,g.Description AS '@d'
				,g.IsActive AS '@i'
			FROM dbo.N88_Groups AS g WITH (NOLOCK)
			WHERE g.GroupId = @GroupId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	IF EXISTS (
			SELECT 1
			FROM dbo.N88_Groups WITH (NOLOCK)
			WHERE (
					@IsLicenseeGroup = 1
					AND ISNULL(IsLicenseeGroup, 0) = @IsLicenseeGroup
					AND GroupName = @GroupName
					AND ISNULL(SourceSiteId, 0) = @SiteId
					AND GroupId <> @GroupId
					)
				OR (
					@IsLicenseeGroup = 0
					AND ISNULL(IsLicenseeGroup, 0) = @IsLicenseeGroup
					AND GroupName = @GroupName
					AND GroupId <> @GroupId
					)
				OR (
					GroupId = @GroupId
					AND IsLicenseeGroup = 1
					AND @GroupName LIKE 'starix%'
				)
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'The group name existed.'

		RETURN
	END

	-- Update group information
	UPDATE dbo.N88_Groups WITH (ROWLOCK, UPDLOCK)
	SET GroupName = @GroupName
		,Description = @Description
		,IsActive = @IsActive
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE GroupId = @GroupId

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Fail to update group of the GroupId ' + CONVERT(VARCHAR(10), @GroupId)

		RETURN
	END

	-- Write log
	SET @xml = (
			SELECT @GroupId AS '@gi'
				,@GroupName AS '@g'
				,@Description AS '@d'
				,@IsActive AS '@i'
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		@UserId = @CurrentUserId
		,@SPName = 'N88_Group_Update'
		,@ObjectId = @GroupId
		,@ObjectTypeId = 2
		,@Language = @Language		-- Object type : Group
		,@SiteID = @CurrentSiteId
		,@IP = @LoginIP
		,@Date = @LogDate
		,@Data = @logSPData
		,@OldData = @logSPDataOld
		,@Duration = @Duration
END
GO
