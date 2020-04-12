-- Shopping Service
-- MrAsync
-- April 1, 2020


--[[

    Handles requests for item purchases
    Does not handle monetized purchases

]]


local ShoppingService = {Client = {}}

--//Api

--//Services
local MetaDataService
local PlayerService

--//Controllers

--//Classes

--//Locals


--//Returns true if player can afford a cost
--//Subtracts cost from player's cash balance
function ShoppingService:CanAffordCost(playerObject, cost)
    local cashValue = playerObject:GetData("Cash")

    --If player can afford cost, subtract and return true
    if (cashValue >= cost) then
        playerObject:SetData("Cash", playerObject:GetData("Cash") - cost)

        return true
    else
        return false
    end
end


function ShoppingService:PurchaseItem(playerObject, itemId, itemMetaData)
    local itemMetaData = MetaDataService:GetMetaData(itemId)

--    if (playerObject:GetData("Cash") >= itemMetaData.Cost) then
        playerObject:SetData("Cash", playerObject:GetData("Cash") - itemMetaData.Cost)

        return true
--    else
--        print("Not enough funds!")

--        return false
--   end
end


function ShoppingService:SellItem(playerObject, profit)
    playerObject:SetData("Cash", playerObject:GetData("Cash") + profit)

    return true
end


function ShoppingService:Start()
	
end


function ShoppingService:Init()
    --//Api

    --//Services
    MetaDataService = self.Services.MetaDataService
    PlayerService = self.Services.PlayerService

    --//Controllers

    --//Classes

    --//Locals
        
end


return ShoppingService