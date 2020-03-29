-- Placement Api
-- MrAsync
-- March 24, 2020


--[[

    Interface for controlling the players ability to place objects, edit objects

    Events:
        ObjectPlaced => itemId
        PlacementCancelled => itemId

    Methods:
        public void StartPlacing(int ItemId)
        public void StopPlacing()

        private int Round(int num)
        private void RotateObject(String actionName, Enum inputState, InputObject inputObject)
        private void PlaceObject(String actionName, Enum inputState, InputObject inputObject)

        private void CheckSelection()
        private void UpdatePlacement()

]]



local PlacementApi = {}
local self = PlacementApi

--//Api

--//Services
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")

local PlayerService

--//Controllers

--//Classes

--//Locals
local mouse
local camera
local character
local plotObject

local itemId
local plotMin
local plotMax
local plotCFrame
local itemObject
local itemRotation
local worldPosition

local UP = Vector3.new(0, 1, 0)
local BACK = Vector3.new(0, 0, 1)
local GRID_SIZE = 1
local BUILD_HEIGHT = 1024

--[[
    PRIVATE METHODS
]]

--//Rotates the object according to input
local function RotateObject(actionName, inputState, inputObject)
    if (inputState == Enum.UserInputState.Begin) then
        if (inputObject.KeyCode == Enum.KeyCode.R or inputObject.KeyCode == Enum.KeyCode.ButtonR1) then
            itemRotation = itemRotation - (math.pi / 2)
        else
            itemRotation = itemRotation + (math.pi / 2)
        end
    end
end


--//Fires the ObjectPlaced signal
local function PlaceObject(_, inputState)
    if (inputState == Enum.UserInputState.Begin) then
        self.Events.ObjectPlaced:Fire(itemId)
    end
end


--//Simple smart-rounding method
local function Round(num)
    return (num % 1 >= 0.5 and math.ceil(num) or math.floor(num))
end


--//Bound to RenderStep
--//Checks if player is hovering over a placed object
local function CheckSelection()

end

--//Bound to RenderStep
--//Moves model to position of mouse
--//Big maths
local function UpdatePlacement()
    --RayCasting to determine optimal placement position
    local mousePos = UserInputService:GetMouseLocation()
    local mouseUnitRay = camera:ScreenPointToRay(mousePos.X, mousePos.Y - 30)
    local mouseRay = Ray.new(mouseUnitRay.Origin, (mouseUnitRay.Direction * 100))
    local rayPart, hitPosition, normal = workspace:FindPartOnRayWithIgnoreList(mouseRay, {(self.Player.Character or self.Player.CharacterAdded:Wait()), itemObject})

    --Calculate model size according to current itemRotation
    local modelSize = CFrame.fromEulerAnglesYXZ(0, itemRotation, 0) * itemObject.PrimaryPart.Size
    modelSize = Vector3.new(Round(math.abs(modelSize.X)), Round(math.abs(modelSize.Y)), Round(math.abs(modelSize.Z)))

    --If itemObject.PrimaryPart.Size is odd, we must place it evenly on the grid
    local xAppend = 0
    local zAppend = 0

    if (((modelSize.X / 2) % 2) > 0) then
        xAppend = 0.5
    end
    if (((modelSize.Z / 2) % 2) > 0) then
        zAppend = 0.5
    end

    --Allow messy placement on the side of previously placed objects
    hitPosition = hitPosition + (normal * (modelSize / 2))

    --Allign placement positions to GRID_SIZE
    local xPosition = (math.floor(hitPosition.X / GRID_SIZE) * GRID_SIZE) + xAppend
    local yPosition = plotMax.Y + (modelSize.Y / 2)
    local zPosition = (math.floor(hitPosition.Z / GRID_SIZE) * GRID_SIZE) + zAppend

    --Clamp positions inside of plot so players cannot scrub outside of plot
    xPosition = math.clamp(xPosition, plotMin.X + (modelSize.X / 2), plotMax.X - (modelSize.X / 2))
    zPosition = math.clamp(zPosition, plotMin.Z + (modelSize.Z / 2), plotMax.Z - (modelSize.Z / 2))

    --Construct worldPosition and get a localPosition
    worldPosition = CFrame.new(xPosition, yPosition, zPosition) * CFrame.Angles(0, itemRotation, 0)

    --Set the position of the object
    itemObject:SetPrimaryPartCFrame(itemObject.PrimaryPart.CFrame:Lerp(worldPosition, .2))
end

--[[
    PUBLIC METHODS
]]

--//Starts the placing process
--//Clones the model
--//Binds function to renderStepped
function PlacementApi:StartPlacing(id)
    --Clone model into current camera
    --IMPLEMENT LEVEL SELECTION
    itemObject = ReplicatedStorage.Items.Buildings:FindFirstChild(id).Lvl1:Clone()
    itemObject.Parent = camera
    itemId = id

    --Setup rotation
    itemRotation = math.pi / 2

    --Setup grid
    plotObject.PrimaryPart.Grid.Transparency = 0
    plotObject.PrimaryPart.GridDash.Transparency = 0

    --Bind Actions
    ContextActionService:BindAction("PlaceObject", PlaceObject, true, Enum.KeyCode.ButtonR2, Enum.UserInputType.MouseButton1)
        ContextActionService:SetImage("PlaceObject", "rbxassetid://4834693086")

        local placeObjectButton = ContextActionService:GetButton("PlaceObject")
        placeObjectButton.AnchorPoint = Vector2.new(.5, .5)
        placeObjectButton.Position = UDim2.new(.725, 0, .35, 0)

    ContextActionService:BindAction("RotateObject", RotateObject, true, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL1, Enum.KeyCode.R)
        ContextActionService:SetImage("RotateObject", "rbxassetid://4834696114")

        local rotateObjectButton = ContextActionService:GetButton("RotateObject")
        rotateObjectButton.AnchorPoint = Vector2.new(.5, .5)
        rotateObjectButton.Position = UDim2.new(.512, 0, .45, 0)

    ContextActionService:BindAction("CancelPlacement", PlacementApi.StopPlacing, true, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
        ContextActionService:SetImage("CancelPlacement", "rbxassetid://4834678852")

        local cancelButton = ContextActionService:GetButton("CancelPlacement")
        cancelButton.AnchorPoint = Vector2.new(.5, .5)
        cancelButton.Position = UDim2.new(.425, 0, .7, 0)

    RunService:BindToRenderStep("UpdatePlacement", 1, UpdatePlacement)
end


--//Stops placing object
function PlacementApi:StopPlacing()
    if (itemObject) then itemObject:Destroy() end

    --Reset locals
    worldPosition = nil
    itemId = 0

    --Cleanup grid
    plotObject.PrimaryPart.Grid.Transparency = 1
    plotObject.PrimaryPart.GridDash.Transparency = 1

    --Unbind actions
    ContextActionService:UnbindAction("PlaceObject")
    ContextActionService:UnbindAction("CancelPlacement")
    ContextActionService:UnbindAction("RotateObject")

    RunService:UnbindFromRenderStep("UpdatePlacement")
end


function PlacementApi:Start()
    --Update local plotObject when and if plotObject changes
    PlayerService.SendPlotToClient:Connect(function(newPlot)
        plotObject = newPlot

        plotCFrame = plotObject.PrimaryPart.CFrame
        plotMin = plotCFrame - (plotObject.PrimaryPart.Size / 2)
        plotMax = plotCFrame + (plotObject.PrimaryPart.Size / 2)
    end)
    
    RunService:BindToRenderStep("SelectionChecking", 0, CheckSelection)
end


function PlacementApi:Init()
    --//Api
    
    --//Services
    PlayerService = self.Services.PlayerService
    
    --//Controllers
    
    --//Classes
    
    --//Locals
    mouse = self.Player:GetMouse()
    camera = workspace.CurrentCamera

    --Register signals
    self.Events = {}
    self.Events.ObjectPlaced = Instance.new("BindableEvent")
    self.Events.PlacementCancelled = Instance.new("BindableEvent")

    self.Events.PlacementCancelled.Parent = script
    self.Events.ObjectPlaced.Parent = script

    self.PlacementCancelled = self.Events.PlacementCancelled.Event
    self.ObjectPlaced = self.Events.ObjectPlaced.Event

end

return PlacementApi