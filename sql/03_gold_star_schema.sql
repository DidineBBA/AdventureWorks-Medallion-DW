USE [AdventureWorks2012];
GO

-- 1. Drop Tables in Correct Dependency Order
IF OBJECT_ID('gold.Fact_Sales', 'U') IS NOT NULL DROP TABLE gold.Fact_Sales;
IF OBJECT_ID('gold.Dim_Date', 'U') IS NOT NULL DROP TABLE gold.Dim_Date;
IF OBJECT_ID('gold.Dim_Customer', 'U') IS NOT NULL DROP TABLE gold.Dim_Customer;
IF OBJECT_ID('gold.Dim_Product', 'U') IS NOT NULL DROP TABLE gold.Dim_Product;
GO

-- 2. Dimension: Date (Expanded Range 2005-2025)
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

-- Insert Unknown Date Placeholder for Nulls
INSERT INTO gold.Dim_Date (DateKey, [Date], [Year], [Quarter], [Month], MonthName, DayOfWeek, DayName)
VALUES (-1, '1900-01-01', 1900, 0, 0, 'Unknown', 0, 'Unknown');

-- Populate Date Dimension (2005 - 2025)
DECLARE @StartDate DATE = '2005-01-01';
DECLARE @EndDate DATE = '2025-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO gold.Dim_Date
    SELECT 
        (YEAR(@StartDate) * 10000) + (MONTH(@StartDate) * 100) + DAY(@StartDate),
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

-- 5. Fact: Sales
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
    ISNULL((YEAR(s.OrderDateKey) * 10000) + (MONTH(s.OrderDateKey) * 100) + DAY(s.OrderDateKey), -1) AS OrderDateKey,
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

-- 6. Verification Check
SELECT 'Dim_Customer' AS TableName, COUNT(*) AS [RowCount] FROM gold.Dim_Customer
UNION ALL
SELECT 'Dim_Product', COUNT(*) FROM gold.Dim_Product
UNION ALL
SELECT 'Dim_Date', COUNT(*) FROM gold.Dim_Date
UNION ALL
SELECT 'Fact_Sales', COUNT(*) FROM gold.Fact_Sales;
GO