USE ContosoRetailDW

SELECT 'Online' AS Canal,
COUNT(*)   AS Total_transações,
SUM(fo.SalesAmount)   AS Faturamento_total,
AVG(fo.SalesAmount)   As Ticket_Médio
FROM FactOnlineSales fo
UNION ALL
SELECT c.ChannelName,
COUNT(*)   AS Total_transações,
SUM(f.SalesAmount)   AS Faturamento_total,
AVG(f.SalesAmount)   As Ticket_Médio
FROM FactSales f
JOIN DimChannel c ON c.ChannelKey = f.channelKey
GROUP BY c.ChannelName
ORDER BY Faturamento_total DESC;
