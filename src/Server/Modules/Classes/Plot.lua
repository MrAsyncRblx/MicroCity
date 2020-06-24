-- Plot
-- MrAsync
-- June 2, 2020


--[[

    Handle the dispertion of plots as well as anything plot and placement related
    Most importantly, handles the networking of roads

]]


local Plot = {}
Plot.__index = Plot

--//Api
local CompressionApi
local NumberUtil
local DataStore2
local LogApi

--//Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PlayerService

--//Classes
local BuildingClass

--//Controllers

--//Locals
local PlotContainer
local AvailablePlots = {}


function Plot.new(pseudoPlayer)
    LogApi:Log("Server | PlotClass | Constructor: A new Plot object is being created for " .. pseudoPlayer.Player.Name)

    local self = setmetatable({
        Player = pseudoPlayer.Player,

        RoadNetwork = {},
        BuildingList = {},
        BuildingStore = DataStore2("Buildings", pseudoPlayer.Player)
    }, Plot)

    --De-serializes data before initially loaded
    self.BuildingStore:BeforeInitialGet(function(serialized)
        local decompressedData = CompressionApi:decompress(serialized)
        local buildingData = string.split(decompressedData, "|")
        serialized = {}

        --Iterate through all split strings, insert them into table
        for _, JSONData in pairs(buildingData) do
            serialized[HttpService:GenerateGUID(false)] = JSONData
        end

        return serialized
    end)

    --Serializes data before save
    self.BuildingStore:BeforeSave(function(deserialized)
        local str = ""

        --Iterate through all placements, combine JSONData
        for guid, jsonArray in pairs(deserialized) do
            if (str == "") then
                str = jsonArray
            else
                str = str .. "|" .. jsonArray
            end
        end

        return CompressionApi:compress(str)
    end) 

    --Pop last plot and give it to player
    self.Object = table.remove(AvailablePlots, #AvailablePlots)
    if (not self.Object) then LogApi:LogWarn("Server | PlotClass | Constructor: No plot object was given to " .. pseudoPlayer.Player.Name .. "!") end

    --Localize aspects of plot
    self.CFrame = self.Object.Main.CFrame
    self.MainSize = self.Object.Main.Size
    self.VisualPartSize = self.Object.VisualPart.Size
    self.Corner = self.CFrame * CFrame.new(self.MainSize / 2) + Vector3.new(1, 0, 1)

    --Populate network
    self.TotalRows = self.MainSize.Z / 2
    for i=1, self.TotalRows do
        table.insert(self.RoadNetwork, {})
    end 

    return self
end


--//Solves a merge given a building object and their adjacent tiles
function Plot:SolveMerge(buildingObject, adjacentTiles)
    --Four way intersection
    if (adjacentTiles.Top and adjacentTiles.Bottom and adjacentTiles.Left and adjacentTiles.Right) then
        buildingObject:Upgrade(6, true)

    --Three way intersection
    elseif ((adjacentTiles.Top and adjacentTiles.Bottom and (adjacentTiles.Right or adjacentTiles.Left)) or (adjacentTiles.Right and adjacentTiles.Left and (adjacentTiles.Top or adjacentTiles.Bottom))) then
        buildingObject:Upgrade(5, true)

        local newWorldPosition = CFrame.new(
            buildingObject.WorldPosition.Position,
            ((adjacentTiles.Right and adjacentTiles.Left and adjacentTiles.Top) and adjacentTiles.Top.WorldPosition.Position) or
            ((adjacentTiles.Right and adjacentTiles.Left and not adjacentTiles.Top) and adjacentTiles.Bottom.WorldPosition.Position) or
            ((adjacentTiles.Top and adjacentTiles.Bottom and adjacentTiles.Right) and adjacentTiles.Right.WorldPosition.Position) or
            ((adjacentTiles.Top and adjacentTiles.Bottom and not  adjacentTiles.Right) and adjacentTiles.Left.WorldPosition.Position)
        )

        buildingObject:Move(self.CFrame:ToObjectSpace(newWorldPosition))

	--Turns
    elseif (adjacentTiles.Top and adjacentTiles.Left or adjacentTiles.Top and adjacentTiles.Right or adjacentTiles.Bottom and adjacentTiles.Right or adjacentTiles.Bottom and adjacentTiles.Left) then
        buildingObject:Upgrade(4, true)

        --Orientation detection
        local newWorldPosition = CFrame.new(
            buildingObject.WorldPosition.Position,
            ((adjacentTiles.Top and adjacentTiles.Left) and adjacentTiles.Left.WorldPosition.Position) or
            ((adjacentTiles.Top and adjacentTiles.Right) and adjacentTiles.Top.WorldPosition.Position) or
            ((adjacentTiles.Bottom and adjacentTiles.Right) and adjacentTiles.Right.WorldPosition.Position) or
            ((adjacentTiles.Bottom and adjacentTiles.Left) and adjacentTiles.Bottom.WorldPosition.Position)
        )

        buildingObject:Move(self.CFrame:ToObjectSpace(newWorldPosition))


    --Straight road orientation
    elseif (adjacentTiles.Top or adjacentTiles.Bottom or adjacentTiles.Left or adjacentTiles.Right) then
        if ((adjacentTiles.Top and adjacentTiles.Bottom) or (adjacentTiles.Right and adjacentTiles.Left)) then
            --Straight road no dead-end

            buildingObject:Upgrade(3, true)
        else
            --Cul de sac

            buildingObject:Upgrade(2, true)
        end

        --Orientation detection
        local newWorldPosition = CFrame.new(
            buildingObject.WorldPosition.Position,
            (adjacentTiles.Top and adjacentTiles.Top.WorldPosition.Position) or 
            (adjacentTiles.Bottom and adjacentTiles.Bottom.WorldPosition.Position) or
            (adjacentTiles.Left and adjacentTiles.Left.WorldPosition.Position) or
            (adjacentTiles.Right and adjacentTiles.Right.WorldPosition.Position)
        )

        buildingObject:Move(self.CFrame:ToObjectSpace(newWorldPosition))
    end

    --Refresh cached versions on BuildingObject
    self:RefreshBuildingObject(buildingObject)
    self:RefreshRoadInNetwork(buildingObject)
end


--//Adds a road to the network
--//If road is not being loaded, the merge is solved
function Plot:AddRoadToNetwork(buildingObject, isBeingLoaded)
    if (buildingObject.MetaData.Type ~= "Road") then return end
   
    local gridSpace = self:WorldToGridSpace(buildingObject.WorldPosition)
    self.RoadNetwork[gridSpace.Z][gridSpace.X] = buildingObject

    if (not isBeingLoaded) then
        local adjacentTiles = self:GetAdjacentTiles(gridSpace)
        self:SolveMerge(buildingObject, adjacentTiles)

        --Refresh adjacent tiles
        for _, adjacentTile in pairs(adjacentTiles) do
            local adjacentGridSpace = self:WorldToGridSpace(adjacentTile.WorldPosition)
            self:SolveMerge(adjacentTile, self:GetAdjacentTiles(adjacentGridSpace))
        end
    end
end


--//Removes a road from the network
function Plot:RemoveRoadFromNetwork(buildingObject)
    local gridSpace = self:WorldToGridSpace(buildingObject.WorldPosition)
    self.RoadNetwork[gridSpace.Z][gridSpace.X] = nil

    --Re-merge adjacent tiles
    local adjacentTiles = self:GetAdjacentTiles(gridSpace)
    for _, adjacentTile in pairs(adjacentTiles) do
        local adjacentGridSpace = self:WorldToGridSpace(adjacentTile.WorldPosition)
        self:SolveMerge(adjacentTile, self:GetAdjacentTiles(adjacentGridSpace))
    end
end


--//Updates the buildingObject at a GridSpace
--//Will overwrite the buildingObject
function Plot:RefreshRoadInNetwork(buildingObject)
    local gridSpace = self:WorldToGridSpace(buildingObject.WorldPosition)
    self.RoadNetwork[gridSpace.Z][gridSpace.X] = buildingObject
end


--//Returns a Vector3 in GridSpace from a given CFrame
function Plot:WorldToGridSpace(worldSpace)
    local cornerSpace = self.Corner:ToObjectSpace(worldSpace)

    return Vector3.new(
        NumberUtil.Round(math.abs(cornerSpace.X / 2) + 1),
        0,
        NumberUtil.Round(math.abs(cornerSpace.Z / 2) + 1)
    )
end


--//Returns the objects in the four adjacent tiles
--//Indecies may be null
function Plot:GetAdjacentTiles(gridSpace)
    return {
		Top = self.RoadNetwork[math.clamp(gridSpace.Z - 1, 1, self.TotalRows)][gridSpace.X],
		Bottom = self.RoadNetwork[math.clamp(gridSpace.Z + 1, 1, self.TotalRows)][gridSpace.X],
		Left = self.RoadNetwork[gridSpace.Z][math.clamp(gridSpace.X - 1, 1, self.TotalRows)],
		Right = self.RoadNetwork[gridSpace.Z][math.clamp(gridSpace.X + 1, 1, self.TotalRows)]
    }
end


--//Returns the object at index GUID
--//May return nil
function Plot:GetBuildingObject(guid)
    return self.BuildingList[guid]
end


--//Inserts buildingObject into BuildingList
--//Updates BuildingStore to reflect change
function Plot:AddBuildingObject(buildingObject)
    self.BuildingList[buildingObject.Guid] = buildingObject
    
    self.BuildingStore:Update(function(currentIndex)
        currentIndex[buildingObject.Guid] = buildingObject:Encode()

        return currentIndex
    end)
end


--//Removes buildingObject from BuildingList
--//Updates BuildingStore to reflect change
function Plot:RemoveBuildingObject(buildingObject)
    self.BuildingList[buildingObject.Guid] = nil

    self.BuildingStore:Update(function(currentIndex)
        currentIndex[buildingObject.Guid] = nil

        return currentIndex
    end)
end


--//Pseudo for AddBuildingObject
function Plot:RefreshBuildingObject(...)
    return self:AddBuildingObject(...)
end


--//Loads buildings from a save list
function Plot:LoadBuildings(pseudoPlayer, buildingList)
    self.Loading = true

    local steppedConnection
    local numericalTable = {}
    local currentIndex = 1

    --Temporarily store all items in a sub-table in numericalTable
    for guid, JSONData in pairs(buildingList) do
        table.insert(numericalTable, {guid, JSONData})
    end

    --Failsafe to prevent error spam if player leaves while loading
    local failSafe = Players.PlayerRemoving:Connect(function(player)
        if (player.Name == pseudoPlayer.Player.Name) then
            if (steppedConnection) then
                steppedConnection:Disconnect()
            end
        end
    end)

    --Load items when stepped
    steppedConnection = RunService.Stepped:Connect(function()
        local buildInfo = numericalTable[currentIndex]

        --Run once all buildings are loaded
        if (not buildInfo) then
            steppedConnection:Disconnect()

            --Tell client that their plot has finished loading
            PlayerService:FireClientEvent("PlotHasLoaded", pseudoPlayer.Player)

            --Disconnect failsafe
            failSafe:Disconnect()
            self.Loading = false

            return
        end

        local guid = buildInfo[1]
        local jsonData = buildInfo[2]

        --Construct a new BuildingObject
        local buildingObject = BuildingClass.newFromSave(pseudoPlayer, guid, jsonData)
        if (not buildingObject) then return end

        self:AddBuildingObject(buildingObject)
        self:AddRoadToNetwork(buildingObject, true)

        currentIndex += 1
    end)

    return
end


--//Cleans up plot when player leaves
function Plot:Unload()
    LogApi:Log("Server | PlotClass | Unload: Unloading player-plot for " .. self.Player.Name)

    table.insert(AvailablePlots, self.Object)

    self.Object.Placements.Building:ClearAllChildren()
    self.Object.Placements.Road:ClearAllChildren()
    self.Object = nil

    LogApi:Log("Server | PlotClass | Unload: Completed")
end


function Plot:Start()
    LogApi:Log("Server | PlotClass | Startup: Indexing available plots, pushing them into the PlotStack")

    for _, plot in pairs(PlotContainer:GetChildren()) do
        if (not plot:IsA("Folder")) then continue end

        table.insert(AvailablePlots, plot)
    end

    LogApi:Log("Server | PlotClass | Startup: Completed")
end


function Plot:Init()
    --//Api
    CompressionApi = self.Shared.Api.CompressionApi
    NumberUtil = self.Shared.NumberUtil
    DataStore2 = require(ServerScriptService:WaitForChild("DataStore2"))
    LogApi = self.Shared.Api.LogApi

    --//Services
    PlayerService = self.Services.PlayerService

    --//Classes
    BuildingClass = self.Modules.Classes.Building

    --//Controllers

    --//Locals
    PlotContainer = Workspace:WaitForChild("Plots")

end


return Plot