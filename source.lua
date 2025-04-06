--[[
	NexusUI - Single File Roblox UI Library
	Version: 0.2.2 (Single File - Added Close Button)

	Place this ModuleScript in ReplicatedStorage (or elsewhere accessible)
	and require it from a LocalScript.

	Example Usage (in a LocalScript, e.g., StarterPlayerScripts):

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local NexusUI = require(ReplicatedStorage.NexusUI) -- Adjust path if needed

	local window = NexusUI:Load({
		Title = "My Awesome UI",
		Size = UDim2.new(0, 550, 0, 400),
		Draggable = true
	})

	-- Add tabs and elements as usual...
	local mainTab = window:AddTab({ Name = "Main" })
	mainTab:AddButton({ Text="Test Button" })

	-- The close button in the top-right will automatically call NexusUI:Destroy() when clicked.

]]

local NexusUI = {}
NexusUI.Version = "0.2.2" -- Updated version number

-- Roblox Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService") -- Used for slider updates
local TweenService = game:GetService("TweenService") -- For smoother animations (optional)

-- Default Configuration / Theme
local DEFAULT_THEME = {
	WindowBackground = Color3.fromRGB(35, 35, 40),
	TitleBar = Color3.fromRGB(28, 28, 32),
	Border = Color3.fromRGB(50, 50, 55),
	Text = Color3.fromRGB(240, 240, 240),
	TextDisabled = Color3.fromRGB(150, 150, 150),
	TextPlaceholder = Color3.fromRGB(180, 180, 180),

	TabButtonActive = Color3.fromRGB(55, 55, 60),
	TabButtonInactive = Color3.fromRGB(40, 40, 45),
	TabHover = Color3.fromRGB(65, 65, 70),
	TabContentBackground = Color3.fromRGB(45, 45, 50),

	Button = Color3.fromRGB(70, 70, 80),
	ButtonHover = Color3.fromRGB(85, 85, 95),
	ButtonPressed = Color3.fromRGB(60, 60, 70),

	ToggleBackground = Color3.fromRGB(60, 60, 70),
	ToggleKnobOff = Color3.fromRGB(100, 100, 110),
	ToggleKnobOn = Color3.fromRGB(80, 180, 100),

	SliderBackground = Color3.fromRGB(60, 60, 70),
	SliderFill = Color3.fromRGB(80, 130, 200),
	SliderKnob = Color3.fromRGB(220, 220, 220),

	TextboxBackground = Color3.fromRGB(55, 55, 60),
	TextboxBorder = Color3.fromRGB(70, 70, 80),

	CloseButton = Color3.fromRGB(28, 28, 32), -- Same as TitleBar default
	CloseButtonHover = Color3.fromRGB(232, 17, 35), -- Red hover
	CloseButtonPressed = Color3.fromRGB(190, 15, 30), -- Darker red press

	Font = Enum.Font.GothamSemibold,
	TextSize = 14,
	TitleTextSize = 16,
}

local PADDING = UDim.new(0, 8) -- General padding for elements
local ELEMENT_HEIGHT = UDim.new(0, 28) -- Standard height for interactive elements
local TITLE_BAR_HEIGHT = UDim.new(0, 30)
local TAB_BUTTON_HEIGHT = UDim.new(0, 30)
local TAB_AREA_WIDTH = UDim.new(0, 120)
local CLOSE_BUTTON_WIDTH = UDim.new(0, 35) -- Width for the close button

-- State Tracking
local currentWindowInstance = nil
local connections = {} -- Store connections to disconnect later

-- Utility: Cleanup Connections
local function CleanupConnections()
	for _, conn in ipairs(connections) do
		if conn then
			pcall(function() conn:Disconnect() end) -- Wrap in pcall in case connection is already invalid
		end
	end
	connections = {}
end

-- Utility: Instance Creation Helper
local function Create(instanceType, properties)
	local inst = Instance.new(instanceType)
	for prop, value in pairs(properties) do
		pcall(function() inst[prop] = value end)
	end
	return inst
end

--[[----------------------------------------------------------------------------
	Dragger Utility (Integrated - Improved)
------------------------------------------------------------------------------]]
local Dragger = {}
function Dragger.Enable(guiObject, dragHandle)
	dragHandle = dragHandle or guiObject

	local dragging = false
	local dragStartOffset = Vector2.zero
	local lastInputPosition = Vector2.zero
	local inputChangedConnection = nil

	local function inputBegan(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local mousePos = UserInputService:GetMouseLocation()
			local handleAbsPos = dragHandle.AbsolutePosition
			local handleAbsSize = dragHandle.AbsoluteSize

			if mousePos.X >= handleAbsPos.X and mousePos.X <= handleAbsPos.X + handleAbsSize.X and
			   mousePos.Y >= handleAbsPos.Y and mousePos.Y <= handleAbsPos.Y + handleAbsSize.Y then

				dragging = true
				lastInputPosition = input.Position
				dragStartOffset = guiObject.AbsolutePosition - input.Position
				guiObject.Selectable = false
				dragHandle.Selectable = false

				if inputChangedConnection then inputChangedConnection:Disconnect() end
				inputChangedConnection = UserInputService.InputChanged:Connect(function(changedInput)
					if not dragging then return end
					if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
						local targetPosition = changedInput.Position + dragStartOffset
						local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
						local absoluteSize = guiObject.AbsoluteSize
						local anchorPoint = guiObject.AnchorPoint
						local minX = -absoluteSize.X * anchorPoint.X
						local maxX = viewportSize.X - absoluteSize.X * (1 - anchorPoint.X)
						local minY = -absoluteSize.Y * anchorPoint.Y
						local maxY = viewportSize.Y - absoluteSize.Y * (1 - anchorPoint.Y)
						local clampedX = math.clamp(targetPosition.X, minX, maxX)
						local clampedY = math.clamp(targetPosition.Y, minY, maxY)
						guiObject.Position = UDim2.fromOffset(clampedX, clampedY)
						lastInputPosition = changedInput.Position
					end
				end)
				table.insert(connections, inputChangedConnection)

				local inputChangedEndConnection
				inputChangedEndConnection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if inputChangedConnection then
							inputChangedConnection:Disconnect()
							inputChangedConnection = nil
						end
						guiObject.Selectable = true
						dragHandle.Selectable = true
						if inputChangedEndConnection then inputChangedEndConnection:Disconnect() end
					end
				end)
				-- Don't add inputChangedEndConnection to main table
			end
		end
	end

	local function inputEnded(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				if inputChangedConnection then
					pcall(function() inputChangedConnection:Disconnect() end)
					inputChangedConnection = nil
				end
				guiObject.Selectable = true
				dragHandle.Selectable = true
			end
		end
	end

	table.insert(connections, dragHandle.InputBegan:Connect(inputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(inputEnded))
end


--[[----------------------------------------------------------------------------
	Core UI Classes / Prototypes (Integrated)
------------------------------------------------------------------------------]]

-- Forward Declarations
local Window, Tab
local Button, Label, Toggle, Slider, Textbox -- Elements

-- Element Base
local ElementBase = {}
ElementBase.__index = ElementBase
function ElementBase.new()
	local self = setmetatable({}, ElementBase)
	self.Instance = nil
	self.Container = nil
	self.Config = {}
	self.Theme = {}
	return self
end
function ElementBase:Destroy()
	if self.Instance then
		pcall(function() self.Instance:Destroy() end)
		self.Instance = nil
	end
end

--- Window Class ---
Window = {}
Window.__index = Window
function Window.new(screenGui, config, theme)
	local self = setmetatable({}, Window)

	self.ScreenGui = screenGui
	self.Config = config
	self.Theme = theme or DEFAULT_THEME
	self.Tabs = {}
	self.TabButtons = {}
	self.ActiveTab = nil

	-- Main Window Frame
	self.Instance = Create("Frame", {
		Name = "NexusWindow",
		Size = config.Size,
		Position = UDim2.fromOffset(100, 100),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = self.Theme.WindowBackground,
		BorderSizePixel = 1,
		BorderColor3 = self.Theme.Border,
		Parent = screenGui,
		ClipsDescendants = true,
	})
	currentWindowInstance = self.Instance

	-- Title Bar
	self.TitleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT.Offset),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = self.Theme.TitleBar,
		BorderSizePixel = 0,
		Parent = self.Instance,
		ZIndex = 2,
	})

	-- Close Button (NEW)
	self.CloseButton = Create("TextButton", {
		Name = "CloseButton",
		Size = UDim2.new(0, CLOSE_BUTTON_WIDTH.Offset, 1, 0), -- Use full height of title bar
		Position = UDim2.new(1, -CLOSE_BUTTON_WIDTH.Offset, 0, 0), -- Position top-right
		BackgroundColor3 = self.Theme.CloseButton,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSansBold, -- Use a clear font for 'X'
		Text = "X",
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TitleTextSize, -- Match title text size roughly
		AutoButtonColor = false,
		Parent = self.TitleBar,
		ZIndex = 4, -- Above title label
	})

	-- Title Label (Adjusted Size)
	self.TitleLabel = Create("TextLabel", {
		Name = "TitleLabel",
		-- Reduce size to account for close button width and some padding
		Size = UDim2.new(1, -(PADDING.Offset * 2 + CLOSE_BUTTON_WIDTH.Offset), 1, 0),
		Position = UDim2.fromOffset(PADDING.Offset, 0),
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TitleTextSize,
		Text = config.Title or "Nexus UI",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = self.TitleBar,
		ZIndex = 3,
	})

	-- Close Button Interactions (NEW)
	table.insert(connections, self.CloseButton.MouseButton1Click:Connect(function()
		-- Call the main destroy function for the entire UI
		NexusUI:Destroy()
	end))
	table.insert(connections, self.CloseButton.MouseEnter:Connect(function()
		TweenService:Create(self.CloseButton, TweenInfo.new(0.1), { BackgroundColor3 = self.Theme.CloseButtonHover }):Play()
	end))
	table.insert(connections, self.CloseButton.MouseLeave:Connect(function()
		TweenService:Create(self.CloseButton, TweenInfo.new(0.1), { BackgroundColor3 = self.Theme.CloseButton }):Play()
	end))
	table.insert(connections, self.CloseButton.MouseButton1Down:Connect(function()
		TweenService:Create(self.CloseButton, TweenInfo.new(0.05), { BackgroundColor3 = self.Theme.CloseButtonPressed }):Play()
	end))
	table.insert(connections, self.CloseButton.MouseButton1Up:Connect(function()
		-- Check if mouse is still over the button on release
		local mousePos = UserInputService:GetMouseLocation()
		local btnPos = self.CloseButton.AbsolutePosition
		local btnSize = self.CloseButton.AbsoluteSize
		local targetColor = self.Theme.CloseButton
		if mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X and
		   mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y then
			targetColor = self.Theme.CloseButtonHover
		end
		TweenService:Create(self.CloseButton, TweenInfo.new(0.1), { BackgroundColor3 = targetColor }):Play()
	end))


	-- Main Content Area Container
	self.ContentArea = Create("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT.Offset),
		Position = UDim2.new(0, 0, 0, TITLE_BAR_HEIGHT.Offset),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = self.Instance,
	})

	-- Tab Button List
	self.TabList = Create("Frame", {
		Name = "TabList",
		Size = UDim2.new(0, TAB_AREA_WIDTH.Offset, 1, 0),
		Position = UDim2.new(0,0,0,0),
		BackgroundColor3 = self.Theme.TitleBar,
		BorderSizePixel = 0,
		Parent = self.ContentArea,
	})
	self.TabListLayout = Create("UIListLayout", {
		Parent = self.TabList,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	-- Tab Content Area
	self.TabContent = Create("Frame", {
		Name = "TabContent",
		Size = UDim2.new(1, -TAB_AREA_WIDTH.Offset, 1, 0),
		Position = UDim2.new(0, TAB_AREA_WIDTH.Offset, 0, 0),
		BackgroundColor3 = self.Theme.TabContentBackground,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.ContentArea,
	})

	-- Make Draggable
	if config.Draggable ~= false then
		Dragger.Enable(self.Instance, self.TitleBar)
	end

	return self
end

function Window:AddTab(tabConfig)
	local tab = Tab.new(self, tabConfig)
	table.insert(self.Tabs, tab)

	local tabButton = Create("TextButton", {
		Name = tabConfig.Name .. "TabButton",
		Size = UDim2.new(1, 0, 0, TAB_BUTTON_HEIGHT.Offset),
		BackgroundColor3 = self.Theme.TabButtonInactive,
		BorderSizePixel = 0,
		Font = self.Theme.Font,
		Text = tabConfig.Name or "Tab",
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TextSize,
		LayoutOrder = #self.Tabs,
		Parent = self.TabList,
		AutoButtonColor = false,
	})
	self.TabButtons[tab] = tabButton

	if #self.Tabs == 1 then
		self:SetActiveTab(tab)
	end

	table.insert(connections, tabButton.MouseButton1Click:Connect(function()
		self:SetActiveTab(tab)
	end))
	table.insert(connections, tabButton.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			tabButton.BackgroundColor3 = self.Theme.TabHover
		end
	end))
	table.insert(connections, tabButton.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then
			tabButton.BackgroundColor3 = self.Theme.TabButtonInactive
		end
	end))

	return tab
end

function Window:SetActiveTab(tabToActivate)
	if not tabToActivate or self.ActiveTab == tabToActivate then return end

	if self.ActiveTab then
		if self.ActiveTab.ContainerFrame then
			self.ActiveTab.ContainerFrame.Visible = false
		end
		local oldButton = self.TabButtons[self.ActiveTab]
		if oldButton then
			oldButton.BackgroundColor3 = self.Theme.TabButtonInactive
			oldButton.TextColor3 = self.Theme.Text
		end
	end

	self.ActiveTab = tabToActivate
	if self.ActiveTab.ContainerFrame then
		self.ActiveTab.ContainerFrame.Visible = true
	end
	local newButton = self.TabButtons[self.ActiveTab]
	if newButton then
		newButton.BackgroundColor3 = self.Theme.TabButtonActive
		newButton.TextColor3 = self.Theme.Text
	end
end

function Window:Destroy()
	NexusUI:Destroy() -- Window destroy now delegates to the main destroy
end


--- Tab Class ---
Tab = {}
Tab.__index = Tab
function Tab.new(window, config)
	local self = setmetatable({}, Tab)
	self.Window = window
	self.Config = config
	self.Theme = window.Theme
	self.Elements = {}

	self.ContainerFrame = Create("ScrollingFrame", {
		Name = config.Name .. "Content",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = self.Window.TabContent,
		Visible = false,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = self.Theme.AccentDark or self.Theme.Border, -- Use AccentDark or Border
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasPosition = Vector2.zero,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})

	self.Layout = Create("UIListLayout", {
		Parent = self.ContainerFrame,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = PADDING,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		FillDirection = Enum.FillDirection.Vertical,
	})

	Create("UIPadding", {
		Parent = self.ContainerFrame,
		PaddingTop = PADDING,
		PaddingBottom = PADDING,
		PaddingLeft = PADDING,
		PaddingRight = PADDING,
	})

	return self
end

function Tab:_AddElement(elementInstance, layoutOrder)
	elementInstance.LayoutOrder = layoutOrder or (#self.Elements + 1)
	elementInstance.Parent = self.ContainerFrame
end

function Tab:Destroy()
	for _, element in ipairs(self.Elements) do
		if element and element.Destroy then
			pcall(element.Destroy, element)
		elseif element and element.Instance and element.Instance.Parent then
			pcall(element.Instance.Destroy, element.Instance)
		end
	end
	self.Elements = {}
	if self.ContainerFrame and self.ContainerFrame.Parent then
		pcall(self.ContainerFrame.Destroy, self.ContainerFrame)
		self.ContainerFrame = nil
	end
end

-- Element Factory Methods
function Tab:AddLabel(elemConfig) local el=Label.new(self,elemConfig) table.insert(self.Elements,el) self:_AddElement(el.Instance) return el end
function Tab:AddButton(elemConfig) local el=Button.new(self,elemConfig) table.insert(self.Elements,el) self:_AddElement(el.Instance) return el end
function Tab:AddToggle(elemConfig) local el=Toggle.new(self,elemConfig) table.insert(self.Elements,el) self:_AddElement(el.Instance) return el end
function Tab:AddSlider(elemConfig) local el=Slider.new(self,elemConfig) table.insert(self.Elements,el) self:_AddElement(el.ContainerInstance) return el end
function Tab:AddTextbox(elemConfig) local el=Textbox.new(self,elemConfig) table.insert(self.Elements,el) self:_AddElement(el.Instance) return el end


--[[----------------------------------------------------------------------------
	UI Element Classes (Integrated -unchanged from v0.2.1)
------------------------------------------------------------------------------]]

--- Label Element ---
Label = setmetatable({}, ElementBase)
Label.__index = Label
function Label.new(container, config)
	local self=setmetatable(ElementBase.new(),Label) self.Container=container self.Config=config self.Theme=container.Theme
	self.Instance=Create("TextLabel",{Name=config.Name or"NexusLabel",Size=UDim2.new(1,-PADDING.Offset*2,0,config.Height or self.Theme.TextSize+4),Position=UDim2.new(0,PADDING.Offset,0,0),BackgroundTransparency=1,Font=self.Theme.Font,TextColor3=config.Color or self.Theme.Text,TextSize=config.TextSize or self.Theme.TextSize,Text=config.Text or"Label",TextWrapped=config.Wrap or true,TextXAlignment=config.Align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,AutomaticSize=Enum.AutomaticSize.Y}) return self
end

--- Button Element ---
Button = setmetatable({}, ElementBase)
Button.__index = Button
function Button.new(container, config)
	local self=setmetatable(ElementBase.new(),Button) self.Container=container self.Config=config self.Theme=container.Theme self.Callback=config.Callback or function()print("Button clicked: "..(config.Text or"Untitled"))end
	self.Instance=Create("TextButton",{Name=config.Name or"NexusButton",Size=UDim2.new(1,-PADDING.Offset*2,0,ELEMENT_HEIGHT.Offset),Position=UDim2.new(0,PADDING.Offset,0,0),BackgroundColor3=self.Theme.Button,BorderSizePixel=0,Font=self.Theme.Font,TextColor3=self.Theme.Text,TextSize=self.Theme.TextSize,Text=config.Text or"Button",AutoButtonColor=false}) Create("UICorner",{CornerRadius=UDim.new(0,4),Parent=self.Instance})
	table.insert(connections,self.Instance.MouseButton1Click:Connect(function()pcall(self.Callback)end)) table.insert(connections,self.Instance.MouseEnter:Connect(function()TweenService:Create(self.Instance,TweenInfo.new(0.1),{BackgroundColor3=self.Theme.ButtonHover}):Play()end)) table.insert(connections,self.Instance.MouseLeave:Connect(function()TweenService:Create(self.Instance,TweenInfo.new(0.1),{BackgroundColor3=self.Theme.Button}):Play()end)) table.insert(connections,self.Instance.MouseButton1Down:Connect(function()TweenService:Create(self.Instance,TweenInfo.new(0.05),{BackgroundColor3=self.Theme.ButtonPressed}):Play()end)) table.insert(connections,self.Instance.MouseButton1Up:Connect(function()local mp=UserInputService:GetMouseLocation()local bp,bs=self.Instance.AbsolutePosition,self.Instance.AbsoluteSize local tc=self.Theme.Button if mp.X>=bp.X and mp.X<=bp.X+bs.X and mp.Y>=bp.Y and mp.Y<=bp.Y+bs.Y then tc=self.Theme.ButtonHover end TweenService:Create(self.Instance,TweenInfo.new(0.1),{BackgroundColor3=tc}):Play()end)) return self
end

--- Toggle Element ---
Toggle = setmetatable({}, ElementBase)
Toggle.__index = Toggle
function Toggle.new(container, config)
	local self=setmetatable(ElementBase.new(),Toggle) self.Container=container self.Config=config self.Theme=container.Theme self.Callback=config.Callback or function(s)print("Toggle changed:",s)end self.State=config.Default or false
	self.Instance=Create("Frame",{Name=config.Name or"NexusToggleContainer",Size=UDim2.new(1,-PADDING.Offset*2,0,ELEMENT_HEIGHT.Offset),Position=UDim2.new(0,PADDING.Offset,0,0),BackgroundTransparency=1})
	self.Label=Create("TextLabel",{Name="ToggleLabel",Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Font=self.Theme.Font,TextColor3=self.Theme.Text,TextSize=self.Theme.TextSize,Text=config.Text or"Toggle",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Parent=self.Instance})
	local sw,sh,ks=40,ELEMENT_HEIGHT.Offset*0.6,ELEMENT_HEIGHT.Offset*0.6*0.8
	self.Switch=Create("Frame",{Name="SwitchBackground",Size=UDim2.fromOffset(sw,sh),Position=UDim2.new(1,-PADDING.Offset,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundColor3=self.Theme.ToggleBackground,BorderSizePixel=0,Parent=self.Instance}) Create("UICorner",{CornerRadius=UDim.new(1,0),Parent=self.Switch})
	self.Knob=Create("Frame",{Name="Knob",Size=UDim2.fromOffset(ks,ks),Position=UDim2.new(0,(sh-ks)/2,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=self.Theme.ToggleKnobOff,BorderSizePixel=0,Parent=self.Switch,ZIndex=2}) Create("UICorner",{CornerRadius=UDim.new(1,0),Parent=self.Knob})
	self.ClickDetector=Create("TextButton",{Name="ClickDetector",Size=UDim2.new(1,0,1,0),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Text="",Parent=self.Instance,ZIndex=3})
	self:_UpdateVisuals(false) table.insert(connections,self.ClickDetector.MouseButton1Click:Connect(function()self:SetState(not self.State)end)) return self
end
function Toggle:_UpdateVisuals(animate)
	animate=animate and TweenService~=nil local tp,tc local sh,ks=self.Switch.AbsoluteSize.Y,self.Knob.AbsoluteSize.Y
	if self.State then tp=UDim2.new(1,-(sh-ks)/2-self.Switch.AbsoluteSize.X*(1-1),0.5,0) tc=self.Theme.ToggleKnobOn else tp=UDim2.new(0,(sh-ks)/2,0.5,0) tc=self.Theme.ToggleKnobOff end
	if animate then TweenService:Create(self.Knob,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=tp,BackgroundColor3=tc}):Play() else self.Knob.Position=tp self.Knob.BackgroundColor3=tc end
end
function Toggle:SetState(newState,triggerCallback)triggerCallback=triggerCallback==nil if self.State==newState then return end self.State=newState self:_UpdateVisuals(true) if triggerCallback then pcall(self.Callback,self.State)end end
function Toggle:GetState()return self.State end

--- Slider Element ---
Slider = setmetatable({}, ElementBase)
Slider.__index = Slider
function Slider.new(container, config)
	local self=setmetatable(ElementBase.new(),Slider) self.Container=container self.Config=config self.Theme=container.Theme self.Min=config.Min or 0 self.Max=config.Max or 100 self.Default=config.Default or self.Min self.Increment=config.Increment or 1 self.Unit=config.Unit or"" self.Callback=config.Callback or function(v)print("Slider value:",v)end self.Value=self.Default
	self.ContainerInstance=Create("Frame",{Name=config.Name or"NexusSliderContainer",Size=UDim2.new(1,-PADDING.Offset*2,0,ELEMENT_HEIGHT.Offset*1.5),Position=UDim2.new(0,PADDING.Offset,0,0),BackgroundTransparency=1}) self.Instance=self.ContainerInstance
	self.TopRow=Create("Frame",{Name="TopRow",Size=UDim2.new(1,0,0.5,-2),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Parent=self.ContainerInstance})
	self.Label=Create("TextLabel",{Name="SliderLabel",Size=UDim2.new(0.7,-5,1,0),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Font=self.Theme.Font,TextColor3=self.Theme.Text,TextSize=self.Theme.TextSize,Text=config.Text or"Slider",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Parent=self.TopRow})
	self.ValueLabel=Create("TextLabel",{Name="ValueLabel",Size=UDim2.new(0.3,0,1,0),Position=UDim2.new(1,0,0,0),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,Font=self.Theme.Font,TextColor3=self.Theme.Text,TextSize=self.Theme.TextSize,Text="",TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center,Parent=self.TopRow})
	self.BottomRow=Create("Frame",{Name="BottomRow",Size=UDim2.new(1,0,0.5,-2),Position=UDim2.new(0,0,0.5,2),BackgroundTransparency=1,Parent=self.ContainerInstance})
	local th=6 self.Track=Create("Frame",{Name="Track",Size=UDim2.new(1,0,0,th),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=self.Theme.SliderBackground,BorderSizePixel=0,Parent=self.BottomRow,ClipsDescendants=true}) Create("UICorner",{CornerRadius=UDim.new(1,0),Parent=self.Track})
	self.Fill=Create("Frame",{Name="Fill",Size=UDim2.new(0,0,1,0),Position=UDim2.new(0,0,0,0),BackgroundColor3=self.Theme.SliderFill,BorderSizePixel=0,Parent=self.Track,ZIndex=2})
	self.DraggerArea=Create("TextButton",{Name="DraggerArea",Size=UDim2.new(1,0,2.5,0),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Text="",Parent=self.BottomRow,ZIndex=3})
	self:SetValue(self.Default,false) local id=false local dicc=nil local function ufvi(i)local taps,tas=self.Track.AbsolutePosition,self.Track.AbsoluteSize if tas.X==0 then return end local mx=i.Position.X local rx=math.clamp(mx-taps.X,0,tas.X) local p=rx/tas.X local nv=self.Min+(self.Max-self.Min)*p if self.Increment>0 then nv=math.floor(nv/self.Increment+0.5)*self.Increment end nv=math.clamp(nv,self.Min,self.Max) if self.Value~=nv then self:SetValue(nv,true)end end
	table.insert(connections,self.DraggerArea.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then id=true ufvi(i) if dicc then dicc:Disconnect()end dicc=UserInputService.InputChanged:Connect(function(ci)if not id then return end if ci.UserInputType==Enum.UserInputType.MouseMovement or ci.UserInputType==Enum.UserInputType.Touch then ufvi(ci)end end) local iec iec=i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then id=false if dicc then dicc:Disconnect()dicc=nil end if iec then iec:Disconnect()end end end) end end))
	table.insert(connections,UserInputService.InputEnded:Connect(function(i)if id and(i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch)then id=false if dicc then pcall(function()dicc:Disconnect()end) dicc=nil end end end)) return self
end
function Slider:SetValue(newValue,triggerCallback)newValue=math.clamp(newValue,self.Min,self.Max)if self.Increment>0 then newValue=math.floor(newValue/self.Increment+0.5)*self.Increment newValue=math.clamp(newValue,self.Min,self.Max)end if self.Value==newValue then return end self.Value=newValue local r=self.Max-self.Min local p=0 if r~=0 then p=(self.Value-self.Min)/r end TweenService:Create(self.Fill,TweenInfo.new(0.05),{Size=UDim2.new(p,0,1,0)}):Play() local ndp=0 if self.Increment~=0 and math.floor(self.Increment)~=self.Increment then local s=string.format("%f",self.Increment) local dp=s:find("%.")if dp then ndp=#s-dp end ndp=math.max(ndp,2)end if r<=1 and self.Increment<1 and self.Increment~=0 then ndp=2 end self.ValueLabel.Text=string.format("%."..ndp.."f%s",self.Value,self.Unit) if triggerCallback==nil or triggerCallback==true then pcall(self.Callback,self.Value)end end
function Slider:GetValue()return self.Value end

--- Textbox Element ---
Textbox = setmetatable({}, ElementBase)
Textbox.__index = Textbox
function Textbox.new(container, config)
	local self=setmetatable(ElementBase.new(),Textbox) self.Container=container self.Config=config self.Theme=container.Theme self.Callback=config.Callback or function(t)print("Textbox submitted:",t)end self.PlaceholderText=config.PlaceholderText or"" self.ClearOnFocus=config.ClearOnFocus or false
	self.Instance=Create("TextBox",{Name=config.Name or"NexusTextbox",Size=UDim2.new(1,-PADDING.Offset*2,0,ELEMENT_HEIGHT.Offset),Position=UDim2.new(0,PADDING.Offset,0,0),BackgroundColor3=self.Theme.TextboxBackground,BorderSizePixel=1,BorderColor3=self.Theme.TextboxBorder,Font=self.Theme.Font,TextColor3=self.Theme.TextPlaceholder,TextSize=self.Theme.TextSize,Text=config.Text or self.PlaceholderText,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,PlaceholderText="",ClearTextOnFocus=false,MultiLine=config.MultiLine or false}) Create("UICorner",{CornerRadius=UDim.new(0,4),Parent=self.Instance}) Create("UIPadding",{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5),Parent=self.Instance})
	local ipa=false if self.Instance.Text==self.PlaceholderText and self.PlaceholderText~="" then self.Instance.TextColor3=self.Theme.TextPlaceholder ipa=true else self.Instance.TextColor3=self.Theme.Text ipa=false end
	table.insert(connections,self.Instance.Focused:Connect(function()self.Instance.BorderColor3=self.Theme.ButtonHover if ipa then if self.ClearOnFocus or self.Instance.Text==self.PlaceholderText then self.Instance.Text="" self.Instance.TextColor3=self.Theme.Text ipa=false end end end))
	table.insert(connections,self.Instance.FocusLost:Connect(function(ep,_)self.Instance.BorderColor3=self.Theme.TextboxBorder if self.Instance.Text==""and self.PlaceholderText~=""then self.Instance.Text=self.PlaceholderText self.Instance.TextColor3=self.Theme.TextPlaceholder ipa=true else self.Instance.TextColor3=self.Theme.Text ipa=false end if ep and not ipa then pcall(self.Callback,self.Instance.Text)end end))
	if config.ChangedCallback then table.insert(connections,self.Instance.Changed:Connect(function(p)if p=="Text"then if self.Instance.Text~=self.PlaceholderText then ipa=false self.Instance.TextColor3=self.Theme.Text pcall(config.ChangedCallback,self.Instance.Text)elseif self.Instance.Text==""then pcall(config.ChangedCallback,"")end end end))end return self
end
function Textbox:SetText(text)text=text or""self.Instance.Text=text if text==""and self.PlaceholderText~=""then self.Instance.Text=self.PlaceholderText self.Instance.TextColor3=self.Theme.TextPlaceholder elseif text==self.PlaceholderText and self.PlaceholderText~=""then self.Instance.TextColor3=self.Theme.TextPlaceholder else self.Instance.TextColor3=self.Theme.Text end if self.Config.ChangedCallback then pcall(self.Config.ChangedCallback,self:GetText())end end
function Textbox:GetText()if self.Instance.Text==self.PlaceholderText and self.PlaceholderText~=""then return""end return self.Instance.Text end


--[[----------------------------------------------------------------------------
	Main Library API
------------------------------------------------------------------------------]]

--[[** Loads the UI **--]]
function NexusUI:Load(config)
	config = config or {}
	local theme = table.clone(DEFAULT_THEME)
	if config.Theme then for k,v in pairs(config.Theme) do theme[k]=v end end
	local parentGui = config.ParentGui
	if not parentGui then local s,pg=pcall(function()return Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")end) if s and pg then parentGui=pg else if not Players.LocalPlayer then warn("NexusUI Error: Cannot access LocalPlayer...") return nil end warn("NexusUI Warning: Could not find PlayerGui...") return nil end end
	if not (typeof(parentGui)=="Instance" and(parentGui:IsA("ScreenGui")or parentGui:IsA("Folder")or parentGui:IsA("PlayerGui")or parentGui==game:GetService("CoreGui"))) then warn("NexusUI Error: Invalid ParentGui...") return nil end

	self:Destroy() -- Destroy previous

	local screenGui = Create("ScreenGui",{Name="NexusUI_ScreenGui_"..math.random(1000,9999),ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=parentGui,DisplayOrder=1000,Enabled=true})

	local windowObject = nil
	local success, result = pcall(function() windowObject = Window.new(screenGui, config, theme) end)

	if not success or not windowObject or not windowObject.Instance then
		warn("NexusUI Error: Window creation failed.", result)
		pcall(screenGui.Destroy, screenGui)
		currentWindowInstance = nil
		return nil
	end
	return windowObject
end

--[[** Destroys the UI **--]]
function NexusUI:Destroy()
	CleanupConnections()
	if currentWindowInstance and currentWindowInstance.Parent then
		local screenGui = currentWindowInstance:FindFirstAncestorOfClass("ScreenGui")
		if screenGui and screenGui.Name:match("^NexusUI_ScreenGui_") then
			pcall(screenGui.Destroy, screenGui)
		else
			pcall(currentWindowInstance.Destroy, currentWindowInstance)
		end
	elseif currentWindowInstance then
		pcall(currentWindowInstance.Destroy, currentWindowInstance)
	end
	currentWindowInstance = nil
	print("NexusUI Destroyed")
end


return NexusUI
