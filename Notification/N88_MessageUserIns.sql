/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE N88_MessageUserIns
	@MessageId		INT
	,@UserName		NVARCHAR(50)
	,@LicenseeName  VARCHAR(50)
AS
/*	
	Created by: Kai
	Task : Mark as read notification (#174308)
	DB: DBN88POL/N88_UserControl
	Revisions:
		- 20230117@Kai: Initial sp [RedmineID: #174308]
*/
BEGIN

	SET NOCOUNT ON
 
	IF NOT EXISTS (
		SELECT 1
		FROM [N88_MessageUser] WITH(NOLOCK)
		WHERE MessageID = @MessageId
			AND UserName = @UserName
			AND LicenseeName = @LicenseeName
	)
	BEGIN
		INSERT INTO [N88_MessageUser] (
			MessageID
			,UserName
			,LicenseeName
			,IsRead
			,UpdatedDate
		)
		VALUES (
			@MessageID
			,@UserName
			,@LicenseeName
			,1
			,CURRENT_TIMESTAMP
		)
	END
	
END
GO
