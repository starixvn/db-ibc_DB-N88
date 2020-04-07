/*<info serverAlias="DBN88POL-N88_UserControl" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_Functions_GenerateN88Function]
	@SiteId			TINYINT,
	@Environment	VARCHAR(10)
AS

/*
	Created: 20200314@Kos
	Task: Generate system functions
	DB: DBN88POL.N88_UserControl

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @SystemConfigurationId SMALLINT
	DECLARE @AdministrationId INT
	DECLARE @ManageUserId INT
	DECLARE @ManageGroupId INT

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'System Configuration', N'SystemConfiguration', N'System Configuration', NULL, NULL, 0, 1, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	SET @SystemConfigurationId = SCOPE_IDENTITY()

--	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
--	VALUES (@SiteId, N'Manage Site', N'ManageSite', N'Manage Site', @SystemConfigurationId, N'System Configuration', 1, 1, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)
	
	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Manage Function', N'ManageFunction', N'Manage Function', @SystemConfigurationId, N'System Configuration', 1, 2, 1, NULL, GETDATE(), NULL,  GETDATE(), @Environment)

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Manage Menu', N'ManageMenu', N'Manage Menu', @SystemConfigurationId, N'System Configuration', 1, 3, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Administration', N'Administration', N'Administration', NULL, NULL, 0, 2, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	SET @AdministrationId = SCOPE_IDENTITY()

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Manage User', N'ManageUser', N'Manage User', @AdministrationId, N'Administration', 1, 1, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	SET @ManageUserId = SCOPE_IDENTITY()

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Assign Site To User', N'AssignSiteToUser', N'Assign Site To User', @ManageUserId, N'Manage User', 1, 1, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Assign Function To User', N'AssignFunctionToUser', N'Assign Function To User', @ManageUserId, N'Manage User', 1, 2, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Manage Group', N'ManageGroup', N'Manage Group', @AdministrationId, N'Administrator', 1, 2, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)

	SET @ManageGroupId = SCOPE_IDENTITY()

	INSERT dbo.N88_Functions (SiteId, FunctionName, FunctionKey, Description, ParentId, ParentName, CRUD, DisplayOrder, IsActive, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Environment) 
	VALUES (@SiteId, N'Assign Function To Group', N'AssignFunctionToGroup', N'Assign Function To Group', @ManageGroupId, N'Manage Group', 1, 1, 1, NULL, GETDATE(), NULL, GETDATE(), @Environment)
END
GO
