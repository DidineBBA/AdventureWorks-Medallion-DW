USE [AdventureWorks2012];
GO

-- 1. Create the Bronze Schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA [bronze];');
END;
GO

-- 2. Ingest Raw Sales Order Header
IF OBJECT_ID('bronze.SalesOrderHeader', 'U') IS NOT NULL DROP TABLE bronze.SalesOrderHeader;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.SalesOrderHeader
FROM Sales.SalesOrderHeader;

-- 3. Ingest Raw Sales Order Detail
IF OBJECT_ID('bronze.SalesOrderDetail', 'U') IS NOT NULL DROP TABLE bronze.SalesOrderDetail;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.SalesOrderDetail
FROM Sales.SalesOrderDetail;

-- 4. Ingest Raw Product Data
IF OBJECT_ID('bronze.Product', 'U') IS NOT NULL DROP TABLE bronze.Product;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.Product
FROM Production.Product;

IF OBJECT_ID('bronze.ProductSubcategory', 'U') IS NOT NULL DROP TABLE bronze.ProductSubcategory;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.ProductSubcategory
FROM Production.ProductSubcategory;

IF OBJECT_ID('bronze.ProductCategory', 'U') IS NOT NULL DROP TABLE bronze.ProductCategory;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.ProductCategory
FROM Production.ProductCategory;

-- 5. Ingest Raw Customer & Person Data
IF OBJECT_ID('bronze.Customer', 'U') IS NOT NULL DROP TABLE bronze.Customer;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.Customer
FROM Sales.Customer;

IF OBJECT_ID('bronze.Person', 'U') IS NOT NULL DROP TABLE bronze.Person;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.Person
FROM Person.Person;

IF OBJECT_ID('bronze.Store', 'U') IS NOT NULL DROP TABLE bronze.Store;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.Store
FROM Sales.Store;

-- 6. Ingest Raw Sales Territory Data
IF OBJECT_ID('bronze.SalesTerritory', 'U') IS NOT NULL DROP TABLE bronze.SalesTerritory;
SELECT *, GETDATE() AS _ingested_at
INTO bronze.SalesTerritory
FROM Sales.SalesTerritory;
GO

SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('bronze');