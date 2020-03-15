/*<info serverAlias="DBN88LOG-bodb_N88Log" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_LogUserLogin_Insert]
	@UserId			INT,
	@SiteId			TINYINT,
	@IP				VARCHAR(50),
	@LogDate		DATETIME,
	@Doing			VARCHAR(300)	= '',
	@DomainName		NVARCHAR(255)	= '',
	@BrowserName	NVARCHAR(255)	= '',
	@Platform		NVARCHAR(255)	= '',
	@CountryCode	VARCHAR(64)		= '',
	@Duration		INT				= NULL
AS

/*
	Created: 20200314@Kos
	Task: Insert new login log
	DB: DBN88LOG.bodb_N88Log

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.N88Log_UserLogin(
		UserId,
		SiteId,
		IP,
		LogDate,
		DomainName,
		BrowserName,
		Platform,
		CountryCode,
		Duration)
	VALUES (
		@UserId,
		@SiteId,
		@IP,
		@LogDate,
		@DomainName,
		@BrowserName,
		@Platform,
		@CountryCode,
		@Duration)
END
GO
