/*<info serverAlias="DBN88-bodb_N88"></info>*/
USE bodb_N88
GO

/*
	Created: 20200520@Percy
	DB: DBN88-bodb_N88
	Task: New table for N88
*/

CREATE TABLE dbo.ServerInfo
(
	SiteId			INT NOT NULL
	,SiteName		VARCHAR(50)
	,LicenseeName	VARCHAR(50)
	,LangList		NVARCHAR(MAX)
	,CurrencyList	NVARCHAR(MAX)
	,DefLang		VARCHAR(4)
	,DefCurrency	INT
	,CONSTRAINT PK_ServerInfo PRIMARY KEY CLUSTERED
	(
		SiteId
	) ON [SettingData]
) ON [SettingData]
GO

CREATE TABLE [dbo].[TpGameType]
(
	Type		INT NOT NULL
	,TypeName	VARCHAR(45)
	,CONSTRAINT [PK_TpGameType] PRIMARY KEY CLUSTERED 
	(
		Type
	) ON [SettingData]
) ON [SettingData]
GO

CREATE TABLE dbo.TpBetRecord
(
	TpId			INT NOT NULL
	,TransId		VARCHAR(50) NOT NULL
	,GameType		INT NOT NULL
	,CustId			VARCHAR(45) NOT NULL
	,UserName		VARCHAR(30) NOT NULL
	,CurrencyId		INT NOT NULL
	,SiteId			INT NOT NULL
	,TpUserName		VARCHAR(50) NOT NULL
	,TransTime		DATETIME NOT NULL
	,SettledTime	DATETIME NOT NULL
	,Stake			DECIMAL(18, 2) NOT NULL
	,WinlostAmount	DECIMAL(18, 2) NOT NULL
	,SettlementType TINYINT NOT NULL
	,TicketStatus	TINYINT NOT NULL
	,OriginalState	VARCHAR(10)
	,TicketKey		BIGINT NOT NULL
	,CreateTime		DATETIME NOT NULL
	,WinlostDate	SMALLDATETIME
	,CONSTRAINT PK_TpBetRecord PRIMARY KEY CLUSTERED 
	(
		TpId
		,TransId
		,GameType
	) ON [ReportData]
) ON [ReportData]
GO

CREATE TABLE dbo.Customer
(
	CustId			INT NOT NULL
	,SiteId			INT NOT NULL
	,UserName		VARCHAR(30)
	,CurrencyId		TINYINT
	,UserLang		VARCHAR(4)
	,ActStatus		TINYINT
	,AgentId		INT
	,AllAgentId		NVARCHAR(MAX)
	,UserLevel		TINYINT
	,RegTime		DATETIME
	,IsTest			TINYINT
	,Status			TINYINT
	,CONSTRAINT PK_Customer PRIMARY KEY CLUSTERED
	(
		CustId
	) ON [SettingData]
) ON [SettingData]
GO

CREATE TABLE dbo.API_Queue
(
	QueueId			BIGINT NOT NULL IDENTITY(1,1)
	,CheckInTime	DATETIME CONSTRAINT DF_API_Queue_CheckInTime DEFAULT (GETDATE())
	,FinishedTime	DATETIME
	,IsFinished		BIT CONSTRAINT DF_API_Queue_IsFinished DEFAULT ((0))
	,XmlData		XML
	,DataSource		VARCHAR(200)		
	,LogDesc		VARCHAR(2000)
	,CONSTRAINT PK_API_Queue PRIMARY KEY NONCLUSTERED
	(
		QueueId
	) ON [ReportData]
) ON [ReportData]
GO

CREATE CLUSTERED INDEX CIX_DataSource ON dbo.API_Queue (DataSource, IsFinished)
GO

CREATE TABLE dbo.API_TimeTracker
(
	Id			BIGINT NOT NULL IDENTITY(1,1)
	,DataSource	VARCHAR(200)
	,CalledTime	DATETIME
	,CONSTRAINT PK_API_TimeTracker PRIMARY KEY NONCLUSTERED
	(
		Id
	) ON [ReportData]
) ON [ReportData]
GO

CREATE CLUSTERED INDEX CIX_DataSource ON dbo.API_TimeTracker (DataSource, CalledTime)
GO