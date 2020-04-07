/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_MenuItem_UpdateStatus]
	@MenuItemId		SMALLINT,
	@IsActive		BIT,
	@ModifiedBy		INT,
	@ModifiedDate	DATETIME,
	@CurrentUserId	INT,
	@CurrentSiteId	TINYINT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)			= '',
	@Language		VARCHAR(20)			= 'en-us',
	@ErrCode		INT					= 0			OUTPUT, 
	@ErrMsg			NVARCHAR(1000)		= ''		OUTPUT 
AS

/*  
	Created: 20200314@Kos
	Task: Update menu item status
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		• Main:
			<root><xml path="r" />
				<row item="MenuItemId" alias="mi" />
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

	-- Write log before update
	SET @xml = (
		SELECT
			@MenuItemId	AS '@mi',
			m.IsActive	AS '@i'
		FROM dbo.N88_MenuItems AS m WITH (NOLOCK)
		WHERE m.MenuItemId = @MenuItemId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Update menu item information
	UPDATE dbo.N88_MenuItems WITH (ROWLOCK, UPDLOCK)
	SET
		IsActive		= @IsActive,
		ModifiedBy		= @ModifiedBy,
		ModifiedDate	= @ModifiedDate
	WHERE MenuItemId = @MenuItemId

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode	= 1, 
			@ErrMsg		= 'Fail to update status of the MenuItemId ' + CONVERT(VARCHAR(10), @MenuItemId)
		RETURN
	END

	-- Write log after update
	SET @xml = (
		SELECT
			@MenuItemId	AS '@mi',
			@IsActive	AS '@i'
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_MenuItem_UpdateStatus',
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
