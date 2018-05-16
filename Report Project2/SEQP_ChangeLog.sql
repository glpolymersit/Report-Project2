
CREATE PROCEDURE SEQP_ChangeLog
as

WITH cteOrderLineRel (Key2, OrderNum, OrderLine, RelNum)
AS 
(
	SELECT x.key2
,	 ( CASE WHEN  CHARINDEX('~',x.Key2)-1 > 0 THEN
	 SUBSTRING(x.Key2, 1, CHARINDEX('~',x.Key2)-1)
	 ELSE '' 
	 END) as OrderNum
	,(CASE WHEN LEN(x.Key2)-1 < CHARINDEX('~',x.Key2) + 2
		THEN
			CASE WHEN SUBSTRING(x.Key2,CHARINDEX('~',x.Key2)+2,1) <> '~' --this case required for order lines 10-99
				THEN
					SUBSTRING(x.Key2,CHARINDEX('~',x.Key2)+1, 2) 
				ELSE
					SUBSTRING(x.Key2,CHARINDEX('~',x.Key2)+1, 1)
			END
		ELSE
			CASE WHEN SUBSTRING(x.Key2,CHARINDEX('~',x.Key2)+2,1) <> '~' --this case required for order lines 10-99
			THEN
				SUBSTRING(x.Key2,CHARINDEX('~',x.Key2)+1, 2) 
			ELSE
				SUBSTRING(x.Key2,CHARINDEX('~',x.Key2)+1, 1)
			END
	END 
	) as OrderLine
	,( CASE 
	WHEN x.key2 like '%~%~%' THEN
		CASE WHEN SUBSTRING( x.Key2,LEN(x.key2)-2,1) = '~' THEN
		SUBSTRING( x.Key2,LEN(x.key2)-1,2)
		ELSE SUBSTRING( x.Key2,LEN(x.key2),1)
		END
	ELSE ''
	END
	) as RelNum
	From ChgLog x
	WHERE  x.key2 like '[0-9][0-9][0-9][0-9]%~%~%' or x.key2 like '[0-9][0-9][0-9][0-9]%~%'
	)

select c.Company
,  Key1 AS OrderNum
,(CASE WHEN LEN(c.Key2)-1 < CHARINDEX('~',c.Key2) + 2
		THEN
			CASE WHEN SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+2,1) <> '~' --this case required for order lines 10-99
				THEN
					SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 2) 
				ELSE
					SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 1)
			END
		ELSE
			CASE WHEN SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+2,1) <> '~' --this case required for order lines 10-99
			THEN
				SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 2) 
			ELSE
				SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 1)
			END
	END 
	) as orderLine
	,cte.RelNum as RelNum
,  c.TableName
,  CASE When c.TableName = 'orderdtl'
     THEN 'Line Change'
     ELSE 'Release Change'
   END  AS ChangeType
,  c.Key2 AS "Order-Lin-Rel"
,od.PartNum
, CAST(od.OrderQty as int) as OrderQty --for some reason wants to display as float even though it is int!  :-(
,CONVERT(VARCHAR, oh.OrderDate, 110) AS OrderDate	--Code 110 represents mm-dd-yyyy, get rid of the annoying 00:00:00
, orl.plant
,  CONVERT(VARCHAR, c.DateStamp, 110) AS ChangeDate   --Code 110 represents mm-dd-yyyy, get rid of the annoying 00:00:00
--, ' ' as NewPart
,(CASE WHEN c.LogText LIKE '%Part:%' THEN
	CASE WHEN c.LogText LIKE '%Quantity:%' or c.LogText LIKE '%Plant:%' THEN 'MULTI-See Log Text'
	ELSE   SUBSTRING(c.logtext,CHARINDEX('>',c.logtext)+1, LEN(c.logtext)-CHARINDEX('>', c.logtext ))
	END
	ELSE ' '
	END
	) as NewPart
--, ' ' as NewQty
,(CASE WHEN c.LogText LIKE '%Quantity:%'
	THEN SUBSTRING(c.logtext,CHARINDEX('>',c.logtext,PATINDEX('%Quantity:%',c.logtext))+1, 
		(CASE WHEN SUBSTRING(c.logtext, CHARINDEX('>', c.logtext,PATINDEX('%Quantity:%',c.logtext))+4,1) = char(32) THEN 3
			WHEN SUBSTRING(c.logtext, CHARINDEX('>', c.logtext,PATINDEX('%Quantity:%',c.logtext))+5,1) = char(32) THEN 4
			ELSE 5
			END ))
	ELSE ' '
	END
	) as NewQty
, CHARINDEX('>', c.logtext,PATINDEX('%Quantity:',c.logtext)) as test
--, ' ' as NewPlant
,(CASE WHEN c.LogText LIKE '%Plant:%'
	THEN --SUBSTRING(c.logtext,CHARINDEX('>',c.logtext)+1, 
		(CASE
			WHEN SUBSTRING(c.logtext, CHARINDEX('>', c.logtext)+2,2) = 'AC' THEN SUBSTRING(c.logtext,CHARINDEX('>',c.logtext)+1, 3)
			ELSE SUBSTRING(c.logtext,CHARINDEX('>',c.logtext)+1, 7)
			END )
	ELSE ' '
	END
	) as NewPlant
, ' ' as NewDate
,  LogText
from ChgLog c
JOIN OrderHed oh ON c.Company = oh.Company AND c.Key1 = oh.OrderNum
JOIN OrderDtl od ON c.Company = od.Company AND c.Key1=od.OrderNum 
JOIN OrderRel orl ON c.Company = orl.Company AND c.Key1=orl.OrderNum
JOIN cteOrderLineRel cte ON orl.OrderLine = cte.OrderLine AND orl.OrderNum = cte.OrderNum AND c.key2 = cte.Key2
where c.Company = 'CO1'
and Identifier = 'OrderHed'
--and TableName = 'OrderRel'
and DateStamp between GETDATE()-15 and GETDATE()-2
and LogText NOT Like '%New Record%'
and LogText NOT like '%Unit Price%'
AND (CASE WHEN LEN(c.Key2)-1 < CHARINDEX('~',c.Key2) + 2
		THEN
			CASE WHEN SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+2,1) <> '~' --this case required for order lines 10-99
				THEN
					SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 2) 
				ELSE
					SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 1)
			END
		ELSE
			CASE WHEN SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+2,1) <> '~' --this case required for order lines 10-99
			THEN
				SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 2) 
			ELSE
				SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 1)
			END
	END 
	)=od.OrderLine
	
	ORDER BY plant, OrderNum, ChangeDate DESC

	--, SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 1) AS LINE
--,SUBSTRING(c.Key2,CHARINDEX('~',c.Key2)+1, 1) AS TWO
--,LEN(c.Key2)-3 AS THREE
--,CHARINDEX('~',c.Key2) AS FOUR
