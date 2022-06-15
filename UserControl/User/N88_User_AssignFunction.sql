/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_AssignFunction]
	@UserId			INT
	,@SiteId		TINYINT
	,@Value			VARCHAR(MAX)
	,@ModifiedBy	INT
	,@ModifiedDate	DATETIME
	,@CurrentUserId	INT
	,@CurrentSiteId	TINYINT
	,@LogDate		DATETIME
	,@LoginIP		VARCHAR(30)		= ''
	,@Language		VARCHAR(20)		= 'en-us'
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(1000)	= ''	OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Assign permission to user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20220615@Kos: Handle SELECT INTO using temp table [RedmineID: #174035]

	Param's Explanation:
		- Value : '<ROOT><FunctionPolicy SiteId="4" FunctionId="4" Policy="1"></FunctionPolicy></ROOT>'

		*** WRITE LOG template:
		main:	<root><xml path="r" />
					<row item="SiteId" alias="s" />
					<row item="UserId" alias="u" />
				</root>
		sub:	<root><xml path="r/z" />
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

	CREATE TABLE #TempData (
		FunctionId	SMALLINT,
		Policy		TINYINT,
		UserId		INT
	)

	INSERT INTO #TempData (FunctionId, Policy, UserId)
	SELECT FunctionId, Policy, UserId
	FROM dbo.N88_UserFunction WITH (NOLOCK)
	WHERE UserId = @UserId AND SiteId = @SiteId

	-- Write log before assign permission
	SET @xml = (
		SELECT
			@SiteId		AS '@s',
			@UserId	AS '@u',
			(
				SELECT
					FunctionId	AS '@f'
					,Policy		AS '@p'
				FROM #TempData
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Read information from @Value and insert into temp table
	DECLARE @TableFunctionPolicy TABLE(FunctionId SMALLINT, SiteId TINYINT, Policy TINYINT)

	SET @xml = CONVERT(XML, @Value)
	INSERT INTO @TableFunctionPolicy(FunctionId, siteid, policy)
	SELECT	T.C.value('./@FunctionId', 'smallint')
			,T.C.value('./@SiteId', 'tinyint')
			,T.C.value('./@Policy', 'tinyint')
	FROM @xml.nodes('/ROOT/FunctionPolicy') as [T](C) --T: table, C: column	

	-- Update Policy = 0 for function not set to user
	UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
	SET Policy = 0
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE
		UserId = @UserId
		AND SiteId = @SiteId
		AND FunctionId NOT IN (SELECT FunctionId FROM @TableFunctionPolicy)

	--Update policy for function of user
	UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
	SET Policy			=	Temp.Policy
		,ModifiedBy		=	@ModifiedBy
		,ModifiedDate	=	@ModifiedDate
	FROM @TableFunctionPolicy AS Temp
	WHERE dbo.N88_UserFunction.UserId = @UserId AND dbo.N88_UserFunction.FunctionId = Temp.FunctionId   

	--Insert new policy for function of user
	INSERT INTO dbo.N88_UserFunction (
		UserId
		, FunctionId
		, SiteId
		, Policy
		, CreatedBy
		, CreatedDate
		, ModifiedBy
		, ModifiedDate
	)
	SELECT
		@UserId
		,Temp.FunctionId
		,Temp.SiteId
		,Temp.Policy
		,@ModifiedBy
		,@ModifiedDate
		,@ModifiedBy
		,@ModifiedDate
	FROM @TableFunctionPolicy AS Temp
	WHERE NOT EXISTS (	SELECT TOP(1) *
						FROM dbo.N88_UserFunction AS uf WITH(NOLOCK)
						WHERE uf.UserId = @UserId AND uf.FunctionId = Temp.FunctionId )

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1, 
			@ErrMsg = 'Fail to assign function UserId '+ CONVERT(VARCHAR(10), @UserId)
		RETURN
	END

	-- write log after update
	SET @xml = (
		SELECT
			@SiteId		AS '@s',
			@UserId	AS '@u',
			(
				SELECT
					uf.FunctionId	AS '@f'
					,uf.Policy		AS '@p'
				FROM dbo.N88_UserFunction uf WITH(NOLOCK)
					LEFT JOIN #TempData t ON uf.FunctionId = t.FunctionId AND uf.Policy = t.Policy
				WHERE uf.UserId = @UserId	
					AND uf.SiteId = @SiteId
					AND t.UserID IS NULL
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData	= REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	SET @endRun		= GETDATE()
	SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_User_AssignFunction',
		@ObjectId		= @UserId,
		@ObjectTypeId	= 1,			--Object type : User
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
