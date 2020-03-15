/*<info serverAlias="DBN88LOG-bodb_N88Log" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_LogRunSp_Insert]
	@UserId			INT,
	@SPName			NVARCHAR(50)	= NULL,
	@ObjectId		INT				= NULL,
	@ObjectTypeId	TINYINT			= NULL,
	@SiteId			TINYINT			= NULL,
	@IP				VARCHAR(50)		= NULL,
	@Date			DATETIME,
	@Data			NVARCHAR(MAX)	= NULL,
	@OldData		NVARCHAR(MAX)	= NULL,
	@Duration		INT				= NULL
AS

/*
	Created: 20200314@Kos
	Task: Insert new exec SP log
	DB: DBN88LOG.bodb_N88Log

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]

	Param's Explanation: 
		- @UserId: UserId perform this action  
		- @CustId:
		- @ActionId: Log action ID
		- @TrackingValue: XML string format
*/

BEGIN
	SET NOCOUNT ON

	IF @SPName LIKE '%_xtest'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 6)
	ELSE IF @SPName LIKE '%_xpre'
		OR @SPName LIKE '%_UAT1'
		OR @SPName LIKE '%_UAT2'
		OR @SPName LIKE '%_UAT3'
		OR @SPName LIKE '%_UAT4'
		SELECT @SPName = LEFT(@SPName, LEN(@SPName) - 5)

	DECLARE @ActionId SMALLINT

	SELECT @ActionId = ActionId
	FROM dbo.N88Log_Action WITH(NOLOCK)
	WHERE SPName = @SPName

	INSERT INTO dbo.N88Log_RUNSP (
		UserId,
		SPName,
		ActionId,
		ObjectId,
		ObjectTypeId,
		siteID,
		IP,
		LogDate,
		Duration)
	VALUES (
		@UserId,
		@SPName,
		@ActionId,
		@ObjectId,
		@ObjectTypeId,
		@SiteID,
		@IP,
		@Date,
		@Duration
	)

	IF @@ERROR = 0
	BEGIN
		INSERT INTO dbo.N88Log_RUNSP_Detail(ID, ActionID, Data, OldData)
		VALUES(@@IDENTITY, @actionid, @Data, @OldData)
	END
END
GO
