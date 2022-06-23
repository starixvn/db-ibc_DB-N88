/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Group_AssignFunction]
	@GroupId		SMALLINT
	,@SiteId		TINYINT
	,@Value			NVARCHAR(MAX)
	,@ModifiedBy	INT
	,@ModifiedDate	DATETIME
	,@CurrentUserId	INT
	,@CurrentSiteId	TINYINT
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)		= ''
	,@Language		VARCHAR(20)		= 'en-us'
	,@ErrCode		INT				= 0			OUTPUT
	,@ErrMsg		NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Assign permission to group
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20220615@Kos: Handle SELECT INTO using temp table [RedmineID: #174035]

	Param's Explanation:
		• @Value	: is xml
			<ROOT>
				<FunctionPolicy FunctionId="1" SiteId="1" Policy="2"></FunctionPolicy>
				<FunctionPolicy FunctionId="2" SiteId="1" Policy="2"></FunctionPolicy>
			</ROOT>
		• @ErrCode :
			= 0: super create master successfully
			> 0: Specific Error

		*** WRITE LOG template:
		Main:
			<root><xml path="r" />
				<row item="GroupId" alias="g" />
				<row item="SiteId" alias="s" />
			</root>
		Sub:
			<root><xml path="r/z" />
				<row item="FunctionId" alias="f" />
				<row item="Policy" alias="p" />
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
	DECLARE @tempData VARCHAR(5000)

	CREATE TABLE #TempData (
		FunctionId	SMALLINT,
		Policy		TINYINT,
		GroupId		SMALLINT
	)

	-- Data xml for write log
	INSERT INTO #TempData (FunctionId, Policy, GroupId)
	SELECT FunctionId, Policy, GroupId
	FROM dbo.N88_GroupFunction AS gf WITH(NOLOCK)
	WHERE gf.GroupId = @GroupId AND gf.SiteId = @SiteId

	SET @xml = (
		SELECT
			@SiteId		AS '@s',
			@GroupId	AS '@g',
			(
				SELECT
					gf.FunctionId AS '@f'
					,gf.Policy AS '@p'
				FROM  #TempData	 AS gf
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Get data from @Value and insert to table
	DECLARE @TableFunctionPolicy TABLE(FunctionId SMALLINT, SiteId TINYINT, Policy TINYINT)

	SET @xml = CONVERT(XML, @Value)
	INSERT INTO @TableFunctionPolicy(FunctionId, siteid, policy)
	SELECT
		T.C.value('./@FunctionId', 'smallint')
		,T.C.value('./@SiteId', 'tinyint')
		,T.C.value('./@Policy', 'tinyint')
	FROM @xml.nodes('/ROOT/FunctionPolicy') AS [T](C) --T: table, C: column		

	-- Update Policy = 0 for function not set to group
	UPDATE dbo.N88_GroupFunction WITH (ROWLOCK, UPDLOCK)
	SET Policy        = 0
		,ModifiedBy   = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE
		GroupId = @GroupId
		AND SiteId = @SiteId
		AND FunctionId NOT IN (SELECT FunctionId FROM @TableFunctionPolicy )

	-- Update policy for function of group
	UPDATE dbo.N88_GroupFunction WITH (ROWLOCK, UPDLOCK)
	SET Policy			=	Temp.Policy
		,ModifiedBy		=	@ModifiedBy
		,ModifiedDate	=	@ModifiedDate
	FROM @TableFunctionPolicy AS Temp
	WHERE
		dbo.N88_GroupFunction.GroupId = @GroupId
		AND dbo.N88_GroupFunction.FunctionId = Temp.FunctionId 

	--Insert new policy for function of group
	INSERT INTO dbo.N88_GroupFunction (
		GroupId
		, FunctionId
		, SiteId
		, Policy
		, CreatedBy
		, CreatedDate
		, ModifiedBy
		, ModifiedDate
	)
	SELECT @GroupId
		,Temp.FunctionId
		,Temp.SiteId
		,Temp.Policy
		,@ModifiedBy
		,@ModifiedDate
		,@ModifiedBy
		,@ModifiedDate
	FROM @TableFunctionPolicy AS Temp
	WHERE NOT EXISTS (	SELECT TOP(1) *
						FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
						WHERE gf.GroupId = @GroupId AND gf.FunctionId = Temp.FunctionId)

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1, 
				@ErrMsg = 'Fail to assign function of the GroupId '+ CONVERT(VARCHAR(10), @GroupId)
		RETURN
	END

	-- write log after update
	SET @xml = (
		SELECT
			@SiteId		AS '@s',
			@GroupId	AS '@g',
			(
				SELECT gf.FunctionId	AS '@f'
					,gf.Policy			AS '@p'
				FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
					LEFT JOIN #TempData t ON gf.FunctionId = t.FunctionId AND gf.Policy = t.Policy
				WHERE gf.GroupId = @GroupId
					AND gf.SiteId = @SiteId
					AND t.GroupId IS NULL
				FOR XML PATH('z'), TYPE	
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)   

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Group_AssignFunction',
		@ObjectId		= @GroupId,
		@ObjectTypeId	= 2,			--Object type : Group
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration

	DROP TABLE #TempData
END
GO
