/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Site_InsertWithSiteURL]
	@SiteId				TINYINT						OUTPUT,
	@SiteName			VARCHAR(50),
	@Description		VARCHAR(200)	= NULL,
	@SiteURLs			VARCHAR(MAX)	= NULL,
	@IsActive			BIT,
	@Environment		VARCHAR(10),					-- Values: UAT | LIVE
	@CurrentUserId		INT,
	@CurrentSiteId		TINYINT,
	@SecretAccessKey	VARCHAR(200),
	@SiteKey			VARCHAR(50),
	@IsLicenseeSite		BIT = 0,
	@LogDate			DATETIME,
	@LoginIP			VARCHAR(30)		= '',
	@Language			VARCHAR(20)		= 'en-us',
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				NVARCHAR(1000)	= ''		OUTPUT
AS

/*
	Created: 20200314@Kos
	Task: Insert site with site URLs
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		
	Param's Explanation:
		+ Urls sample:
		<ROOT>
				<SiteURL
					URL="http://www.example.com/"
					Environment="LIVE"
					IsDefault="1"
					IsActive="1">
				</SiteURL>
			</ROOT>
		• @ErrCode	:
			= 0: super create master successfully.
			> 0: Specific Error.

		*** WRITE LOG template:
		Main: 
			<root><xml path="r" />
				<row item="SiteId" alias="si" />
				<row item="SiteName" alias="s" />
				<row item="Description" alias="d" />
				<row item="IsActive" alias="i" />
				<row item="Environment" alias="e" />
			</root>
		Sub: 
			<root><xml path="r/z" />
				<row item="SiteURLId" alias="si" />
				<row item="URL" alias="u" />
				<row item="Environment" alias="e" />
				<row item="IsDefault" alias="id" />
				<row item="IsActive" alias="ia" />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @startRun	DATETIME
		,@endRun		DATETIME
		,@duration		INT
		,@logSPData		NVARCHAR(MAX)
		,@logSPDataOld	NVARCHAR(MAX)
		,@xml			XML

	SET @startRun = GETDATE()

	-- Create site
	INSERT INTO dbo.N88_Sites (
		SiteName,
		Description,
		IsActive,
		IsLicenseeSite,
		Environment,
		SecretAccessKey,
		SiteKey)
	VALUES (
		@SiteName,
		@Description,
		@IsActive,
		@IsLicenseeSite,
		@Environment,
		@SecretAccessKey,
		@SiteKey)

	SET @SiteId = SCOPE_IDENTITY()

	IF @SiteId > 0
	BEGIN
		EXEC dbo.N88_Functions_GenerateN88Function @SiteId, @Environment

		-- assign portal admin is site admin in this site
		INSERT dbo.N88_UserSite (
			UserId,
			SiteId,
			Level,
			IsActive,
			LastLoginDate,
			CreatedBy,
			CreatedDate,
			ModifiedBy,
			ModifiedDate)
		SELECT DISTINCT 
			us.UserId,
			@SiteId,
			50,
			1,
			NULL,
			@CurrentUserId,
			@LogDate,
			@CurrentUserId,
			@LogDate
		FROM dbo.N88_UserSite AS us WITH (NOLOCK)
		WHERE
			us.Level = 100		-- Portal Admin
			AND SiteId = 1		-- N88 Admin Site ID

		-- Assign permission for site admin
		INSERT dbo.N88_UserFunction
		(
			UserId,
			FunctionId,
			SiteId,
			Policy,
			CreatedBy,
			CreatedDate,
			ModifiedBy,
			ModifiedDate
		)
		SELECT
			us.UserId,
			f.FunctionId,
			@SiteId,
			policy = CASE f.CRUD
				WHEN 0 THEN 1
				WHEN 1 THEN 2
			END,
			@CurrentUserId,
			@LogDate,
			@CurrentUserId,
			@LogDate
		FROM
			dbo.N88_UserSite AS us WITH (NOLOCK)
			INNER JOIN dbo.N88_Functions AS f WITH (NOLOCK) ON us.SiteId = f.SiteId
		WHERE
			us.SiteId = @SiteId AND us.[Level] IN (50, 100) -- Site admin: 50, Portal admin: 100
	END

	-- Insert site URL
	SET @xml = CONVERT(XML, @SiteURLs)

	INSERT dbo.N88_SiteURL (
		SiteId,
		URL,
		Environment,
		IsDefault,
		IsActive)
	SELECT
		@SiteId,
		T.C.value('./@URL', 'VARCHAR(100)'),
		T.C.value('./@Environment', 'VARCHAR(10)'),
		T.C.value('./@IsDefault', 'BIT'),
		T.C.value('./@IsActive', 'BIT')
	FROM @xml.nodes('/ROOT/SiteURL') AS [T](C) --T: table, C: column

	--#region Handles Errors and Logging
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1,
			@ErrMsg = 'Failed to insert site [SiteId = ' + COALESCE(CAST(@SiteId AS VARCHAR(10)), '') + ']'
		RETURN
	END

	-- Write log
	SET @xml = (
		SELECT
			@SiteId				AS '@si',
			@SiteName			AS '@s',
			@Description		AS '@d',
			@Environment		AS '@e',
			@IsActive			AS '@i',
			@IsLicenseeSite		AS '@il',
			@SecretAccessKey	AS '@sak',
			@SiteKey			AS '@sk',
			(
				SELECT
					su.SiteURLId	AS '@si',
					su.URL			AS '@u',
					su.Environment	AS '@e',
					su.IsDefault	AS '@id',
					su.IsActive		AS '@ia'
				FROM dbo.N88_SiteURL AS su WITH (NOLOCK)
				WHERE SiteId = @SiteId
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog 
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Site_InsertWithSiteURL',
		@ObjectId		= @SiteId,
		@ObjectTypeId	= 3,			--Object type : Site
		@Language		= @Language,
		@SiteID			= @CurrentSiteId,
		@IP				= @LoginIP,
		@Date			= @LogDate,
		@Data			= @logSPData,
		@OldData		= @logSPDataOld,
		@Duration		= @Duration
END
GO
