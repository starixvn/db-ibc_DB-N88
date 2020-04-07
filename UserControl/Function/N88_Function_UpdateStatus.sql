/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Function_UpdateStatus]
	@FunctionId		SMALLINT,
	@IsActive		BIT,
	@ModifiedBy		INT,
	@ModifiedDate	DATETIME,
	@CurrentUserId	INT,
	@CurrentSiteId	TINYINT,
	@LogDate		DATETIME,
	@LoginIP		VARCHAR(30)		=	'',
	@Language		VARCHAR(20)		=	'en-us',
	@ErrCode		INT				=	0			OUTPUT, 
	@ErrMsg			NVARCHAR(1000)	=	''			OUTPUT 
AS

/*
	Created: 20200314@Kos
	Task: Assign function to users
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		 
	Param's Explanation: 
	• Main	:	<root><xml path="r" />
					<row item="FunctionId" alias="fi" />
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

	-- write log before update
	SET @xml = (
		SELECT
			@FunctionId	AS '@fi',
			f.IsActive	AS '@i'
		FROM dbo.N88_Functions AS f WITH (NOLOCK)
		WHERE f.FunctionId =  @FunctionId
		FOR XML PATH('r'), TYPE
	)

	SET @logSPDataOld = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')

	-- Update status of function
	UPDATE dbo.N88_Functions WITH (ROWLOCK, UPDLOCK)
	SET
		IsActive		= @IsActive,
		ModifiedBy		= @ModifiedBy,
		ModifiedDate	= @ModifiedDate
	WHERE FunctionId	= @FunctionId

	IF @@ERROR > 0
	BEGIN
		SELECT
			@ErrCode	= 1,
			@ErrMsg		= 'Fail to update status of the FunctionId ' + CONVERT(VARCHAR(10), @FunctionId)
		RETURN
	END

	-- Write log after update
	SET @xml = (
		SELECT
			@FunctionId	AS '@fi',
			@IsActive	AS '@i'
		FOR XML PATH('r'), TYPE
	)

	SET @logSPData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"')
	SET @endRun		= GETDATE()
	SET @duration	= DATEDIFF(MILLISECOND, @startRun, @endRun)

	EXEC dbo.N88_RunSP_WriteLog
		@UserId			= @CurrentUserId,
		@SPName			= 'N88_Function_UpdateStatus',
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
