/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_Duplicate]
	@DuplicateFunctionId	SMALLINT,	
	@FunctionId				SMALLINT							OUTPUT,
	@SiteId					TINYINT,
	@FunctionName			NVARCHAR(50),
	@FunctionKey			NVARCHAR(50),
	@Description			NVARCHAR(200)	= NULL,
	@ParentId				SMALLINT		= NULL,
	@ParentName				NVARCHAR(50)	= NULL,	
	@CRUD					TINYINT,
	@DisplayOrder			SMALLINT,
	@IsActive				BIT,	
	@CreatedBy				INT				= NULL, 
	@CreatedDate			DATETIME,
	@Environment			VARCHAR(10)		= 'UAT',	-- 'UAT', 'LIVE'
	@CurrentUserId			INT,
	@CurrentSiteId			TINYINT,
	@LogDate				DATETIME,
	@LoginIP				VARCHAR(30)		= '',
	@Language				VARCHAR(20)		= 'en-us',
	@ErrCode				INT				= 0			OUTPUT, 
	@ErrMsg					NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Duplicate function
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		
	Param's Explanation:
		@DuplicateFunctionId : FunctionId will be duplicate
		@CRUD : 
			= 0 : Is read only permission
			= 1 : Is host permission
		Duplicate function can not change CRUD field

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
		@now			DATETIME,
		@startRun		DATETIME,
		@endRun			DATETIME,
		@duration		INT,
		@logSPData		NVARCHAR(MAX),
		@logSPDataOld	NVARCHAR(MAX),
		@xml			XML

	SET @now = GETDATE()
	SET @startRun = @now

	-- write log function will be duplicate
	SET @xml = (
		SELECT
			f.FunctionId	AS '@fi'
			,f.FunctionName	AS '@f'	
			,s.SiteId		AS '@si'
			,s.SiteName		AS '@s'
			,f.FunctionKey	AS '@fk'
			,f.Description	AS '@d'
			,f.ParentId		AS '@pi'
			,f.ParentName	AS '@p'
			,f.CRUD			AS '@c'
			,f.DisplayOrder	AS '@o'
			,f.IsActive		AS '@i'
			,f.Environment	AS '@e'
		FROM dbo.N88_Functions AS f WITH (NOLOCK)
			INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE f.FunctionId =  @DuplicateFunctionId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Insert new function
	INSERT dbo.N88_Functions 
	(
		SiteId,
		FunctionName,
		FunctionKey,
		Description,
		ParentId,
		ParentName,
		CRUD,
		DisplayOrder,
		IsActive,
		CreatedBy,
		CreatedDate,
		ModifiedBy,
		ModifiedDate,
		Environment    
	)
	VALUES
	(
		@SiteId,
		@FunctionName,
		@FunctionKey,
		@Description,
		@ParentId,
		@ParentName,
		@CRUD,
		@DisplayOrder,
		@IsActive,
		@CreatedBy,
		@CreatedDate,
		@CreatedBy,
		@CreatedDate,
		@Environment    
	)

	SET @FunctionId = SCOPE_IDENTITY()

	-- Duplicates privileged groups/users
	
	-- Duplicates privileged groups
	INSERT dbo.N88_GroupFunction
	(
		GroupId,
		FunctionId,
		SiteId,
		Policy,
		CreatedBy,
		CreatedDate,
		ModifiedDate
	)
	SELECT
		GroupId,
		@FunctionId,
		SiteId,
		Policy,
		@CreatedBy,
		@now,
		@now
	FROM dbo.N88_GroupFunction WITH (NOLOCK)
	WHERE FunctionId = @DuplicateFunctionId

	-- Duplicates privileged users
	INSERT dbo.N88_UserFunction
	(
		UserId,
		FunctionId,
		SiteId,
		Policy,
		CreatedBy,
		CreatedDate,
		ModifiedDate
	)
	SELECT
		UserId,
		@FunctionId,
		SiteId,
		Policy,
		@CreatedBy,
		@now,
		@now
	FROM dbo.N88_UserFunction  WITH (NOLOCK)
	WHERE FunctionId = @DuplicateFunctionId

	----------------------------------------
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1,
			@ErrMsg = 'Failed to duplicate function [FunctionId = ' + COALESCE(CAST(@DuplicateFunctionId AS VARCHAR(10)), SPACE(1)) + ']'
		RETURN
	END

	-- Write log after duplicate
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

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun		= GETDATE()
	SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Function_Duplicate',
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
