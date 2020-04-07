/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_Update]
	@FunctionId		SMALLINT,
	@SiteId			TINYINT,
	@FunctionName	NVARCHAR(50),
	@FunctionKey	NVARCHAR(50),
	@Description	NVARCHAR(200)	= NULL,
	@ParentId		SMALLINT		= NULL,
	@ParentName		NVARCHAR(50)	= NULL,
	@CRUD			TINYINT,
	@DisplayOrder	SMALLINT,
	@IsActive		BIT,
	@ModifiedBy		INT				= NULL, 
	@ModifiedDate	DATETIME,
	@Environment	VARCHAR(10)		= 'UAT',				-- 'UAT', 'LIVE'
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
	Task: Update function info
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		• Main	:	<root><xml path="r" />
						<row item="FunctionId" alias="fi" />
						<row item="FunctionName" alias="f" />
						<row item="SiteId" alias="si" />
						<row item="SiteName" alias="s" />
						<row item="FunctionKey" alias="fk" />
						<row item="Description" alias="d" />
						<row item="ParentId" alias="pi" />
						<row item="ParentName" alias="p" />
						<row item="CRUD" alias="c" />
						<row item="DisplayOrder" alias="o" />
						<row item="IsActive" alias="i" />
						<row item="Environment" alias="e" />
					</root>
*/

BEGIN
	SET NOCOUNT ON

	-- For write log
	DECLARE 
		@startRun		DATETIME,
		@endRun			DATETIME,
		@duration		INT,
		@logSPData		NVARCHAR(MAX),
		@logSPDataOld	NVARCHAR(MAX),
		@xml			XML

	SET @startRun = GETDATE()

	-- write log before update
	SET @xml = (
		SELECT
			f.FunctionId			AS '@fi'
			,f.FunctionName		AS '@f'	
			,s.SiteId			AS '@si'
			,s.SiteName			AS '@s'
			,f.FunctionKey		AS '@fk'
			,f.Description		AS '@d'
			,f.ParentId			AS '@pi'
			,f.ParentName		AS '@p'
			,f.CRUD				AS '@c'
			,f.DisplayOrder		AS '@o'
			,f.IsActive			AS '@i'
			,f.Environment		AS '@e'
		FROM dbo.N88_Functions AS f WITH (NOLOCK)
			INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE f.FunctionId =  @FunctionId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- SiteId and EnvironmentId before update
	DECLARE @OldSiteId TINYINT
	DECLARE @OldEnvironment VARCHAR(10)
	DECLARE @OldCRUD	TINYINT

	SELECT 
		@OldSiteId		= SiteId,
		@OldEnvironment = Environment,
		@OldCRUD		= CRUD
	FROM dbo.N88_Functions WITH (NOLOCK)
	WHERE FunctionId = @FunctionId

	-- Update function information
	UPDATE dbo.N88_Functions WITH (ROWLOCK, UPDLOCK)
	SET
		SiteId			= @SiteId,
		FunctionName	= @FunctionName,
		FunctionKey		= @FunctionKey,
		Description		= @Description,
		ParentId		= @ParentId,
		ParentName		= @ParentName,
		CRUD			= @CRUD,
		DisplayOrder	= @DisplayOrder,
		IsActive		= @IsActive,
		ModifiedBy		= @ModifiedBy,
		ModifiedDate	= @ModifiedDate,
		Environment		= @Environment
	WHERE FunctionId	= @FunctionId

	-- Update all table contains FunctionId = @FunctionID
	-- and SiteId change
	IF @OldSiteId != @SiteId
	BEGIN
		UPDATE dbo.N88_MenuItems WITH (ROWLOCK, UPDLOCK)
		SET SiteId = @SiteId
		WHERE FunctionId = @FunctionId

		UPDATE dbo.N88_GroupFunction WITH (ROWLOCK, UPDLOCK)
		SET SiteId = @SiteId
		WHERE FunctionId = @FunctionId

		UPDATE dbo.N88_UserFunction WITH (ROWLOCK, UPDLOCK)
		SET SiteId = @SiteId
		WHERE FunctionId = @FunctionId
	END

	-- update permission (from readonly to non readonly) for site admin and portal admin
	IF @CRUD > @OldCRUD
	BEGIN
		UPDATE dbo.N88_UserFunction 
		SET Policy = 2
		WHERE UserId IN (
			SELECT DISTINCT us.UserId
			FROM dbo.N88_UserSite AS us WITH (NOLOCK)
			WHERE us.Level IN(50,100)
			)
			AND FunctionId = @FunctionId
	END

	--update permission (from non read only to readonly) for all user has permission in this function
	IF @CRUD < @OldCRUD
	BEGIN
		UPDATE dbo.N88_UserFunction 
		SET Policy = 1
		WHERE UserId IN (
			SELECT DISTINCT uf.UserId
			FROM dbo.N88_UserFunction AS uf WITH (NOLOCK)
			WHERE uf.FunctionId = @FunctionId
			AND uf.Policy = 2
			)
			AND FunctionId = @FunctionId
	END

	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1, 
			@ErrMsg = 'Fail to update information of the FunctionId ' + CONVERT(VARCHAR(10), @FunctionId)
		RETURN
	END
	ELSE
	BEGIN
		-- Check if Environment change, will be update for all function childs
		IF @OldEnvironment != @Environment
		BEGIN
			-- Get list function child of FunctionId
			;WITH FunctionChild AS (
				SELECT FunctionId 
				FROM dbo.N88_Functions WITH (NOLOCK)
				WHERE FunctionId = @FunctionId

				UNION ALL

				SELECT f.FunctionId 
				FROM
					dbo.N88_Functions AS f WITH(NOLOCK) 
					INNER JOIN FunctionChild r ON f.ParentId = r.FunctionId
			)

			-- Update Environment for all function child
			UPDATE dbo.N88_Functions WITH (ROWLOCK, UPDLOCK)
			SET Environment = @Environment
			WHERE FunctionId IN ( SELECT  FunctionId FROM FunctionChild)
		END
	END

	-- Write log after update
	SET @xml = (
		SELECT
			@FunctionId		AS '@fi'
			,@FunctionName	AS '@f'	
			,@SiteId		AS '@si'
			,s.SiteName		AS '@s'
			,@FunctionKey	AS '@fk'
			,@Description	AS '@d'
			,@ParentId		AS '@pi'
			,@ParentName	AS '@p'
			,@CRUD			AS '@c'
			,@DisplayOrder	AS '@o'
			,@IsActive		AS '@i'
			,@Environment	AS '@e'
		FROM dbo.N88_Sites AS s WITH (NOLOCK)
		WHERE s.SiteId = @SiteId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Function_Update',
		@ObjectId		= @FunctionId,
		@ObjectTypeId	= 4,					-- Object type : Function
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
