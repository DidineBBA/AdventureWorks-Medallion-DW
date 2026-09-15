USE [AdventureWorks2012];
GO

-- 1. Create Silver Schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA [silver];');
END;
GO

-- 2. Cleaned Customer View / Staging
IF OBJECT_ID('silver.vw_Customer', 'V') IS NOT NULL DROP VIEW silver.vw_Customer;
GO
CREATE VIEW silver.vw_Customer AS
SELECT 
    c.CustomerID,
    c.PersonID,
    c.StoreID,
    c.TerritoryID,
    COALESCE(p.FirstName + ' ' + ISNULL(p.LastName, ''), s.Name, 'Unknown Customer') AS CustomerName,
    CASE 
        WHEN c.PersonID IS NOT NULL THEN 'Individual'
        WHEN c.StoreID IS NOT NULL THEN 'Store'
        ELSE 'Unknown'
    END AS CustomerType,
    c._ingested_at
FROM bronze.Customer c
LEFT JOIN bronze.Person p ON c.PersonID = p.BusinessEntityID
LEFT JOIN bronze.Store s ON c.StoreID = s.BusinessEntityID;
GO

-- 3. Cleaned Product View / Staging
IF OBJECT_ID('silver.vw_Product', 'V') IS NOT NULL DROP VIEW silver.vw_Product;
GO
CREATE VIEW silver.vw_Product AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    p.ProductNumber,
    ISNULL(p.Color, 'N/A') AS Color,
    p.StandardCost,
    p.ListPrice,
    ISNULL(ps.Name, 'Uncategorized') AS SubcategoryName,
    ISNULL(pc.Name, 'Uncategorized') AS CategoryName,
    p._ingested_at
FROM bronze.Product p
LEFT JOIN bronze.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN bronze.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID;
GO

-- 4. Cleaned Sales Fact Staging
IF OBJECT_ID('silver.vw_SalesOrder', 'V') IS NOT NULL DROP VIEW silver.vw_SalesOrder;
GO
CREATE VIEW silver.vw_SalesOrder AS
SELECT 
    h.SalesOrderID,
    d.SalesOrderDetailID,
    CAST(h.OrderDate AS DATE) AS OrderDateKey,
    CAST(h.DueDate AS DATE) AS DueDateKey,
    CAST(h.ShipDate AS DATE) AS ShipDateKey,
    h.CustomerID,
    d.ProductID,
    h.TerritoryID,
    d.OrderQty,
    d.UnitPrice,
    d.UnitPriceDiscount,
    d.LineTotal,
    h.Status AS OrderStatus,
    h._ingested_at
FROM bronze.SalesOrderHeader h
INNER JOIN bronze.SalesOrderDetail d ON h.SalesOrderID = d.SalesOrderID;
GO

-- ====================================================================
-- VERIFICATION: Silver Layer Views
-- ====================================================================
SELECT 'silver.vw_Customer' AS ViewName, COUNT(*) AS RecordCount FROM silver.vw_Customer
UNION ALL
SELECT 'silver.vw_Product', COUNT(*) FROM silver.vw_Product
UNION ALL
SELECT 'silver.vw_SalesOrder', COUNT(*) FROM silver.vw_SalesOrder;
GO