USE [AdventureWorks2012];
GO

-- 1. Create Pareto ABC Analysis View
IF OBJECT_ID('gold.vw_Product_ABC_Analysis', 'V') IS NOT NULL DROP VIEW gold.vw_Product_ABC_Analysis;
GO
CREATE VIEW gold.vw_Product_ABC_Analysis AS
WITH ProductSales AS (
    SELECT 
        p.ProductSK,
        p.ProductName,
        p.CategoryName,
        SUM(f.LineTotal) AS TotalRevenue
    FROM gold.Fact_Sales f
    JOIN gold.Dim_Product p ON f.ProductSK = p.ProductSK
    GROUP BY p.ProductSK, p.ProductName, p.CategoryName
),
CumulativeSales AS (
    SELECT 
        *,
        SUM(TotalRevenue) OVER (ORDER BY TotalRevenue DESC) AS RunningTotal,
        SUM(TotalRevenue) OVER () AS OverallTotal
    FROM ProductSales
)
SELECT 
    ProductSK,
    ProductName,
    CategoryName,
    TotalRevenue,
    (RunningTotal / OverallTotal) * 100 AS CumulativePercentage,
    CASE 
        WHEN (RunningTotal / OverallTotal) <= 0.80 THEN 'A'
        WHEN (RunningTotal / OverallTotal) <= 0.95 THEN 'B'
        ELSE 'C'
    END AS ABC_Class
FROM CumulativeSales;
GO

-- 2. Performance Tuning Indexes for Gold Schema
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_OrderDateKey')
    CREATE INDEX IX_FactSales_OrderDateKey ON gold.Fact_Sales(OrderDateKey);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_CustomerSK')
    CREATE INDEX IX_FactSales_CustomerSK ON gold.Fact_Sales(CustomerSK);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_ProductSK')
    CREATE INDEX IX_FactSales_ProductSK ON gold.Fact_Sales(ProductSK);
GO

-- Verification Check
SELECT ABC_Class, COUNT(*) AS ProductCount, SUM(TotalRevenue) AS CategoryRevenue 
FROM gold.vw_Product_ABC_Analysis
GROUP BY ABC_Class
ORDER BY ABC_Class;
GO