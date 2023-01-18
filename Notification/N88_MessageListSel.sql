/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE N88_MessageListSel
	@UserName		NVARCHAR(50)
	,@LicenseeName	VARCHAR(50)
	,@MessageTypes	VARCHAR(50)
	,@FromDate		DATETIME
	,@ToDate		DATETIME
AS
/*	
	Created by: Kai
	Task : Get notification by MessageTypes (#174308)
	DB: DBN88POL/N88_UserControl
	Revisions:
		- 20230117@Kai: Initial sp [RedmineID: #174308]

	Param's Explanation:
		@MessageTypes: "2,3,..." - 2: Abnormal Bet 
*/
BEGIN
	SET NOCOUNT ON

	SELECT	m.MessageID
			,m.MessageType
			,m.SubjectEn
			,m.SubjectCs
			,m.ContentEn
			,m.ContentCs
			,m.EventDate
	FROM [N88_Message] m WITH(NOLOCK)
		INNER JOIN [N88_MessageLicensee] ml WITH(NOLOCK)
			ON m.MessageID = ml.MessageID
		LEFT JOIN [N88_MessageUser] mu WITH(NOLOCK)
			ON m.MessageID = mu.MessageID
				AND mu.UserName = @UserName
				AND mu.LicenseeName = @LicenseeName
	WHERE ml.LicenseeName = @LicenseeName
		AND m.MessageType IN (SELECT value FROM STRING_SPLIT(@MessageTypes, ','))
		AND (m.EventDate BETWEEN @FromDate AND @ToDate)
		AND (mu.IsRead IS NULL OR mu.IsRead = 0)

END
GO
