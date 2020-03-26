ALTER PROCEDURE [dbo].[N88_User_GetUserByFunctionAndSite] @FunctionId INT, 
                                                          @SiteId     INT = 0
AS

/*  
 * Created: 20120820@Edward
 * Task : Get all user
 * DB: DBPOL-N88_UserControl
 *  
 * Revisions:
- 20180925@Helen: DB052.bodb_N88 Migration to DBCust - [Redmine:100493]
- 20190913@Jacob: Support remove all permission on function - [Redmine:120213]	     
 * Param's Explanation: 
*/

     SET NOCOUNT ON;
     SELECT uf.Policy, 
            u.UserId, 
            u.firstname, 
            u.lastname, 
            u.email, 
            u.username, 
            u.userpwd, 
            u.LastLoginDate, 
            u.CreatedDate, 
            u.ModifiedDate, 
            g.GroupId, 
            g.GroupName, 
            ci1.UserId AS CreatorId, 
            ci1.username AS CreatorUsername, 
            ci2.UserId AS ModifierId, 
            ci2.username AS ModifierUsername, 
            uf.CreatedBy AS CreatorIdUserFunction, 
            ci3.username AS CreatorUsernameUserFunction, 
            uf.ModifiedBy AS ModifierIdUserFunction, 
            ci4.username AS ModifierUsernameUserFunction, 
            uf.CreatedDate AS CreatedDateUserFunction, 
            uf.ModifiedDate AS ModifiedDateUserFunction
     FROM dbo.N88_Users AS u WITH(NOLOCK)
          LEFT JOIN dbo.N88_Groups AS g WITH(NOLOCK) ON g.GroupId = u.GroupId
          LEFT JOIN dbo.N88_Users AS ci1 WITH(NOLOCK) ON u.CreatedBy = ci1.UserId
          LEFT JOIN dbo.N88_Users AS ci2 WITH(NOLOCK) ON u.ModifiedBy = ci2.UserId
          INNER JOIN dbo.N88_UserFunction AS uf WITH(NOLOCK) ON u.UserId = uf.UserId
          LEFT JOIN dbo.N88_Users AS ci3 WITH(NOLOCK) ON uf.CreatedBy = ci3.UserId
          LEFT JOIN dbo.N88_Users AS ci4 WITH(NOLOCK) ON uf.ModifiedBy = ci4.UserId
     WHERE uf.FunctionId = @FunctionId
           AND uf.Policy > 0;