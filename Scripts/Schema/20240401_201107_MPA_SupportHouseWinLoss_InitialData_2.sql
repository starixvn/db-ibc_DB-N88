/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*	
	Created: 20240328@Sally
	Task: Support House Win Loss [RedmineID: #201107]
	DB: DBN88/bodb_N88
	- Initial Data
*/

/*Run ON DB052, DB053*/
USE bodb_N88
GO
SET IDENTITY_INSERT dbo.ReportSettingType ON
GO
INSERT INTO dbo.ReportSettingType ([ReportSettingTypeId], [Type], [SettingValue], [Description], [DisplayOrder])
VALUES ('1', 'DATAVIEW', 'FULL', 'View Full 100%', '1'),
       ('2', 'DATAVIEW', 'HOUSE', 'View House Sharing', '2'),
       ('3', 'DATAVIEW', 'SHAREHOLDER', 'View Shareholder Sharing', '3');
GO
SET IDENTITY_INSERT dbo.ReportSettingType OFF
GO

INSERT INTO dbo.ReportSetting ([ReportSettingTypeId], [SiteId], [CurrencyType], [CurrencyId], [PercentageValue], [FromDate], [ToDate])
VALUES ('2', '1', 'ID', '51', '0.7', '2019-01-01', '2999-12-31'),
       ('2', '1', 'OTHER', NULL, '1', '2019-01-01', '2999-12-31'),
       ('2', '2', 'OTHER', NULL, '0.3', '2019-01-01', '2999-12-31'),
       ('2', '3', 'OTHER', NULL, '0.3', '2019-01-01', '2999-12-31'),
       ('3', '1', 'ID', '51', '0.3', '2019-01-01', '2999-12-31'),
       ('3', '1', 'OTHER', NULL, '0', '2019-01-01', '2999-12-31'),
       ('3', '2', 'OTHER', NULL, '0.7', '2019-01-01', '2999-12-31'),
       ('3', '3', 'OTHER', NULL, '0.7', '2019-01-01', '2999-12-31'),
       ('1', '1', 'OTHER', NULL, '1', '2019-01-01', '2999-12-31'),
       ('1', '2', 'OTHER', NULL, '1', '2019-01-01', '2999-12-31'),
       ('1', '3', 'OTHER', NULL, '1', '2019-01-01', '2999-12-31');