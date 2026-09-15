USE [AdventureWorks2012];
GO

-- 1. Create Gold Schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA [gold];');
END;
GO

-- 2. Dimension: Date (Role-Playing Support)
IF OBJECT_ID('gold.Dim_Date', 'U') IS NOT NULL DROP TABLE gold.Dim_Date;
CREATE TABLE gold.Dim_Date (
    DateKey INT PRIMARY KEY,
    [Date] DATE NOT NULL,
    [Year] INT NOT NULL,
    [Quarter] INT NOT NULL,
    [Month] INT NOT NULL,
    MonthName VARCHAR(15) NOT NULL,
    DayOfWeek INT NOT NULL,
    DayName VARCHAR(15) NOT NULL
);

-- Populate Date Dimension (2010 - 2015)
DECLARE @StartDate DATE = '2010-01-01';
DECLARE @EndDate DATE = '2015-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO gold.Dim_Date
    SELECT 
        CAST(CONVERT(VARCHAR(8), @StartDate, 112) AS INT),
        @StartDate,
        YEAR(@StartDate),
        DATEPART(QUARTER, @StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH, @StartDate),
        DATEPART(WEEKDAY, @StartDate),
        DATENAME(WEEKDAY, @StartDate);
        
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;
GO

-- 3. Dimension: Customer
IF OBJECT_ID('gold.Dim_Customer', 'U') IS NOT NULL DROP TABLE gold.Dim_Customer;
CREATE TABLE gold.Dim_Customer (
    CustomerSK INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    CustomerName NVARCHAR(150),
    CustomerType VARCHAR(20),
    TerritoryID INT
);

INSERT INTO gold.Dim_Customer (CustomerID, CustomerName, CustomerType, TerritoryID)
SELECT CustomerID, CustomerName, CustomerType, TerritoryID 
FROM silver.vw_Customer;

-- 4. Dimension: Product
IF OBJECT_ID('gold.Dim_Product', 'U') IS NOT NULL DROP TABLE gold.Dim_Product;
CREATE TABLE gold.Dim_Product (
    ProductSK INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    ProductName NVARCHAR(100),
    ProductNumber NVARCHAR(25),
    Color NVARCHAR(15),
    StandardCost MONEY,
    ListPrice MONEY,
    SubcategoryName NVARCHAR(50),
    CategoryName NVARCHAR(50)
);

INSERT INTO gold.Dim_Product (ProductID, ProductName, ProductNumber, Color, StandardCost, ListPrice, SubcategoryName, CategoryName)
SELECT ProductID, ProductName, ProductNumber, Color, StandardCost, ListPrice, SubcategoryName, CategoryName 
FROM silver.vw_Product;

USE [AdventureWorks2012];
GO

-- 1. Drop Fact Table
IF OBJECT_ID('gold.Fact_Sales', 'U') IS NOT NULL DROP TABLE gold.Fact_Sales;
GO

-- 2. Re-create Fact_Sales Table
CREATE TABLE gold.Fact_Sales (
    SalesOrderSK INT IDENTITY(1,1) PRIMARY KEY,
    SalesOrderID INT,
    SalesOrderDetailID INT,
    OrderDateKey INT FOREIGN KEY REFERENCES gold.Dim_Date(DateKey),
    CustomerSK INT FOREIGN KEY REFERENCES gold.Dim_Customer(CustomerSK),
    ProductSK INT FOREIGN KEY REFERENCES gold.Dim_Product(ProductSK),
    OrderQty SMALLINT,
    UnitPrice MONEY,
    UnitPriceDiscount MONEY,
    LineTotal NUMERIC(38, 6)
);
GO

-- 3. Insert using Mathematical Date Key Generation
INSERT INTO gold.Fact_Sales (
    SalesOrderID, 
    SalesOrderDetailID, 
    OrderDateKey, 
    CustomerSK, 
    ProductSK, 
    OrderQty, 
    UnitPrice, 
    UnitPriceDiscount, 
    LineTotal
)
SELECT 
    s.SalesOrderID,
    s.SalesOrderDetailID,
    (YEAR(s.OrderDateKey) * 10000) + (MONTH(s.OrderDateKey) * 100) + DAY(s.OrderDateKey) AS OrderDateKey,
    c.CustomerSK,
    p.ProductSK,
    s.OrderQty,
    s.UnitPrice,
    s.UnitPriceDiscount,
    s.LineTotal
FROM silver.vw_SalesOrder s
LEFT JOIN gold.Dim_Customer c ON s.CustomerID = c.CustomerID
LEFT JOIN gold.Dim_Product p ON s.ProductID = p.ProductID;
GO

-- 4. Verification Check
SELECT 'Dim_Customer' AS TableName, COUNT(*) AS [RowCount] FROM gold.Dim_Customer
UNION ALL
SELECT 'Dim_Product', COUNT(*) FROM gold.Dim_Product
UNION ALL
SELECT 'Dim_Date', COUNT(*) FROM gold.Dim_Date
UNION ALL
SELECT 'Fact_Sales', COUNT(*) FROM gold.Fact_Sales;
GO