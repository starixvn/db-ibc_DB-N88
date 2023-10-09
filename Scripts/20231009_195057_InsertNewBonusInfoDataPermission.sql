/*<info serverAlias="DBN88POL-N88_UserControl"></info>*/

/*
	Created: 20231009@HOgan
	DB: DBN88POL.N88_UserControl
	Task: Add new function for Bonus Type [RedmineID: #195057]
*/

CREATE TABLE  #Site(SiteId int);
DECLARE @SiteId int,@FunctionId smallint,@FunctionName nvarchar(50)

INSERT INTO #Site
SELECT SiteId
FROM N88_Sites WITH (NOLOCK)
WHERE SiteName IN (SELECT * FROM STRING_SPLIT('N88 Admin,N8B Admin,N8G Admin',','))

WHILE EXISTS (SELECT * FROM #Site)
BEGIN

	SELECT TOP 1 @SiteId = SiteId
	FROM #Site

	SELECT @FunctionId = FunctionId,@FunctionName = FunctionName
	FROM N88_Functions WITH (NOLOCK)
	WHERE FunctionKey LIKE 'BonusInfoReport' AND SiteId = @SiteId

	IF @FunctionId IS NOT NULL
	BEGIN
		INSERT INTO dbo.N88_Functions (SiteId,FunctionName,FunctionKey,Description,ParentId,ParentName,CRUD,DisplayOrder,IsActive,CreatedDate,ModifiedDate,Environment)
		VALUES
		(@SiteId,'Bonus Type','BonusReport_BonusType','Bonus Report Bonus Type',@FunctionId,@FunctionName,0,1,1,GETDATE(),GETDATE(),'UAT')

		SET @FunctionId = SCOPE_IDENTITY()

		INSERT INTO dbo.N88_Functions (SiteId,FunctionName,FunctionKey,Description,ParentId,ParentName,CRUD,DisplayOrder,IsActive,CreatedDate,ModifiedDate,Environment
		)
		VALUES
		(@SiteId,'Welcome Bonus','BonusType_1','Bonus Type Welcome Bonus',@FunctionId,'Bonus Report Bonus Type',0,1,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'ReDeposit','BonusType_2','Bonus Type ReDeposit',@FunctionId,'Bonus Report Bonus Type',0,2,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'FreeBet','BonusType_3','Bonus Type FreeBet',@FunctionId,'Bonus Report Bonus Type',0,3,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Cashback','BonusType_7','Bonus Type Cashback',@FunctionId,'Bonus Report Bonus Type',0,7,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Manual Bonus','BonusType_8','Bonus Type Manual Bonus',@FunctionId,'Bonus Report Bonus Type',0,8,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Retention Free Bet','BonusType_9','Bonus Type Retention Free Bet',@FunctionId,'Bonus Report Bonus Type',0,9,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Unidentified','BonusType_0','Bonus Type Unidentified',@FunctionId,'Bonus Report Bonus Type',0,0,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Rebate','BonusType_6','Bonus Type Rebate',@FunctionId,'Bonus Report Bonus Type',0,6,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Others','BonusType_101','Bonus Type Others',@FunctionId,'Bonus Report Bonus Type',0,101,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Prize Draw','BonusType_102','Bonus Type Prize Draw',@FunctionId,'Bonus Report Bonus Type',0,102,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'VIP Upgrade','BonusType_103','Bonus Type VIP Upgrade',@FunctionId,'Bonus Report Bonus Type',0,103,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Verification Reward','BonusType_104','Bonus Type Verification Reward',@FunctionId,'Bonus Report Bonus Type',0,104,1,GETDATE(),GETDATE(),'UAT'),
		(@SiteId,'Referral','BonusType_105','Bonus Type Referral',@FunctionId,'Bonus Report Bonus Type',0,105,1,GETDATE(),GETDATE(),'UAT');
	END

	SET @FunctionId = NULL
	SET @FunctionName = NULL
	DELETE #Site
	WHERE SiteId = @SiteId

END
DROP TABLE #Site