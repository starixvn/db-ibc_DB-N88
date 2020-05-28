/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*
Created: 20200528@Sol
Task: Re - Generate data for past months [Redmine: #133254]
DB: DBN88-bodb_N88
*/

USE bodb_N88

GO 

TRUNCATE TABLE N88_RptWinloss

GO

DECLARE @s DATE 
DECLARE cur CURSOR FOR 
SELECT DISTINCT CAST(SettledTime AS DATE) FROM dbo.TpBetRecord WITH(NOLOCK)
ORDER BY CAST(SettledTime AS DATE)
OPEN cur 

FETCH NEXT FROM cur INTO @s

WHILE @@FETCH_STATUS = 0
BEGIN

	PRINT @s
	EXEC dbo.Task_N88_ImportData_3rdProducts @WinlostDate = @s

	FETCH NEXT FROM cur INTO @s

END

CLOSE cur;  
DEALLOCATE cur; 

GO