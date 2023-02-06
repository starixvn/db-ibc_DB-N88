/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE N88_MessageIns
	@MessageType	TINYINT
	,@LicenseeNames	VARCHAR(MAX)
	,@SubjectEn		NVARCHAR(300)	= NULL
	,@SubjectCs		NVARCHAR(300)	= NULL
	,@ContentEn		NVARCHAR(MAX)	= NULL
	,@ContentCs		NVARCHAR(MAX)	= NULL
	,@EventDate		DATETIME
AS
/*	
	Created by: Kai
	Task : Insert notification (#174308)
	DB: DBN88POL/N88_UserControl
	Revisions:
		- 20230117@Kai: Initial sp [RedmineID: #174308]

	Param's Explanation:
		@MessageType: 2 - Abnormal Bet
		@LicenseeNames: "N88,N8G"
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MessageID INT
	DECLARE @tblLicenseeName TABLE (LicenseeName VARCHAR(50))

	INSERT INTO @tblLicenseeName(LicenseeName)
	SELECT value 
	FROM STRING_SPLIT(@LicenseeNames, ',')
	WHERE value <> ''

	IF EXISTS (
		SELECT 1
		FROM [N88_Message] m WITH(NOLOCK)
		WHERE m.EventDate = @EventDate
			AND m.MessageType = @MessageType
	)
	BEGIN
		SELECT @MessageID = m.MessageID
		FROM [N88_Message] m WITH(NOLOCK)
		WHERE m.EventDate = @EventDate
			AND m.MessageType = @MessageType

		INSERT INTO [N88_MessageLicensee] (MessageID, LicenseeName)
		SELECT @MessageID, tbl.LicenseeName
		FROM @tblLicenseeName tbl
			LEFT JOIN [N88_MessageLicensee] ml WITH(NOLOCK)
				ON tbl.LicenseeName = ml.LicenseeName
		WHERE ml.MessageID = @MessageID
			AND ml.LicenseeName IS NULL
	END
	ELSE
	BEGIN
		INSERT INTO [N88_Message] (
			MessageType
			,SubjectEn
			,SubjectCs
			,ContentEn
			,ContentCs
			,EventDate
			,CreatedDate
		)
		VALUES (
			@MessageType
			,@SubjectEn
			,@SubjectCs
			,@ContentEn
			,@ContentCs
			,@EventDate
			,CURRENT_TIMESTAMP
		)
	
		SET @MessageID = SCOPE_IDENTITY()
	
		INSERT INTO [N88_MessageLicensee] (MessageID, LicenseeName)
		SELECT @MessageID, LicenseeName
		FROM @tblLicenseeName
	END
END
