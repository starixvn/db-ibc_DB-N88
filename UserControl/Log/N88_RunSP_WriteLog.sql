/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_RunSP_WriteLog]
	@UserId			INT,
	@SPName			NVARCHAR(50)	= NULL,
	@ObjectId		INT				= NULL,
	@ObjectTypeId	TINYINT			= NULL,
	@Language		VARCHAR(20)		= NULL,
	@SiteId			TINYINT			= NULL,
	@IP				VARCHAR(50)		= NULL,
	@Date			DATETIME,
	@Data			NVARCHAR(MAX)	= NULL,
	@OldData		NVARCHAR(MAX)	= NULL,
	@Duration		INT				= NULL  
AS

/*
	Created: 20200314@Kos
	Task: Write exec SP log
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		EXEC DBN88LOG.bodb_N88LOG.dbo.N88_LogRunSp_Insert 
			@UserId			= @UserId,
			@SPName			= @SPName,
			@ObjectId		= @ObjectId,
			@ObjectTypeId	= @ObjectTypeId,
			@SiteId			= @SiteId,
			@IP				= @IP,
			@Date			= @Date,
			@Data			= @Data,
			@OldData		= @OldData,
			@Duration		= @Duration
	END TRY
	BEGIN CATCH
		
	END CATCH
END
GO
