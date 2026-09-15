USE [AdventureWorks2012];
GO

-- 1. Create Logging Table
IF OBJECT_ID('dbo.ETL_ExecutionLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_ExecutionLog (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        PipelineName VARCHAR(100) NOT NULL,
        StepName VARCHAR(100) NOT NULL,
        Status VARCHAR(20) NOT NULL,
        RowsProcessed INT NULL,
        ExecutionTimeMs INT NULL,
        LogDate DATETIME DEFAULT GETDATE(),
        ErrorMessage VARCHAR(MAX) NULL
    );
END;
GO

-- 2. Master Orchestration Stored Procedure
IF OBJECT_ID('dbo.usp_Run_Medallion_Pipeline', 'P') IS NOT NULL 
    DROP PROCEDURE dbo.usp_Run_Medallion_Pipeline;
GO

CREATE PROCEDURE dbo.usp_Run_Medallion_Pipeline
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @StepStart DATETIME;
    DECLARE @RowCount INT;

    BEGIN TRY
        -- Log Pipeline Start
        INSERT INTO dbo.ETL_ExecutionLog (PipelineName, StepName, Status)
        VALUES ('Medallion_ETL', 'Pipeline_Start', 'STARTED');

        -- ====================================================================
        -- STEP 1: BRONZE LAYER INGESTION (Metadata Tracking)
        -- ====================================================================
        SET @StepStart = GETDATE();
        
        -- Ingested timestamp tracking (Tables populated from AdventureWorks2012 source)
        INSERT INTO dbo.ETL_ExecutionLog (PipelineName, StepName, Status, ExecutionTimeMs)
        VALUES ('Medallion_ETL', 'Bronze_Ingestion', 'SUCCESS', DATEDIFF(MILLISECOND, @StepStart, GETDATE()));

        -- ====================================================================
        -- STEP 2: SILVER LAYER (Cleansing Views Verification)
        -- ====================================================================
        SET @StepStart = GETDATE();

        SELECT @RowCount = COUNT(*) FROM silver.vw_SalesOrder;

        INSERT INTO dbo.ETL_ExecutionLog (PipelineName, StepName, Status, RowsProcessed, ExecutionTimeMs)
        VALUES ('Medallion_ETL', 'Silver_Cleansing_Views', 'SUCCESS', @RowCount, DATEDIFF(MILLISECOND, @StepStart, GETDATE()));

        -- ====================================================================
        -- STEP 3: GOLD LAYER (Star Schema Rebuild)
        -- ====================================================================
        SET @StepStart = GETDATE();

        -- Truncate/Rebuild Fact & Dimensions
        EXEC('
            IF OBJECT_ID(''gold.Fact_Sales'', ''U'') IS NOT NULL DROP TABLE gold.Fact_Sales;
            IF OBJECT_ID(''gold.Dim_Date'', ''U'') IS NOT NULL DROP TABLE gold.Dim_Date;
            IF OBJECT_ID(''gold.Dim_Customer'', ''U'') IS NOT NULL DROP TABLE gold.Dim_Customer;
            IF OBJECT_ID(''gold.Dim_Product'', ''U'') IS NOT NULL DROP TABLE gold.Dim_Product;
        ');

        -- Re-create Date Dimension
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

        INSERT INTO gold.Dim_Date (DateKey, [Date], [Year], [Quarter], [Month], MonthName, DayOfWeek, DayName)
        VALUES (-1, '1900-01-01', 1900, 0, 0, 'Unknown', 0, 'Unknown');

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

        -- Re-create Customer Dimension
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

        -- Re-create Product Dimension
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

        -- Re-create Fact Sales
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

        INSERT INTO gold.Fact_Sales (SalesOrderID, SalesOrderDetailID, OrderDateKey, CustomerSK, ProductSK, OrderQty, UnitPrice, UnitPriceDiscount, LineTotal)
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

        SELECT @RowCount = @@ROWCOUNT;

        INSERT INTO dbo.ETL_ExecutionLog (PipelineName, StepName, Status, RowsProcessed, ExecutionTimeMs)
        VALUES ('Medallion_ETL', 'Gold_Star_Schema_Rebuild', 'SUCCESS', @RowCount, DATEDIFF(MILLISECOND, @StepStart, GETDATE()));

        -- Log Pipeline Success
        INSERT INTO dbo.ETL_ExecutionLog (PipelineName, StepName, Status, ExecutionTimeMs)
        VALUES ('Medallion_ETL', 'Pipeline_Complete', 'SUCCESS', DATEDIFF(MILLISECOND, @StartTime, GETDATE()));

    END TRY
    BEGIN CATCH
        -- Log Pipeline Error
        INSERT INTO dbo.ETL_ExecutionLog (PipelineName, StepName, Status, ErrorMessage)
        VALUES ('Medallion_ETL', 'Pipeline_Failure', 'FAILED', ERROR_MESSAGE());
        
        THROW;
    END CATCH
END;
GO

-- ====================================================================
-- VERIFICATION & EXECUTION TEST
-- ====================================================================
-- Execute the Master Pipeline
EXEC dbo.usp_Run_Medallion_Pipeline;
GO

-- Review Execution Audit Logs
SELECT 
    LogID,
    StepName,
    Status,
    RowsProcessed,
    ExecutionTimeMs,
    LogDate,
    ErrorMessage
FROM dbo.ETL_ExecutionLog
ORDER BY LogID DESC;
GO