/*Debug Variables

DECLARE @EndDate datetime = GETDATE(), -- Set this to your specific end date
    @LocationID varchar(6) = 'MAIN', -- Example LocationID, set your value
    @Categories nvarchar(MAX) = '279, 311, 75, 270, 271', -- Example category IDs, set your values
    @TransactionTypes nvarchar(MAX) = '1,2,3,4,8'; -- Example transaction type IDs, set your values */

	SET NOCOUNT ON


	DECLARE @WipTrackingEnabled AS bit = [wip].[ufn_WipTrackingEnabled]()

	DECLARE @SystemCostMethod tinyint
	DECLARE @XML AS XML
	DECLARE @Delimiter AS CHAR(1) =','

	SELECT @SystemCostMethod = [Value]
	FROM GeneralSetup 
	WHERE Parameter = 'CostingMethod'

	IF @SystemCostMethod IS NULL
		SET @SystemCostMethod = 0 
		
	SET @XML = CAST(('<X>'+REPLACE(@Categories,@Delimiter ,'</X><X>')+'</X>') AS XML)

	DECLARE @CategoriesTable TABLE (ID INT)
	INSERT INTO @CategoriesTable (ID)
		SELECT N.value('.', 'INT') AS ID FROM @XML.nodes('X') AS T(N)

	SET @XML = CAST(('<X>'+REPLACE(@TransactionTypes,@Delimiter ,'</X><X>')+'</X>') AS XML)

	DECLARE @TypesTable TABLE (ID INT)
	INSERT INTO @TypesTable (ID)
		SELECT N.value('.', 'INT') AS ID FROM @XML.nodes('X') AS T(N) 

	-- 1 Schedule (3/1, 4/1)
	-- 2 Real time (3/7, 4/6)
	-- 3 Invoice (3/2, 4/2 ... OR 8)
	-- 4 Shipment (3/6, 4/7)
	-- 5 Opti (3/5, 4/5)
	-- 6 Transfer (3/4, 4/4, 5/4)
	-- 7 Manual adjustment (3/3, 4/3 ... OR 6)
	-- 8 Cycle count (7)
	-- 9 Accounting sync (9)
	-- 10 Receiving (5/6)
	-- 11 Made to Stock (3/8, 4/8);

;WITH InventoryData AS (
    SELECT 
        DATEADD(day, -t.DaysBack, @EndDate) AS PeriodStartDate,
        DATEADD(day, -t.DaysBack + 1, @EndDate) AS PeriodEndDate,
        t.DaysBack,
        [dbo].[ufn_partFormatPart](i.PartNo, i.PartNoSuffix, 0) AS Part, 
        mpl.[Description], 
        ISNULL(c.[Description], '') AS InvCategory,
        itd.QuantityOnHandAdj * -1 AS Quantity,
        CASE WHEN @WipTrackingEnabled = 1 THEN id.AvgCost ELSE 
            CASE ISNULL(i.CostMethod, @SystemCostMethod) 
                WHEN 0 THEN id.StdCost 
                WHEN 1 THEN id.AvgCost
                ELSE id.LastCost 
            END 
        END * dbo.ufn_partGetCostStockMultiplier(i.PartNo, i.PartNoSuffix) * itd.QuantityOnHandAdj * -1 AS TotalCost,
        CASE WHEN @WipTrackingEnabled = 1 THEN id.AvgCost ELSE 
            CASE ISNULL(i.CostMethod, @SystemCostMethod) 
                WHEN 0 THEN id.StdCost 
                WHEN 1 THEN id.AvgCost
                ELSE id.LastCost 
            END 
        END AS CurrentCost,
        i.StockUOM, 
        cc.CultureInfo AS CostingCultureInfo, 
        i.CostUOM, 
        i.CategoryID
    FROM (VALUES (30), (60), (90)) AS t(DaysBack)
    JOIN InventoryTrans it ON it.InvTransDate BETWEEN DATEADD(day, -t.DaysBack, @EndDate) AND @EndDate
    JOIN InventoryTransDetail itd ON it.InvTransID = itd.InvTransID
    JOIN Inventory i ON i.PartNo = itd.PartNo AND i.PartNoSuffix = itd.PartNoSuffix
    JOIN InventoryDetail id ON i.PartNo = id.PartNo AND i.PartNoSuffix = id.PartNoSuffix AND it.LocationID = id.LocationID
    JOIN Locations l ON l.LocationID = it.LocationID
    JOIN CultureCurrencies cc ON cc.CultureInfo = l.CurrencyCulture
    JOIN MasterPartList mpl ON mpl.MasterPartNo = i.PartNo AND mpl.PartNoSuffix = i.PartNoSuffix                    
    JOIN Categories c ON c.ID = i.CategoryID
    JOIN @CategoriesTable cs ON c.ID = cs.ID
    WHERE itd.QuantityOnHandAdj <> 0 AND it.LocationID = ISNULL(@LocationID, it.LocationID)
)
SELECT 
    Part,
    [Description],
    InvCategory,
    MAX(CASE WHEN DaysBack = 30 THEN Quantity ELSE 0 END) AS [30 Days Quantity],
    MAX(CASE WHEN DaysBack = 30 THEN TotalCost ELSE 0 END) AS [30 Days Total Cost],
    MAX(CASE WHEN DaysBack = 60 THEN Quantity ELSE 0 END) AS [60 Days Quantity],
    MAX(CASE WHEN DaysBack = 60 THEN TotalCost ELSE 0 END) AS [60 Days Total Cost],
    MAX(CASE WHEN DaysBack = 90 THEN Quantity ELSE 0 END) AS [90 Days Quantity],
    MAX(CASE WHEN DaysBack = 90 THEN TotalCost ELSE 0 END) AS [90 Days Total Cost],
    AVG(CurrentCost) AS CurrentCost,  -- Assuming you want the average current cost per part for each period
    StockUOM, 
    CostingCultureInfo, 
    CostUOM, 
    CategoryID
FROM InventoryData
GROUP BY Part, [Description], InvCategory, StockUOM, CostingCultureInfo, CostUOM, CategoryID
ORDER BY InvCategory, Part;