/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_Insert]
	@GroupId			SMALLINT OUTPUT
	,@GroupName			VARCHAR(50)
	,@Description		VARCHAR(200) = NULL
	,@IsActive			BIT
	,@CreatedBy			INT
	,@CreatedDate		DATETIME
	,@CurrentUserId		INT
	,@CurrentSiteId		TINYINT
	,@IsLicenseeGroup	BIT = 1
	,@SiteId			TINYINT = NULL
	,@LogDate			DATETIME
	,@LoginIP			VARCHAR(30) = ''
	,@Language			VARCHAR(20) = 'en-us'
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(1000) = '' OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Create new group
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		
	Param's Explanation: 
	• @ErrCode	:
		= 0: super create master successfully.
		> 0: Specific Error.
	• Main	:	<root><xml path="r" />
					<row item="GroupId" alias="gi" />
					<row item="GroupName" alias="g" />
					<row item="Description" alias="d" />
					<row item="IsActive" alias="i" />
					<row item="IsLicenseeGroup" alias="il" />
					<row item="SiteId" alias="si" />
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

	IF EXISTS (
			SELECT 1
			FROM dbo.N88_Groups WITH (NOLOCK)
			WHERE GroupName = LTRIM(@GroupName)
				AND ISNULL(IsLicenseeGroup, 0) = @IsLicenseeGroup
				AND ISNULL(SourceSiteId,0) = ISNULL(@SiteId,0)
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'The group name existed.'

		RETURN
	END

	-- Insert new group 
	INSERT INTO dbo.N88_Groups (
		LTRIM(GroupName)
		,Description
		,IsActive
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
		,IsLicenseeGroup
		,SourceSiteId
		)
	VALUES (
		LTRIM(@GroupName)
		,@Description
		,@IsActive
		,@CreatedBy
		,@CreatedDate
		,@CreatedBy
		,@CreatedDate
		,@IsLicenseeGroup
		,@SiteId
		)

	SET @GroupId = SCOPE_IDENTITY()

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Fail to insert group of the GroupId ' + CONVERT(VARCHAR(10), @GroupId)

		RETURN
	END

	-- Write log
	SET @xml = (
			SELECT @GroupId AS '@gi'
				,LTRIM(@GroupName) AS '@g'
				,@Description AS '@d'
				,@IsActive AS '@i'
				,@IsLicenseeGroup AS '@il'
				,@SiteId AS '@si'
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		@UserId = @CurrentUserId
		,@SPName = 'N88_Group_Insert'
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
