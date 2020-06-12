/*<info serverAlias="DBN88-bodb_N88" isFunction="0" isNested=""></info>*/
/*
Created: 20200527@Sol
Task: Generate data for past months [Redmine: #133254]
DB: DBN88-bodb_N88
*/

USE bodb_N88

GO 

UPDATE dbo.N88_RptWinloss
	SET TurnOver = TurnOver/1000,
		Winloss = Winloss/1000
WHERE Currency = 51

GO