/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_MenuItem_Update] @MenuItemId SMALLINT
	,@FunctionId SMALLINT
	,@SiteId TINYINT
	,@MenuItemName NVARCHAR(50)
	,@MenuItemKey NVARCHAR(50)
	,@Description NVARCHAR(200) = NULL
	,@ParentId SMALLINT = NULL
	,@ParentName NVARCHAR(50) = NULL
	,@Policy TINYINT
	,@URL NVARCHAR(200) = NULL
	,@DisplayOrder SMALLINT
	,@IsActive BIT
	,@ModifierId INT = NULL
	,@ModifiedDate DATETIME
	,@Environment VARCHAR(10) = 'UAT' -- 'UAT', 'LIVE'
	,@CurrentUserId INT
	,@CurrentSiteId TINYINT
	,@LogDate DATETIME
	,@LoginIP VARCHAR(30) = ''
	,@Language VARCHAR(20) = 'en-us'
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20200314@Kos
	Task: Update menu item info
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20200319@Tim: add MenuItemKey [RedmineId: #129873]
	
	Param's Explanation:
		• Main:
			<root><xml path="r" />
				<row item="MenuItemId" alias="mi" />
				<row item="MenuItemName" alias="m" />
				<row item="MenuItemKey" alias="mk" />
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
	DECLARE @startRun DATETIME
		,@endRun DATETIME
		,@duration INT
		,@logSPData NVARCHAR(MAX)
		,@logSPDataOld NVARCHAR(MAX)
		,@xml XML

	SET @startRun = GETDATE()
	-- write log before update
	SET @xml = (
			SELECT @MenuItemId AS '@mi'
				,m.MenuItemName AS '@m'
				,m.MenuItemKey AS '@mk'
				,m.FunctionId AS '@fi'
				,f.FunctionName AS '@f'
				,m.SiteId AS '@si'
				,s.SiteName AS '@s'
				,m.Description AS '@d'
				,m.ParentId AS '@pi'
				,m.ParentName AS '@p'
				,m.Policy AS '@pl'
				,m.URL AS '@u'
				,m.DisplayOrder AS '@o'
				,m.IsActive AS '@i'
			FROM dbo.N88_MenuItems AS m WITH (NOLOCK)
				INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
				INNER JOIN dbo.N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
			WHERE m.MenuItemId = @MenuItemId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Get Environment before update
	DECLARE @EnvironmentOld VARCHAR(10)
		,@MenuItemNameOld NVARCHAR(50)

	SELECT @EnvironmentOld = Environment
		,@MenuItemNameOld = MenuItemName
	FROM dbo.N88_MenuItems WITH (NOLOCK)
	WHERE MenuItemId = @MenuItemId

	-- Update menu item information
	UPDATE dbo.N88_MenuItems WITH (ROWLOCK, UPDLOCK)
	SET FunctionId = @FunctionId
		,SiteId = @SiteId
		,MenuItemName = @MenuItemName
		,MenuItemKey = @MenuItemKey
		,[Description] = @Description
		,ParentId = @ParentId
		,ParentName = @ParentName
		,Policy = @Policy
		,URL = @URL
		,DisplayOrder = @DisplayOrder
		,IsActive = @IsActive
		,ModifiedBy = @ModifierId
		,ModifiedDate = @ModifiedDate
		,Environment = @Environment
	WHERE MenuItemId = @MenuItemId

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'Fail to update information of the MenuItemId ' + CONVERT(VARCHAR(10), @MenuItemId)

		RETURN
	END
	ELSE
	BEGIN
		DECLARE @MenuItemChild AS TABLE (MenuItemId INT)

		INSERT INTO @MenuItemChild (MenuItemId)
		SELECT c.MenuItemId
		FROM dbo.N88_MenuItems AS c WITH (NOLOCK)
		WHERE c.ParentId = @MenuItemId

		-- Check if Environment is change will be update all menu item child
		IF @EnvironmentOld <> @Environment
		BEGIN
			-- Update Environment of all menu item child
			UPDATE dbo.N88_MenuItems WITH (ROWLOCK, UPDLOCK)
			SET Environment = @Environment
			WHERE MenuItemId IN (SELECT MenuItemId FROM @MenuItemChild)
		END

		-- Check if MenuItemName is change will be update all ParentName of item child
		IF @MenuItemNameOld <> @MenuItemName
		BEGIN
			-- Update ParentName of all menu item child
			UPDATE dbo.N88_MenuItems WITH (ROWLOCK, UPDLOCK)
			SET ParentName = @MenuItemName
			WHERE MenuItemId IN (SELECT MenuItemId FROM @MenuItemChild)
		END
	END

	-- Write log after update
	SET @xml = (
			SELECT @MenuItemId AS '@mi'
				,@MenuItemName AS '@m'
				,@MenuItemKey AS '@mk'
				,@FunctionId AS '@fi'
				,f.FunctionName AS '@f'
				,@SiteId AS '@si'
				,s.SiteName AS '@s'
				,@Description AS '@d'
				,@ParentId AS '@pi'
				,@ParentName AS '@p'
				,@Policy AS '@pl'
				,@URL AS '@u'
				,@DisplayOrder AS '@o'
				,@IsActive AS '@i'
			FROM N88_MenuItems AS m WITH (NOLOCK)
				INNER JOIN N88_Functions AS f WITH (NOLOCK) ON m.FunctionId = f.FunctionId
				INNER JOIN N88_Sites AS s WITH (NOLOCK) ON f.SiteId = s.SiteId
			WHERE m.MenuItemId = @MenuItemId
			FOR XML PATH('r')
				,TYPE
			)
	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog @UserId = @CurrentUserId
		,@SPName = 'N88_MenuItem_Update'
		,@ObjectId = @MenuItemId
		,@ObjectTypeId = 5 -- Object type : menu item
		,@Language = @Language
		,@SiteID = @CurrentSiteId
		,@IP = @LoginIP
		,@Date = @LogDate
		,@Data = @logSPData
		,@OldData = @logSPDataOld
		,@Duration = @Duration
END
GO
