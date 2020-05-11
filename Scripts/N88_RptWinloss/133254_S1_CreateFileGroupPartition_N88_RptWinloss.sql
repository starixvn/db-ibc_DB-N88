/*	
	Created: 20200511@Sol
	Task: Get match that settled without ticket - [Redmine:#133254]
	DB: DBLIC/bodb_LicenseeReport
*/

USE bodb_LicenseeReport;

GO

-- add file group
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M05
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M06
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M07
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M08
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M09
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M010
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M011
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_20M012
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M01
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M02
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M03
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M04
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M05
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M06
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M07
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M08
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M09
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M010
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M011
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_21M012
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M01
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M02
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M03
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M04
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M05
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M06
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M07
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M08
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M09
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M010
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M011
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_22M012
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP N88_RptWinloss_MAX

GO

-- add file name
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M05 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M05.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_20M05]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M06 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M06.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_20M06]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M07 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M07.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_20M07]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M08 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M08.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_20M08]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M09 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M09.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_20M09]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M010, FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M010.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_20M010]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M011, FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M011.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_20M011]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_20M012, FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_20M012.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_20M012]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M01 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M01.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M01]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M02 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M02.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M02]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M03 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M03.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M03]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M04 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M04.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M04]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M05 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M05.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M05]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M06 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M06.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M06]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M07 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M07.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M07]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M08 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M08.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M08]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M09 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M09.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_21M09]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M010, FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M010.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_21M010]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M011, FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M011.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_21M011]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_21M012, FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_21M012.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_21M012]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M01 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M01.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M01]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M02 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M02.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M02]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M03 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M03.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M03]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M04 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M04.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M04]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M05 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M05.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M05]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M06 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M06.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M06]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M07 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M07.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M07]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M08 , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M08.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M08]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M09 , FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M09.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP  [N88_RptWinloss_22M09]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M010, FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M010.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_22M010]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M011, FILENAME = 'D:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M011.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_22M011]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_22M012, FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_22M012.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP [N88_RptWinloss_22M012]
ALTER DATABASE [bodb_LicenseeReport] ADD FILE (NAME = N88_RptWinloss_MAX   , FILENAME = 'E:\IBC_DB\bodb_licenseeReport\N88_RptWinloss\N88_RptWinloss_MAX.ndf', SIZE = 3072 KB, MAXSIZE = UNLIMITED, FILEGROWTH = 1024 KB) TO FILEGROUP    [N88_RptWinloss_MAX]

GO

-- Create partition function
CREATE PARTITION FUNCTION [pf_N88_rptWinloss_monthly](DATE) AS 
RANGE LEFT FOR VALUES 
(
    N'2020-05-31',
    N'2020-06-30',
    N'2020-07-31',
    N'2020-08-31',
    N'2020-09-30',
    N'2020-10-31',
    N'2020-11-30',
    N'2020-12-31',
    N'2021-01-31',
    N'2021-02-28',
    N'2021-03-31',
    N'2021-04-30',
    N'2021-05-31',
    N'2021-06-30',
    N'2021-07-31',
    N'2021-08-31',
    N'2021-09-30',
    N'2021-10-31',
    N'2021-11-30',
    N'2021-12-31',
    N'2022-01-31',
    N'2022-02-28',
    N'2022-03-31',
    N'2022-04-30',
    N'2022-05-31',
    N'2022-06-30',
    N'2022-07-31',
    N'2022-08-31',
    N'2022-09-30',
    N'2022-10-31',
    N'2022-11-30',
    N'2022-12-31'
)

GO

-- create partition schema
CREATE PARTITION SCHEME [ps_N88_rptWinloss_monthly] AS PARTITION [pf_N88_rptWinloss_monthly] TO 
(
    N88_RptWinloss_20M05 ,
    N88_RptWinloss_20M06,
    N88_RptWinloss_20M07,
    N88_RptWinloss_20M08,
    N88_RptWinloss_20M09,
    N88_RptWinloss_20M010,
    N88_RptWinloss_20M011,
    N88_RptWinloss_20M012,
    N88_RptWinloss_21M01,
    N88_RptWinloss_21M02,
    N88_RptWinloss_21M03,
    N88_RptWinloss_21M04,
    N88_RptWinloss_21M05,
    N88_RptWinloss_21M06,
    N88_RptWinloss_21M07,
    N88_RptWinloss_21M08,
    N88_RptWinloss_21M09,
    N88_RptWinloss_21M010,
    N88_RptWinloss_21M011,
    N88_RptWinloss_21M012,
    N88_RptWinloss_22M01,
    N88_RptWinloss_22M02,
    N88_RptWinloss_22M03,
    N88_RptWinloss_22M04,
    N88_RptWinloss_22M05,
    N88_RptWinloss_22M06,
    N88_RptWinloss_22M07,
    N88_RptWinloss_22M08,
    N88_RptWinloss_22M09,
    N88_RptWinloss_22M010,
    N88_RptWinloss_22M011,
    N88_RptWinloss_22M012,
    N88_RptWinloss_MAX
)

GO
