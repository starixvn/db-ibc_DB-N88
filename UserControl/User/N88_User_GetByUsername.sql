/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_User_GetByUsername]
	@Username		NVARCHAR(50),
	@IsLicenseeSite	BIT = 0,
	@SiteId			TINYINT = NULL
AS

/*
	Created: 20200314@Kos
	Task: Get user by username
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20201118@Kos: Support default base currency [RedmineID: #145346]
*/

BEGIN
	SET NOCOUNT ON

	SELECT u.UserId
		,u.firstname
		,u.lastname
		,u.email
		,u.DefaultBaseCurrencyId
		,e.Code AS DefaultBaseCurrencyCode
		,u.username
		,u.userpwd
		,u.IsLicenseeUser
		,u.LastLoginDate
		,u.CreatedDate
		,u.ModifiedDate
		,g.GroupId
		,g.GroupName
		,ci1.UserId AS CreatorId
		,ci1.username AS CreatorUsername
		,ci2.UserId AS ModifierId
		,ci2.username AS ModifierUsername
	FROM dbo.N88_Users AS u WITH (NOLOCK)
		LEFT JOIN dbo.N88_UserSite us WITH (NOLOCK) ON u.UserId = us.UserId
		LEFT JOIN dbo.N88_Groups AS g WITH (NOLOCK) ON g.GroupId = u.GroupId
		LEFT JOIN dbo.N88_Users AS ci1 WITH (NOLOCK) ON u.CreatedBy = ci1.UserId
		LEFT JOIN dbo.N88_Users AS ci2 WITH (NOLOCK) ON u.ModifiedBy = ci2.UserId
		LEFT JOIN CustDB.dbo.exchange AS e WITH (NOLOCK) ON e.ExchangeId = u.DefaultBaseCurrencyId
	WHERE u.username = @Username
		AND (
			(
				@IsLicenseeSite = 1
				AND (
					(
						(
							us.SiteId = @SiteId
							AND us.IsActive = 1
							)
						)
					OR u.SourceSiteId = @SiteId
					)
				)
			OR (
				@IsLicenseeSite = 0
				AND ISNULL(u.IsLicenseeUser, 0) = @IsLicenseeSite
				)
			)
END
GO
