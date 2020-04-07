/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_AssignFunctionToGroups]
	@FunctionId		SMALLINT,
	@SiteId			TINYINT,
	@Value			NVARCHAR(MAX),
	@ModifiedBy		INT,
	@ModifiedDate	DATETIME,
	@CurrentUserId	INT,
	@CurrentSiteId	TINYINT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)		= '',
	@Language		VARCHAR(20)		= 'en-us',
	@ErrCode		INT				= 0			OUTPUT,
	@ErrMsg			NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Assign function permission to groups
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		- Value : '<ROOT><FunctionPolicy GroupId='{0}' Policy='{1}'></FunctionPolicy></ROOT>'
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

	-- Write log before assign permission
	SELECT
		gf.FunctionId,
		gf.Policy,
		gf.GroupId,
		g.GroupName
	INTO #TempData
	FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
		INNER JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON gf.GroupId = g.GroupId
	WHERE gf.FunctionId = @FunctionId

	SET @xml = (
		SELECT @FunctionId AS '@f',
			(
				SELECT
					gf.GroupId	AS '@gi',
					gf.Policy		AS '@p',
					gf.GroupName	AS '@g'
				FROM #TempData	 AS gf
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')	
	-- Read information from @Value and insert into temp table
	DECLARE @TblFuncPolicy TABLE(GroupId SMALLINT, Policy TINYINT)
   
	DECLARE @DocHandler INT

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Value

	INSERT INTO @TblFuncPolicy (GroupId, Policy)
	SELECT Data.GroupId, Data.Policy
	FROM OPENXML (@DocHandler, '/ROOT/FunctionPolicy',1) 
	WITH (GroupId	INT,
		Policy		INT
	) AS Data

	EXEC sp_xml_removedocument @DocHandler

	--Update policy for users assigned the function already
	UPDATE dbo.N88_GroupFunction
	SET
		Policy			= 1
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND GroupId IN (SELECT GroupId FROM @TblFuncPolicy WHERE Policy = 1)

	UPDATE dbo.N88_GroupFunction
	SET	
		Policy			= 2
		,ModifiedBy		= @ModifiedBy
		,ModifiedDate	= @ModifiedDate
	WHERE
		FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND GroupId IN (SELECT GroupId FROM @TblFuncPolicy WHERE Policy = 2)

	-- Assigns the fucntion to new users
	INSERT INTO dbo.N88_GroupFunction (
		GroupId
		,FunctionId
		,SiteId
		,Policy
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
	)
	SELECT
		Temp.GroupId
		,@FunctionId
		,@SiteId
		,Temp.Policy
		,@ModifiedBy
		,@ModifiedDate
		,@ModifiedBy
		,@ModifiedDate
	FROM @TblFuncPolicy AS Temp
	WHERE NOT EXISTS (	SELECT TOP(1) *
						FROM dbo.N88_GroupFunction AS uf WITH (NOLOCK)
						WHERE uf.GroupId = Temp.GroupId AND uf.FunctionId = @FunctionId)

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT
			@ErrCode = 1, 
			@ErrMsg = 'Failed to assign function to group [FunctionId='+ COALESCE(CAST(@FunctionId AS VARCHAR(10)), SPACE(1)) + ']'
		RETURN
	END

	-- write log after update
	SET @xml = (
		SELECT @FunctionId		AS '@f',
			(
				SELECT gf.GroupId			AS '@gi'
						,gf.Policy			AS '@p'
						,g.GroupName		AS '@g'
				FROM dbo.N88_GroupFunction AS gf WITH (NOLOCK)
					LEFT JOIN #TempData AS t ON gf.GroupId = t.GroupId AND gf.Policy = t.Policy
					INNER JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON gf.GroupId = g.GroupId
				WHERE gf.FunctionId = @FunctionId
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
		@SPName			= 'N88_Function_AssignFunctionToGroups',
		@ObjectId		= @FunctionId,
		@ObjectTypeId	= 4,			--Object type : Function
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
