USE ContosoRetailDW

SELECT 'Online' AS canal, 
COUNT(*)               AS total_transacoes, 
SUM(SalesAmount)       AS faturamento_total, 
AVG(SalesAmount)       AS ticket_medio 
FROM FactOnlineSales 
UNION ALL 
SELECT c.ChannelName, 
COUNT(*)               AS total_transacoes, 
SUM(f.SalesAmount)     AS faturamento_total, 
AVG(f.SalesAmount)     AS ticket_medio 
FROM FactSales f 
JOIN DimChannel c ON c.ChannelKey = f.channelKey 
GROUP BY c.ChannelName 
ORDER BY faturamento_total DESC;