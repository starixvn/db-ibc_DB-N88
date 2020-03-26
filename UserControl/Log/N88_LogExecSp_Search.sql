/*<info serverAlias="DBN88LOG-bodb_N88Log" executers="bodbAdminNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[N88_LogExecSp_Search]
	@Username		NVARCHAR(50)	= ''
	,@Name			NVARCHAR(50)	= ''
	,@FilterType	INT
	,@SiteId	TINYINT				= NULL
	,@From			DATETIME
	,@To			DATETIME
	,@PageIndex		INT
	,@PageSize		INT
	,@TotalRows		INT				= 0	OUTPUT	
AS

/*
	Created: 20200314@Kos
	Task: Search exec SP log
	DB: DBN88LOG.bodb_N88Log

	Revisions:
		- 20200314@Kos: Created [RedmineID: #129873]
		- 20200326@Scofield: Add param SiteId [RedmineID: #129873]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FirstRec	INT,
		@LastRec		INT

	SELECT @FirstRec = ((@PageIndex - 1) * @PageSize) + 1
	SELECT @LastRec = ((@PageIndex * @PageSize + 1)) - 1

	IF @FilterType = 1	-- User
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM
				dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 1 -- Object type : User
				AND u.username LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND (@SiteId IS NULL OR lg.siteID = @SiteId)
		)

		SET @TotalRows += (
			SELECT COUNT(1)
			FROM 
				dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
			WHERE 
				lg.ObjectTypeId = 1 -- Object type : User
				AND lg.LogDate BETWEEN @From AND @To
				AND lg.SPName LIKE 'Task%'
				AND u.username LIKE '%' + @Name + '%'
				AND (@Username LIKE 'sys%' OR @Username = '')
				AND (@SiteId IS NULL OR lg.siteID = @SiteId)
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT
					SubTemp.Id
					,SubTemp.LogDate
					,SubTemp.Name
					,SubTemp.Modifier 
					,SubTemp.ActionId
					,SubTemp.ActionName
					,ROW_NUMBER() OVER (ORDER BY SubTemp.LogDate DESC) AS num
				FROM (
					SELECT 
						lg.Id,
						lg.LogDate,
						u.username AS Name,
						cu1.username AS Modifier,
						la.ActionId,
						la.ActionName
					FROM 
						dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
						INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
						INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
						INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
					WHERE 
						lg.ObjectTypeId = 1
						AND u.username LIKE '%' + @Name + '%'
						AND lg.LogDate BETWEEN @From AND @To
						AND cu1.username LIKE '%' + @Username + '%'
						AND (@SiteId IS NULL OR lg.siteID = @SiteId)
					UNION
					SELECT
						lg.Id,
						lg.LogDate,
						u.username AS Name,
						'System' AS Modifier,
						la.ActionId,
						la.ActionName
					FROM 
						dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
						INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
						INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS u WITH (NOLOCK) ON lg.ObjectId = u.UserId
					WHERE 
						lg.ObjectTypeId = 1
						AND lg.LogDate BETWEEN @From AND @To
						AND lg.SPName LIKE 'Task%'
						AND u.username LIKE '%' + @Name + '%'
						AND (@Username LIKE 'sys%' OR @Username = '')
						AND (@SiteId IS NULL OR lg.siteID = @SiteId)
					) AS SubTemp
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END

	IF @FilterType = 2 -- Group
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				dbo.N88Log_RUNSP AS lg WITH(NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Groups AS g WITH(NOLOCK) ON lg.ObjectId = g.GroupId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH(NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH(NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 2
				AND g.GroupName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND (@SiteId IS NULL OR lg.siteID = @SiteId)
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					g.GroupName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					dbo.N88Log_RUNSP AS lg WITH(NOLOCK)
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Groups AS g WITH(NOLOCK) ON lg.ObjectId = g.GroupId
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH(NOLOCK) ON lg.UserId = cu1.UserId
					INNER JOIN dbo.N88Log_Action AS la WITH(NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 2
					AND g.GroupName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
					AND (@SiteId IS NULL OR lg.siteID = @SiteId)
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END

	IF @FilterType = 3 -- Site
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Sites AS s WITH (NOLOCK) ON lg.ObjectId = s.SiteId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 3
				AND s.SiteName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND (@SiteId IS NULL OR lg.siteID = @SiteId)
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					s.SiteName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Sites AS s WITH (NOLOCK) ON lg.ObjectId = s.SiteId
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
					INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 3
					AND s.SiteName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
					AND (@SiteId IS NULL OR lg.siteID = @SiteId)
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END

	IF @FilterType = 4	-- Function
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Functions AS f WITH (NOLOCK) ON lg.ObjectId = f.FunctionId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 4
				AND f.FunctionName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND (@SiteId IS NULL OR lg.siteID = @SiteId)
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					f.FunctionName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Functions AS f WITH (NOLOCK) ON lg.ObjectId = f.FunctionId
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
					INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 4 -- Object type : Function
					AND f.FunctionName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
					AND (@SiteId IS NULL OR lg.siteID = @SiteId)
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END

	IF @FilterType = 5 -- Menu item
	BEGIN
		-- gets total rows
		SET @TotalRows = (
			SELECT COUNT(1)
			FROM 
				dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_MenuItems AS m WITH (NOLOCK) ON lg.ObjectId = m.MenuItemId
				INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
				INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
			WHERE 
				lg.ObjectTypeId = 5
				AND m.MenuItemName LIKE '%' + @Name + '%'
				AND lg.LogDate BETWEEN @From AND @To
				AND cu1.username LIKE '%' + @Username + '%'
				AND (@SiteId IS NULL OR lg.siteID = @SiteId)
		)

		-- gets data
		SELECT TOP (@PageSize) *
		FROM (
				SELECT 
					lg.Id,
					lg.LogDate,
					m.MenuItemName AS Name,
					cu1.username AS Modifier,
					la.ActionId,
					la.ActionName,
					ROW_NUMBER() OVER (ORDER BY lg.LogDate DESC) AS num
				FROM 
					dbo.N88Log_RUNSP AS lg WITH (NOLOCK)
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_MenuItems AS m WITH (NOLOCK) ON lg.ObjectId = m.MenuItemId
					INNER JOIN DBN88POL.N88_UserControl.dbo.N88_Users AS cu1 WITH (NOLOCK) ON lg.UserId = cu1.UserId
					INNER JOIN dbo.N88Log_Action AS la WITH (NOLOCK) ON lg.ActionId = la.ActionId
				WHERE 
					lg.ObjectTypeId = 5 -- Object type : menu item
					AND m.MenuItemName LIKE '%' + @Name + '%'
					AND lg.LogDate BETWEEN @From AND @To
					AND cu1.username LIKE '%' + @Username + '%'
					AND (@SiteId IS NULL OR lg.siteID = @SiteId)
			) AS Temp
		WHERE Temp.num BETWEEN @FirstRec AND @LastRec
		ORDER BY Temp.num ASC
	END
END
GO