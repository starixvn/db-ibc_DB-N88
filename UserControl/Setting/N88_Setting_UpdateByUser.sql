/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Setting_UpdateByUser]
	@UserId			INT
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
	Created: 20230626@Hogan
	Task: Update settings by user
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20230626@Hogan: Created [RedmineID: #189299]
		
	Param's Explanation:
		- Value : '<ROOT><UserSetting SettingKey="LimitDays" SettingValue="90" ></UserSetting></ROOT>'
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
		SettingKey	NVARCHAR(50),
		SettingValue	NVARCHAR(255),
		UserId	INT
	)

	INSERT INTO #TempData (SettingKey, SettingValue, UserId)
	SELECT SettingKey, SettingValue, UserId
	FROM dbo.N88_UserSetting WITH (NOLOCK)
	WHERE UserId = @UserId

	-- Write log before update setting of user
	SET @xml = (
		SELECT
			@UserId	AS '@u',
			(
				SELECT
					SettingKey	AS '@k'
					,SettingValue	AS '@v'
				FROM #TempData
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	DECLARE @TableSetting TABLE(SettingKey	NVARCHAR(50), SettingValue	NVARCHAR(255))

	SET @xml = CONVERT(XML, @Value)
	INSERT INTO @TableSetting(SettingKey, SettingValue)
	SELECT	T.C.value('./@SettingKey', 'NVARCHAR(50)')
			,T.C.value('./@SettingValue', 'NVARCHAR(255)')
	FROM @xml.nodes('/ROOT/UserSetting') as [T](C) --T: table, C: column

	-- Update setting of user
	UPDATE dbo.N88_UserSetting WITH (ROWLOCK, UPDLOCK)
	SET SettingValue	=	Temp.SettingValue
		,ModifiedBy		=	@ModifiedBy
		,ModifiedDate	=	@ModifiedDate
	FROM @TableSetting AS Temp
	WHERE dbo.N88_UserSetting.UserId = @UserId AND dbo.N88_UserSetting.SettingKey = Temp.SettingKey

	-- Insert new setting of user
	INSERT INTO dbo.N88_UserSetting (
		UserId
		,SettingKey
		,SettingValue
		,CreatedBy
		,CreatedDate
		,ModifiedBy
		,ModifiedDate
	)
	SELECT
		@UserId
		,Temp.SettingKey
		,Temp.SettingValue
		,@ModifiedBy
		,@ModifiedDate
		,@ModifiedBy
		,@ModifiedDate
	FROM @TableSetting AS Temp
	WHERE NOT EXISTS (	SELECT TOP(1) *
						FROM dbo.N88_UserSetting AS us WITH(NOLOCK)
						WHERE us.UserId = @UserId AND us.SettingKey = Temp.SettingKey )

	DELETE us WITH (ROWLOCK)
	FROM N88_UserSetting us
	WHERE us.UserId = @UserId AND us.SettingKey NOT IN ( SELECT SettingKey FROM @TableSetting )

	-- Check error
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 1,
			@ErrMsg = 'Fail to update setting of UserId '+ CONVERT(VARCHAR(10), @UserId)
		RETURN
	END

	-- write log after update
	SET @xml = (
		SELECT
			@UserId	AS '@u',
			(
				SELECT
					SettingKey	AS '@k'
					,SettingValue	AS '@v'
				FROM dbo.N88_UserSetting us WITH(NOLOCK)
				WHERE us.UserId = @UserId
				FOR XML PATH('z'), TYPE
			)
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData	= REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun		= GETDATE()
	SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		 @UserId		= @CurrentUserId,
		 @SPName		= 'N88_Setting_UpdateByUser',
		 @ObjectId		= @UserId,
		 @ObjectTypeId	= 1, --Object type : User
		 @Language		= @Language,
		 @SiteID		= @CurrentSiteId,
		 @IP			= @LoginIP,
		 @Date			= @LogDate,
		 @Data			= @logSPData,
		 @OldData		= @logSPDataOld,
		 @Duration		= @Duration

	DROP TABLE #TempData
END
GO