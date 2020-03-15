/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_MenuItem_Insert]
	@MenuItemId			SMALLINT					OUTPUT,
	@FunctionId			SMALLINT,	
	@SiteId				TINYINT,	
	@MenuItemName		NVARCHAR(50),	
	@Description		NVARCHAR(200)	= NULL,
	@ParentId			SMALLINT		= NULL,
	@ParentName			NVARCHAR(50)	= NULL,
	@Policy				TINYINT,
	@URL				NVARCHAR(200)	= NULL,
	@DisplayOrder		SMALLINT,
	@IsActive			BIT,
	@CreatedBy			INT				= NULL, 
	@CreatedDate		DATETIME,
	@Environment		VARCHAR(10)		= 'UAT',			-- 'UAT', 'LIVE'	
	@CurrentUserId		INT,
	@CurrentSiteId		TINYINT,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		= '',
	@Language			VARCHAR(20)		= 'en-us',
	@ErrCode			INT				= 0			OUTPUT, 
	@ErrMsg				NVARCHAR(1000)	= ''		OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Create new menu item
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
	
	Param's Explanation: 
		• Main:
			<root><xml path="r" />
				<row item="MenuItemId" alias="mi" />
				<row item="MenuItemName" alias="m" />
				<row item="FunctionId" alias="fi" />
				<row item="FunctionName" alias="f" />
				<row item="SiteId" alias="si" />
				<row item="SiteName" alias="s" />
				<row item="Description" alias="d" />
				<row item="ParentId" alias="pi" />
				<row item="ParentName" alias="p" />
				<row item="Policy" alias="pl" />
				<row item="URL" alias="u" />
				<row item="DisplayOrder" alias="o" />
				<row item="IsActive" alias="i" />
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

	-- Insert new menu item
	INSERT INTO dbo.N88_MenuItems 
	(
		FunctionId,
		SiteId,
		MenuItemName,
		Description,
		ParentId,
		ParentName,
		Policy,
		URL,
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
		@FunctionId,
		@SiteId,
		@MenuItemName,
		@Description,
		@ParentId,
		@ParentName,
		@Policy,
		@URL,
		@DisplayOrder,
		@IsActive,
		@CreatedBy,
		@CreatedDate,
		@CreatedBy,
		@CreatedDate,
		@Environment
	)

	-- Get menu item id current insert
	SET @MenuItemId = SCOPE_IDENTITY()

	IF @@ERROR > 0
	BEGIN
		SELECT
			@ErrCode = 1, 
			@ErrMsg = 'Fail to insert information of the MenuItemId ' + CONVERT(VARCHAR(10), @MenuItemId)
		RETURN
	END

	-- Write log
	SET @xml = (
		SELECT
			@MenuItemId		AS '@mi'
			,@MenuItemName	AS '@m'
			,@FunctionId	AS '@fi'
			,f.FunctionName	AS '@f'
			,@SiteId		AS '@si'
			,s.SiteName		AS '@s'
			,@Description	AS '@d'
			,@ParentId		AS '@pi'
			,@ParentName	AS '@p'
			,@Policy		AS '@pl'
			,@URL			AS '@u'
			,@DisplayOrder	AS '@o'
			,@IsActive		AS '@i'
		FROM dbo.N88_MenuItems AS m WITH (NOLOCK)
			INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
			INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
		WHERE m.MenuItemId = @MenuItemId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun		= GETDATE()
	SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)   

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_MenuItem_Insert',
		@ObjectId		= @MenuItemId,
		@ObjectTypeId	= 5,			-- Object type : menu item
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
