/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_AssignFunctionToUsers]
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
	Task: Assign function permission to users
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		- Value : '<ROOT><FunctionPolicy UserId='{0}' Policy='{1}'></FunctionPolicy></ROOT>'
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE @startRun DATETIME = GETDATE()
		,@endRun DATETIME
		,@duration INT
		,@logSPData NVARCHAR(MAX)
		,@logSPDataOld NVARCHAR(MAX)
		,@xml XML

	-- Write log before update
	SELECT uf.FunctionId
		,uf.Policy
		,uf.UserId
		,u.username
	INTO #TempData
	FROM dbo.N88_UserFunction AS uf WITH (NOLOCK)
		INNER JOIN dbo.N88_Users AS u WITH (NOLOCK) ON uf.UserId = u.UserId
	WHERE uf.FunctionId = @FunctionId

	SET @xml = (	SELECT @FunctionId AS '@f',
						(
						SELECT
							uf.UserId AS '@ui'
							,uf.Policy AS '@p'
							,uf.Username AS '@u'
						FROM #TempData AS uf
						FOR XML PATH('z'),TYPE
						)
					FOR XML PATH('r'),TYPE)
	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Read information from @Value and insert into temp table
	DECLARE @TblFuncPolicy TABLE (UserId INT, Policy INT)
	DECLARE @DocHandler INT

	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @Value

	INSERT INTO @TblFuncPolicy (
		UserId,
		Policy)
	SELECT
		Data.UserId,
		Data.Policy
	FROM OPENXML(@DocHandler, '/ROOT/FunctionPolicy', 1) WITH (UserId INT, Policy INT) AS Data

	EXEC sp_xml_removedocument @DocHandler

	-- Update policy for users assigned the function already
	UPDATE dbo.N88_UserFunction
	SET Policy = 1
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND UserId IN (
			SELECT UserId
			FROM @TblFuncPolicy
			WHERE Policy = 1
			)

	UPDATE dbo.N88_UserFunction
	SET Policy = 2
		,ModifiedBy = @ModifiedBy
		,ModifiedDate = @ModifiedDate
	WHERE FunctionId = @FunctionId
		AND SiteId = @SiteId
		AND UserId IN ( SELECT UserId FROM @TblFuncPolicy WHERE Policy = 2)

	-- Assigns the fucntion to new users
	INSERT INTO dbo.N88_UserFunction (
		UserId
		,FunctionId
		,SiteId
		,Policy
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
		)
	SELECT temp.UserId
		,@FunctionId
		,@SiteId
		,temp.Policy
		,@ModifiedBy
		,@ModifiedDate
		,@ModifiedBy
		,@ModifiedDate
	FROM @TblFuncPolicy AS temp
	WHERE NOT EXISTS (	SELECT TOP (1) *
						FROM dbo.N88_UserFunction AS uf WITH (NOLOCK)
						WHERE uf.UserId = temp.UserId AND uf.FunctionId = @FunctionId )

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Failed to assign function to users [FunctionId=' + COALESCE(CAST(@FunctionId AS VARCHAR(10)), SPACE(1)) + ']'

		RETURN
	END

	-- write log after update
	SET @xml = (	SELECT @FunctionId AS '@f'
						,(
							SELECT uf.UserId AS '@ui'
								,uf.Policy AS '@p'
								,u.Username AS '@u'
							FROM dbo.N88_UserFunction AS uf WITH (NOLOCK)
								LEFT JOIN #TempData AS t ON uf.UserId = t.UserId AND uf.Policy = t.Policy
								INNER JOIN dbo.N88_Users AS u WITH (NOLOCK) ON uf.UserId = u.UserId
							WHERE uf.FunctionId = @FunctionId AND t.UserId IS NULL
							FOR XML PATH('z'), TYPE
							)
					FOR XML PATH('r'), TYPE)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		@UserId = @CurrentUserId
		,@SPName = 'N88_Function_AssignFunctionToUsers'
		,@ObjectId = @FunctionId
		,@ObjectTypeId = 4 --Object type : Function
		,@Language = @Language
		,@SiteID = @CurrentSiteId
		,@IP = @LoginIP
		,@Date = @LogDate
		,@Data = @logSPData
		,@OldData = @logSPDataOld
		,@Duration = @Duration
END
GO
