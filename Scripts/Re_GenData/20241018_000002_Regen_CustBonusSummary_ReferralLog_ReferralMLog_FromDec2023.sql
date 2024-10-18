/*<info serverAlias="DBN88-bodb_N88"></info>*/
/*	
	Created: 20241018@Sally
	DB: DBN88-bodb_N88
	Task: MPA - Repull data ReferralLog, ReferralMLog From Dec 2023 up to now
		- Step 2 : Re-sum N88_CustBonusSummary ReferralLog, ReferralMLog data From Dec 2023 up to now
*/
USE bodb_N88
GO
DECLARE @MinDate  DATE = '2023-12-01'
	,@MaxDate	  DATE = '2024-10-18'
	,@WinlostDate DATE
	,@DataSources VARCHAR(4000) = 'ReferralMLog,ReferralLog'

	SET @WinlostDate = @MinDate
	WHILE @WinlostDate <= @MaxDate
	BEGIN
		BEGIN
			EXEC dbo.Task_N88_CustBonusSummary @WinlostDate = @WinlostDate, @DataSources = @DataSources
		END
		PRINT @WinlostDate
		SET @WinlostDate = DATEADD(DAY, 1, @WinlostDate)
		WAITFOR DELAY '000:00:00.005'
	END
GO
