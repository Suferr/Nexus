--[[
	NexusUI - Single File Roblox UI Library
	Version: 0.2.1 (Single File - Improved Drag)

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

	local mainTab = window:AddTab({ Name = "Main" })
	local settingsTab = window:AddTab({ Name = "Settings" })

	-- Elements for Main Tab
	mainTab:AddLabel({ Text = "Welcome!" })

	mainTab:AddButton({
		Text = "Click Me",
		Callback = function()
			print("Button Clicked!")
		end
	})

	local myToggle = mainTab:AddToggle({
		Text = "Enable Feature",
		Default = false,
		Callback = function(newValue)
			print("Toggle changed to:", newValue)
		end
	})

	mainTab:AddButton({
		Text = "Check Toggle State",
		Callback = function()
			print("Current toggle value:", myToggle:GetState()) -- Example of getting state later
		end
	})

	mainTab:AddTextbox({
		Text = "Enter Text...",
		PlaceholderText = "Type here",
		ClearOnFocus = true,
		Callback = function(text)
			print("Textbox submitted:", text)
		end
	})

	-- Elements for Settings Tab
	settingsTab:AddSlider({
		Text = "Volume",
		Min = 0,
		Max = 100,
		Default = 50,
		Increment = 1,
		Unit = "%",
		Callback = function(value)
			print("Slider value:", value)
		end
	})

	settingsTab:AddLabel({ Text = "More settings soon..." })

	-- To destroy the UI later (e.g., on character death or game end)
	-- NexusUI:Destroy()

]]

local NexusUI = {}
NexusUI.Version = "0.2.1" -- Updated version number

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

	Font = Enum.Font.GothamSemibold,
	TextSize = 14,
	TitleTextSize = 16,
}

local PADDING = UDim.new(0, 8) -- General padding for elements
local ELEMENT_HEIGHT = UDim.new(0, 28) -- Standard height for interactive elements
local TITLE_BAR_HEIGHT = UDim.new(0, 30)
local TAB_BUTTON_HEIGHT = UDim.new(0, 30)
local TAB_AREA_WIDTH = UDim.new(0, 120)

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
	local dragStartOffset = Vector2.zero -- Offset from mouse click to guiObject's top-left corner
	local lastInputPosition = Vector2.zero -- Keep track of the last position for delta calculation (optional, useful for touch)
	local inputChangedConnection = nil -- Store the connection to InputChanged

	local function inputBegan(input)
		-- Only start drag on left mouse button or touch
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			-- Check if the click is actually on the handle
			local mousePos = UserInputService:GetMouseLocation()
			local handleAbsPos = dragHandle.AbsolutePosition
			local handleAbsSize = dragHandle.AbsoluteSize

			if mousePos.X >= handleAbsPos.X and mousePos.X <= handleAbsPos.X + handleAbsSize.X and
			   mousePos.Y >= handleAbsPos.Y and mousePos.Y <= handleAbsPos.Y + handleAbsSize.Y then

				dragging = true
				lastInputPosition = input.Position -- Store initial position
				-- Calculate the offset from the GuiObject's top-left corner to the mouse click position
				dragStartOffset = guiObject.AbsolutePosition - input.Position

				-- Prevent text selection/other default actions while dragging
				guiObject.Selectable = false
				dragHandle.Selectable = false -- Also on handle if different

				-- Connect InputChanged *only* when dragging starts
				if inputChangedConnection then inputChangedConnection:Disconnect() end -- Disconnect previous just in case
				inputChangedConnection = UserInputService.InputChanged:Connect(function(changedInput)
					if not dragging then return end -- Exit if not dragging anymore

					-- Process mouse movement or touch drag
					if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
						-- Calculate the new target position based on the current mouse position and the initial offset
						local targetPosition = changedInput.Position + dragStartOffset

						-- Boundary checks considering AnchorPoint
						local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1024, 768)
						local absoluteSize = guiObject.AbsoluteSize
						local anchorPoint = guiObject.AnchorPoint

						-- Calculate min/max allowed positions for the top-left corner
						local minX = -absoluteSize.X * anchorPoint.X
						local maxX = viewportSize.X - absoluteSize.X * (1 - anchorPoint.X)
						local minY = -absoluteSize.Y * anchorPoint.Y
						local maxY = viewportSize.Y - absoluteSize.Y * (1 - anchorPoint.Y)

						-- Clamp the target position
						local clampedX = math.clamp(targetPosition.X, minX, maxX)
						local clampedY = math.clamp(targetPosition.Y, minY, maxY)

						-- Apply the position using Offset only (Scale remains 0)
						guiObject.Position = UDim2.fromOffset(clampedX, clampedY)

						lastInputPosition = changedInput.Position -- Update last position
					end
				end)
				table.insert(connections, inputChangedConnection) -- Track this connection for global cleanup

				-- Ensure dragging stops if input ends while connected
				local inputChangedEndConnection
				inputChangedEndConnection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if inputChangedConnection then
							inputChangedConnection:Disconnect()
							inputChangedConnection = nil
						end
						-- Re-enable selection if needed
						guiObject.Selectable = true
						dragHandle.Selectable = true
						if inputChangedEndConnection then inputChangedEndConnection:Disconnect() end -- Disconnect self
					end
				end)
				-- Don't add inputChangedEndConnection to the main connections table
				-- as it disconnects itself and is tied to the specific input object lifecycle.
			end
		end
	end

	local function inputEnded(input)
		-- Also handle the case where input ends separately (e.g., mouse button up)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then -- Only act if we were actually dragging
				dragging = false
				if inputChangedConnection then
					-- We might have already disconnected in input.Changed, check again
					pcall(function() inputChangedConnection:Disconnect() end)
					inputChangedConnection = nil
				end
				-- Re-enable selection if needed
				guiObject.Selectable = true
				dragHandle.Selectable = true
			end
		end
	end

	-- Connect the primary Began and Ended events
	table.insert(connections, dragHandle.InputBegan:Connect(inputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(inputEnded)) -- Use InputEnded on UserInputService for more robust end detection

end


--[[----------------------------------------------------------------------------
	Core UI Classes / Prototypes (Integrated)
------------------------------------------------------------------------------]]

-- Forward Declarations
local Window, Tab
local Button, Label, Toggle, Slider, Textbox -- Elements

-- Element Base (Common properties/methods - Optional, but good practice)
local ElementBase = {}
ElementBase.__index = ElementBase
function ElementBase.new()
	local self = setmetatable({}, ElementBase)
	self.Instance = nil -- The primary Roblox Instance for this element
	self.Container = nil -- The parent Tab object
	self.Config = {}
	self.Theme = {}
	return self
end
function ElementBase:Destroy()
	if self.Instance then
		pcall(function() self.Instance:Destroy() end) -- Wrap destroy in pcall
		self.Instance = nil
	end
	-- Any specific cleanup for the element would go in overrides of this method
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
	self.TabButtons = {} -- Store references to tab buttons
	self.ActiveTab = nil

	-- Main Window Frame
	self.Instance = Create("Frame", {
		Name = "NexusWindow",
		Size = config.Size,
		Position = UDim2.fromOffset(100, 100), -- Default position, can be overridden
		AnchorPoint = Vector2.new(0, 0), -- Keep AnchorPoint at 0,0 for easier drag calculations initially
		BackgroundColor3 = self.Theme.WindowBackground,
		BorderSizePixel = 1,
		BorderColor3 = self.Theme.Border,
		Parent = screenGui,
		ClipsDescendants = true,
	})
	currentWindowInstance = self.Instance -- Track globally for destroy

	-- Title Bar
	self.TitleBar = Create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT.Offset),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = self.Theme.TitleBar,
		BorderSizePixel = 0,
		Parent = self.Instance,
		ZIndex = 2, -- Ensure TitleBar is above content slightly if needed overlap occurs
	})

	self.TitleLabel = Create("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, -PADDING.Offset * 2, 1, 0),
		Position = UDim2.fromOffset(PADDING.Offset, 0),
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TitleTextSize,
		Text = config.Title or "Nexus UI",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = self.TitleBar,
		ZIndex = 3, -- Above TitleBar background
	})

	-- Main Content Area Container
	self.ContentArea = Create("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT.Offset),
		Position = UDim2.new(0, 0, 0, TITLE_BAR_HEIGHT.Offset),
		BackgroundTransparency = 1, -- Transparent container
		BorderSizePixel = 0,
		Parent = self.Instance,
	})

	-- Tab Button List (Left Side)
	self.TabList = Create("Frame", { -- Changed to Frame for background
		Name = "TabList",
		Size = UDim2.new(0, TAB_AREA_WIDTH.Offset, 1, 0),
		Position = UDim2.new(0,0,0,0),
		BackgroundColor3 = self.Theme.TitleBar, -- Match TitleBar or choose another bg
		BorderSizePixel = 0,
		Parent = self.ContentArea,
	})
	self.TabListLayout = Create("UIListLayout", {
		Parent = self.TabList,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0), -- No padding between tab buttons
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})

	-- Tab Content Area (Right Side)
	self.TabContent = Create("Frame", {
		Name = "TabContent",
		Size = UDim2.new(1, -TAB_AREA_WIDTH.Offset, 1, 0),
		Position = UDim2.new(0, TAB_AREA_WIDTH.Offset, 0, 0),
		BackgroundColor3 = self.Theme.TabContentBackground,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.ContentArea,
	})

	-- Make Draggable (if enabled)
	if config.Draggable ~= false then
		-- Pass the main window instance and the title bar as the handle
		Dragger.Enable(self.Instance, self.TitleBar)
	end

	return self
end

function Window:AddTab(tabConfig)
	local tab = Tab.new(self, tabConfig)
	table.insert(self.Tabs, tab)

	-- Create the corresponding button in the TabList
	local tabButton = Create("TextButton", {
		Name = tabConfig.Name .. "TabButton",
		Size = UDim2.new(1, 0, 0, TAB_BUTTON_HEIGHT.Offset),
		BackgroundColor3 = self.Theme.TabButtonInactive,
		BorderSizePixel = 0,
		Font = self.Theme.Font,
		Text = tabConfig.Name or "Tab",
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TextSize,
		LayoutOrder = #self.Tabs, -- Keep order
		Parent = self.TabList,
		AutoButtonColor = false, -- Manual hover/active states
	})
	self.TabButtons[tab] = tabButton -- Link tab object to button

	-- Style the first tab as active initially
	if #self.Tabs == 1 then
		self:SetActiveTab(tab)
	end

	-- Button Interactions
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

	return tab -- Return the Tab object for adding elements
end

function Window:SetActiveTab(tabToActivate)
	if not tabToActivate or self.ActiveTab == tabToActivate then
		return -- No change or invalid tab
	end

	-- Deactivate previous tab
	if self.ActiveTab then
		if self.ActiveTab.ContainerFrame then -- Check if frame exists
			self.ActiveTab.ContainerFrame.Visible = false
		end
		local oldButton = self.TabButtons[self.ActiveTab]
		if oldButton then
			oldButton.BackgroundColor3 = self.Theme.TabButtonInactive
			oldButton.TextColor3 = self.Theme.Text
		end
	end

	-- Activate new tab
	self.ActiveTab = tabToActivate
	if self.ActiveTab.ContainerFrame then -- Check if frame exists
		self.ActiveTab.ContainerFrame.Visible = true
	end
	local newButton = self.TabButtons[self.ActiveTab]
	if newButton then
		newButton.BackgroundColor3 = self.Theme.TabButtonActive
		newButton.TextColor3 = self.Theme.Text -- Could change text color for active too
	end
end

function Window:Destroy()
	-- Call the global destroy function which handles cleanup
	NexusUI:Destroy()
end


--- Tab Class ---
Tab = {}
Tab.__index = Tab
function Tab.new(window, config)
	local self = setmetatable({}, Tab)
	self.Window = window
	self.Config = config
	self.Theme = window.Theme
	self.Elements = {} -- Store elements belonging to this tab

	-- Container Frame for the tab's content (inside TabContent area)
	self.ContainerFrame = Create("ScrollingFrame", {
		Name = config.Name .. "Content",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1, -- Let TabContent background show
		BorderSizePixel = 0,
		Parent = self.Window.TabContent,
		Visible = false, -- Initially hidden
		CanvasSize = UDim2.new(0, 0, 0, 0), -- Let UIListLayout manage Y size
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = self.Theme.AccentDark,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasPosition = Vector2.zero,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, -- Automatically adjust canvas based on content
	})

	self.Layout = Create("UIListLayout", {
		Parent = self.ContainerFrame,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = PADDING,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, -- Center elements in the tab
		FillDirection = Enum.FillDirection.Vertical,
	})

	-- Padding at the top and bottom of the scroll frame
	Create("UIPadding", {
		Parent = self.ContainerFrame,
		PaddingTop = PADDING,
		PaddingBottom = PADDING,
		PaddingLeft = PADDING,
		PaddingRight = PADDING,
	})

	return self
end

-- Method to add elements dynamically
function Tab:_AddElement(elementInstance, layoutOrder)
	elementInstance.LayoutOrder = layoutOrder or (#self.Elements + 1)
	elementInstance.Parent = self.ContainerFrame
	-- AutomaticCanvasSize handles canvas size now
end

function Tab:Destroy()
	-- Destroy elements associated with this tab
	for _, element in ipairs(self.Elements) do
		if element and element.Destroy then -- Check if element exists and has a destroy method
			pcall(element.Destroy, element) -- Call destroy safely
		elseif element and element.Instance and element.Instance.Parent then -- Check element/instance/parent exist
			pcall(element.Instance.Destroy, element.Instance) -- Fallback destroy
		end
	end
	self.Elements = {}
	if self.ContainerFrame and self.ContainerFrame.Parent then -- Check exists and parented
		pcall(self.ContainerFrame.Destroy, self.ContainerFrame)
		self.ContainerFrame = nil
	end
end

-- Element Factory Methods (Add these to the Tab prototype)
function Tab:AddLabel(elemConfig)
	local label = Label.new(self, elemConfig)
	table.insert(self.Elements, label)
	self:_AddElement(label.Instance)
	return label -- Return the element object if needed
end

function Tab:AddButton(elemConfig)
	local button = Button.new(self, elemConfig)
	table.insert(self.Elements, button)
	self:_AddElement(button.Instance)
	return button
end

function Tab:AddToggle(elemConfig)
	local toggle = Toggle.new(self, elemConfig)
	table.insert(self.Elements, toggle)
	self:_AddElement(toggle.Instance)
	return toggle
end

function Tab:AddSlider(elemConfig)
	local slider = Slider.new(self, elemConfig)
	table.insert(self.Elements, slider)
	self:_AddElement(slider.ContainerInstance) -- Add the container for sliders
	return slider
end

function Tab:AddTextbox(elemConfig)
	local textbox = Textbox.new(self, elemConfig)
	table.insert(self.Elements, textbox)
	self:_AddElement(textbox.Instance)
	return textbox
end


--[[----------------------------------------------------------------------------
	UI Element Classes (Integrated)
------------------------------------------------------------------------------]]

--- Label Element ---
Label = setmetatable({}, ElementBase)
Label.__index = Label
function Label.new(container, config)
	local self = setmetatable(ElementBase.new(), Label)
	self.Container = container
	self.Config = config
	self.Theme = container.Theme

	self.Instance = Create("TextLabel", {
		Name = config.Name or "NexusLabel",
		Size = UDim2.new(1, -PADDING.Offset * 2, 0, config.Height or self.Theme.TextSize + 4), -- Base height
		Position = UDim2.new(0, PADDING.Offset, 0, 0), -- Position managed by Layout
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextColor3 = config.Color or self.Theme.Text,
		TextSize = config.TextSize or self.Theme.TextSize,
		Text = config.Text or "Label",
		TextWrapped = config.Wrap or true,
		TextXAlignment = config.Align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, -- Usually better with AutomaticSize
		AutomaticSize = Enum.AutomaticSize.Y, -- Allow label to grow vertically if wrapped
	})
	-- Add padding inside the label itself if needed, or rely on ListLayout padding
	-- Create("UIPadding", { PaddingLeft = UDim.new(0,4), Parent=self.Instance})
	return self
end

--- Button Element ---
Button = setmetatable({}, ElementBase)
Button.__index = Button
function Button.new(container, config)
	local self = setmetatable(ElementBase.new(), Button)
	self.Container = container
	self.Config = config
	self.Theme = container.Theme
	self.Callback = config.Callback or function() print("Button clicked: "..(config.Text or "Untitled")) end

	self.Instance = Create("TextButton", {
		Name = config.Name or "NexusButton",
		Size = UDim2.new(1, -PADDING.Offset * 2, 0, ELEMENT_HEIGHT.Offset),
		Position = UDim2.new(0, PADDING.Offset, 0, 0),
		BackgroundColor3 = self.Theme.Button,
		BorderSizePixel = 0,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TextSize,
		Text = config.Text or "Button",
		AutoButtonColor = false, -- Handle hover/press manually
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = self.Instance })

	-- Interactions
	table.insert(connections, self.Instance.MouseButton1Click:Connect(function()
		pcall(self.Callback) -- Wrap callback in pcall for safety
	end))
	table.insert(connections, self.Instance.MouseEnter:Connect(function()
		TweenService:Create(self.Instance, TweenInfo.new(0.1), { BackgroundColor3 = self.Theme.ButtonHover }):Play()
	end))
	table.insert(connections, self.Instance.MouseLeave:Connect(function()
		TweenService:Create(self.Instance, TweenInfo.new(0.1), { BackgroundColor3 = self.Theme.Button }):Play()
	end))
	table.insert(connections, self.Instance.MouseButton1Down:Connect(function()
		TweenService:Create(self.Instance, TweenInfo.new(0.05), { BackgroundColor3 = self.Theme.ButtonPressed }):Play()
	end))
	table.insert(connections, self.Instance.MouseButton1Up:Connect(function()
		-- Check if mouse is still over the button on release
		local mousePos = UserInputService:GetMouseLocation()
		local btnPos = self.Instance.AbsolutePosition
		local btnSize = self.Instance.AbsoluteSize
		local targetColor = self.Theme.Button
		if mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X and
		   mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y then
			targetColor = self.Theme.ButtonHover
		end
		TweenService:Create(self.Instance, TweenInfo.new(0.1), { BackgroundColor3 = targetColor }):Play()
	end))

	return self
end

--- Toggle Element ---
Toggle = setmetatable({}, ElementBase)
Toggle.__index = Toggle
function Toggle.new(container, config)
	local self = setmetatable(ElementBase.new(), Toggle)
	self.Container = container
	self.Config = config
	self.Theme = container.Theme
	self.Callback = config.Callback or function(state) print("Toggle changed:", state) end
	self.State = config.Default or false

	-- Main container Frame for the toggle
	self.Instance = Create("Frame", {
		Name = config.Name or "NexusToggleContainer",
		Size = UDim2.new(1, -PADDING.Offset * 2, 0, ELEMENT_HEIGHT.Offset),
		Position = UDim2.new(0, PADDING.Offset, 0, 0),
		BackgroundTransparency = 1, -- Container is transparent
	})

	-- Label for the toggle
	self.Label = Create("TextLabel", {
		Name = "ToggleLabel",
		Size = UDim2.new(1, -50, 1, 0), -- Adjusted size to leave space for switch+padding
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TextSize,
		Text = config.Text or "Toggle",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = self.Instance,
	})

	-- Switch background
	local switchWidth = 40
	local switchHeight = ELEMENT_HEIGHT.Offset * 0.6
	local knobSize = switchHeight * 0.8

	self.Switch = Create("Frame", {
		Name = "SwitchBackground",
		Size = UDim2.fromOffset(switchWidth, switchHeight),
		Position = UDim2.new(1, -PADDING.Offset, 0.5, 0), -- Position right, centered vertically
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = self.Theme.ToggleBackground,
		BorderSizePixel = 0,
		Parent = self.Instance,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.Switch }) -- Pill shape

	-- Switch Knob
	self.Knob = Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(knobSize, knobSize),
		Position = UDim2.new(0, (switchHeight - knobSize)/2, 0.5, 0), -- Initial left pos
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self.Theme.ToggleKnobOff,
		BorderSizePixel = 0,
		Parent = self.Switch,
		ZIndex = 2,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.Knob }) -- Circle shape

	-- Click area (covers the whole element for easier clicking)
	self.ClickDetector = Create("TextButton", {
		Name = "ClickDetector",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = self.Instance,
		ZIndex = 3, -- Make sure it's clickable above others
	})

	-- Set initial state visually
	self:_UpdateVisuals(false) -- No animation initially

	-- Interactions
	table.insert(connections, self.ClickDetector.MouseButton1Click:Connect(function()
		self:SetState(not self.State) -- Toggle state
	end))

	return self
end

function Toggle:_UpdateVisuals(animate)
	animate = animate and TweenService ~= nil -- Check if animation is requested and possible

	local targetPos
	local targetColor
	local switchHeight = self.Switch.AbsoluteSize.Y -- Use AbsoluteSize for accuracy
	local knobSize = self.Knob.AbsoluteSize.Y

	if self.State then
		targetPos = UDim2.new(1, -(switchHeight - knobSize)/2 - self.Switch.AbsoluteSize.X * (1-1), 0.5, 0) -- Right pos relative to switch width
		targetColor = self.Theme.ToggleKnobOn
	else
		targetPos = UDim2.new(0, (switchHeight - knobSize)/2, 0.5, 0) -- Left pos relative to switch width
		targetColor = self.Theme.ToggleKnobOff
	end


	if animate then
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local knobTween = TweenService:Create(self.Knob, tweenInfo, { Position = targetPos, BackgroundColor3 = targetColor })
		knobTween:Play()
	else
		self.Knob.Position = targetPos
		self.Knob.BackgroundColor3 = targetColor
	end
end

function Toggle:SetState(newState, triggerCallback)
	triggerCallback = triggerCallback == nil -- Default to true if not specified
	if self.State == newState then return end -- No change

	self.State = newState
	self:_UpdateVisuals(true) -- Animate the change

	if triggerCallback then
		pcall(self.Callback, self.State) -- Call the user's callback function
	end
end

function Toggle:GetState()
	return self.State
end

--- Slider Element ---
Slider = setmetatable({}, ElementBase)
Slider.__index = Slider
function Slider.new(container, config)
	local self = setmetatable(ElementBase.new(), Slider)
	self.Container = container
	self.Config = config
	self.Theme = container.Theme

	self.Min = config.Min or 0
	self.Max = config.Max or 100
	self.Default = config.Default or self.Min
	self.Increment = config.Increment or 1
	self.Unit = config.Unit or ""
	self.Callback = config.Callback or function(value) print("Slider value:", value) end
	self.Value = self.Default

	-- Container Frame for the slider and its labels
	self.ContainerInstance = Create("Frame", {
		Name = config.Name or "NexusSliderContainer",
		Size = UDim2.new(1, -PADDING.Offset * 2, 0, ELEMENT_HEIGHT.Offset * 1.5), -- Taller for label/value display
		Position = UDim2.new(0, PADDING.Offset, 0, 0),
		BackgroundTransparency = 1,
	})
	self.Instance = self.ContainerInstance -- Main instance for layouting

	-- Top Row: Label (Left) and Value Display (Right)
	self.TopRow = Create("Frame", {
		Name = "TopRow",
		Size = UDim2.new(1, 0, 0.5, -2), -- Half height minus small padding
		Position = UDim2.new(0,0,0,0),
		BackgroundTransparency = 1,
		Parent = self.ContainerInstance,
	})

	self.Label = Create("TextLabel", {
		Name = "SliderLabel",
		Size = UDim2.new(0.7, -5, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TextSize,
		Text = config.Text or "Slider",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = self.TopRow,
	})

	self.ValueLabel = Create("TextLabel", {
		Name = "ValueLabel",
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.Text,
		TextSize = self.Theme.TextSize,
		Text = "", -- Will be updated
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = self.TopRow,
	})

	-- Bottom Row: Slider Track and Fill
	self.BottomRow = Create("Frame", {
		Name = "BottomRow",
		Size = UDim2.new(1, 0, 0.5, -2), -- Half height minus small padding
		Position = UDim2.new(0,0,0.5, 2), -- Positioned below top row
		BackgroundTransparency = 1,
		Parent = self.ContainerInstance,
	})

	local trackHeight = 6
	self.Track = Create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, trackHeight),
		Position = UDim2.new(0, 0, 0.5, 0), -- Centered vertically in bottom row
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = self.Theme.SliderBackground,
		BorderSizePixel = 0,
		Parent = self.BottomRow,
		ClipsDescendants = true, -- Clip the fill bar
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self.Track })

	self.Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0), -- Width determined by value
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = self.Theme.SliderFill,
		BorderSizePixel = 0,
		Parent = self.Track,
		ZIndex = 2,
	})
	-- Optional Knob Visual
	-- self.KnobVisual = Create("Frame", { ... ZIndex = 3 ...})

	-- Draggable Area (covers the track for interaction)
	self.DraggerArea = Create("TextButton", { -- Use TextButton for input events
		Name = "DraggerArea",
		Size = UDim2.new(1, 0, 2.5, 0), -- Make taller than track for easier clicking/dragging vertically
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1, -- Invisible
		Text = "",
		Parent = self.BottomRow,
		ZIndex = 3, -- Above track/fill
	})

	-- Set initial value and text
	self:SetValue(self.Default, false) -- Set initial value without triggering callback

	-- Interactions
	local isDragging = false
	local dragInputChangedConn = nil -- Connection specific to slider drag

	local function updateValueFromInput(input)
		local trackAbsPos = self.Track.AbsolutePosition
		local trackAbsSize = self.Track.AbsoluteSize
		-- Ensure trackAbsSize.X is not zero to prevent division by zero
		if trackAbsSize.X == 0 then return end

		local mouseX = input.Position.X

		local relativeX = math.clamp(mouseX - trackAbsPos.X, 0, trackAbsSize.X)
		local percentage = relativeX / trackAbsSize.X
		local newValue = self.Min + (self.Max - self.Min) * percentage

		-- Snap to increment
		if self.Increment > 0 then
			newValue = math.floor(newValue / self.Increment + 0.5) * self.Increment
		end
		newValue = math.clamp(newValue, self.Min, self.Max)

		if self.Value ~= newValue then
			self:SetValue(newValue, true) -- Set value and trigger callback
		end
	end

	table.insert(connections, self.DraggerArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			updateValueFromInput(input) -- Update immediately on click

			-- Connect InputChanged only during drag
			if dragInputChangedConn then dragInputChangedConn:Disconnect() end -- Disconnect old if any
			dragInputChangedConn = UserInputService.InputChanged:Connect(function(changedInput)
				if not isDragging then return end
				if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
					updateValueFromInput(changedInput)
				end
			end)
			-- No need to add dragInputChangedConn to main connections, managed locally

			-- Disconnect drag listener when input ends
			local inputChangedEndConn
			inputChangedEndConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDragging = false
					if dragInputChangedConn then dragInputChangedConn:Disconnect() dragInputChangedConn = nil end
					if inputChangedEndConn then inputChangedEndConn:Disconnect() end
				end
			end)
		end
	end))

	-- Use InputEnded on UserInputService as a fallback / definite end
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			isDragging = false
			if dragInputChangedConn then
				pcall(function() dragInputChangedConn:Disconnect() end) -- Disconnect safely
				dragInputChangedConn = nil
			end
		end
	end))


	return self
end

function Slider:SetValue(newValue, triggerCallback)
	newValue = math.clamp(newValue, self.Min, self.Max)
	if self.Increment > 0 then -- Ensure it aligns with increment if set externally
		newValue = math.floor(newValue / self.Increment + 0.5) * self.Increment
		-- Re-clamp after rounding, especially important if Min/Max aren't multiples of Increment
		newValue = math.clamp(newValue, self.Min, self.Max)
	end

	if self.Value == newValue then return end -- No change

	self.Value = newValue

	-- Update Visuals
	local range = self.Max - self.Min
	local percentage = 0
	if range ~= 0 then -- Avoid division by zero
		percentage = (self.Value - self.Min) / range
	end

	-- Use TweenService for smoother fill animation (optional)
	local tweenInfo = TweenInfo.new(0.05) -- Quick tween
	TweenService:Create(self.Fill, tweenInfo, { Size = UDim2.new(percentage, 0, 1, 0) }):Play()

	-- Also update optional Knob position if implemented
	-- if self.KnobVisual then
	--    self.KnobVisual.Position = UDim2.new(percentage, -self.KnobVisual.AbsoluteSize.X * 0.5, 0.5, 0)
	-- end

	-- Format value string: show decimals only if increment is not a whole number or is zero
	local numDecimalPlaces = 0
	if self.Increment ~= 0 and math.floor(self.Increment) ~= self.Increment then
		-- Crude way to find decimal places, better methods exist
		local s = string.format("%f", self.Increment)
		local dotPos = s:find("%.")
		if dotPos then numDecimalPlaces = #s - dotPos end
		numDecimalPlaces = math.max(numDecimalPlaces, 2) -- Show at least 2 if increment has decimals
	end
	-- Special case: If range is small and increment allows decimals, show more precision
	if range <= 1 and self.Increment < 1 and self.Increment ~= 0 then numDecimalPlaces = 2 end

	self.ValueLabel.Text = string.format("%."..numDecimalPlaces.."f%s", self.Value, self.Unit)

	if triggerCallback == nil or triggerCallback == true then
		pcall(self.Callback, self.Value) -- Trigger callback
	end
end

function Slider:GetValue()
	return self.Value
end

--- Textbox Element ---
Textbox = setmetatable({}, ElementBase)
Textbox.__index = Textbox
function Textbox.new(container, config)
	local self = setmetatable(ElementBase.new(), Textbox)
	self.Container = container
	self.Config = config
	self.Theme = container.Theme
	self.Callback = config.Callback or function(text) print("Textbox submitted:", text) end
	self.PlaceholderText = config.PlaceholderText or ""
	self.ClearOnFocus = config.ClearOnFocus or false

	self.Instance = Create("TextBox", {
		Name = config.Name or "NexusTextbox",
		Size = UDim2.new(1, -PADDING.Offset * 2, 0, ELEMENT_HEIGHT.Offset),
		Position = UDim2.new(0, PADDING.Offset, 0, 0),
		BackgroundColor3 = self.Theme.TextboxBackground,
		BorderSizePixel = 1,
		BorderColor3 = self.Theme.TextboxBorder,
		Font = self.Theme.Font,
		TextColor3 = self.Theme.TextPlaceholder, -- Start with placeholder color if text matches
		TextSize = self.Theme.TextSize,
		Text = config.Text or self.PlaceholderText, -- Start with default or placeholder
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		PlaceholderText = "", -- Use manual placeholder logic for color
		-- PlaceholderColor3 = self.Theme.TextPlaceholder, -- Can't directly use, do it manually
		ClearTextOnFocus = false, -- Handle manually for placeholder logic
		MultiLine = config.MultiLine or false, -- Optional multiline support
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = self.Instance })
	Create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = self.Instance}) -- Inner padding

	-- Placeholder logic initial setup
	local isPlaceholderActive = false -- Track if the displayed text is the placeholder
	if self.Instance.Text == self.PlaceholderText and self.PlaceholderText ~= "" then
		self.Instance.TextColor3 = self.Theme.TextPlaceholder
		isPlaceholderActive = true
	else
		self.Instance.TextColor3 = self.Theme.Text
		isPlaceholderActive = false
	end

	table.insert(connections, self.Instance.Focused:Connect(function()
		self.Instance.BorderColor3 = self.Theme.ButtonHover -- Highlight border on focus
		if isPlaceholderActive then
			if self.ClearOnFocus or self.Instance.Text == self.PlaceholderText then -- Double check text content
				self.Instance.Text = ""
				self.Instance.TextColor3 = self.Theme.Text
				isPlaceholderActive = false
			end
		end
	end))

	table.insert(connections, self.Instance.FocusLost:Connect(function(enterPressed, inputThatCausedFocusLoss)
		self.Instance.BorderColor3 = self.Theme.TextboxBorder -- Revert border
		if self.Instance.Text == "" and self.PlaceholderText ~= "" then
			self.Instance.Text = self.PlaceholderText
			self.Instance.TextColor3 = self.Theme.TextPlaceholder
			isPlaceholderActive = true
		else
			-- Even if text wasn't empty, ensure correct color if it wasn't placeholder
			self.Instance.TextColor3 = self.Theme.Text
			isPlaceholderActive = false
		end

		if enterPressed and not isPlaceholderActive then -- Only callback if enter pressed AND not showing placeholder
			pcall(self.Callback, self.Instance.Text) -- Trigger callback on enter
		end
	end))

	-- Optional: Callback on text changed (can be noisy)
	if config.ChangedCallback then
		table.insert(connections, self.Instance.Changed:Connect(function(property)
			-- Only callback if the actual value changed and it's not currently a placeholder being displayed
			if property == "Text" then
				if self.Instance.Text ~= self.PlaceholderText then
					isPlaceholderActive = false
					self.Instance.TextColor3 = self.Theme.Text -- Ensure correct color
					pcall(config.ChangedCallback, self.Instance.Text)
				elseif self.Instance.Text == "" then
					-- If text becomes empty (e.g., backspace all), it might show placeholder later on FocusLost
					-- We can optionally trigger callback with empty string here if needed.
					pcall(config.ChangedCallback, "")
				end
			end
		end))
	end

	return self
end

function Textbox:SetText(text)
	text = text or ""
	self.Instance.Text = text
	if text == "" and self.PlaceholderText ~= "" then
		self.Instance.Text = self.PlaceholderText
		self.Instance.TextColor3 = self.Theme.TextPlaceholder
		-- isPlaceholderActive should be true here, but FocusLost handles this state usually
	elseif text == self.PlaceholderText and self.PlaceholderText ~= "" then
		self.Instance.TextColor3 = self.Theme.TextPlaceholder
		-- isPlaceholderActive = true
	else
		self.Instance.TextColor3 = self.Theme.Text
		-- isPlaceholderActive = false
	end
	-- Manually trigger ChangedCallback if it exists and behavior is desired
	if self.Config.ChangedCallback then
		pcall(self.Config.ChangedCallback, self:GetText()) -- Use GetText to handle placeholder logic
	end
end

function Textbox:GetText()
	if self.Instance.Text == self.PlaceholderText and self.PlaceholderText ~= "" then
		return "" -- Return empty if it's just the placeholder
	end
	return self.Instance.Text
end


--[[----------------------------------------------------------------------------
	Main Library API
------------------------------------------------------------------------------]]

--[[**
	Initializes the UI library and creates the main window.
	@param config Table Configuration options for the window.
		* Title (string): The title displayed on the window. (Default: "Nexus UI")
		* Size (UDim2): The size of the window. (Default: 500x350)
		* Draggable (boolean): Whether the window can be dragged. (Default: true)
		* Theme (table): Optional theme table to override defaults.
		* ParentGui (Instance): Where to parent the ScreenGui. (Default: PlayerGui)
	@returns Window The main Window object, allowing tab/element creation, or nil if failed.
**--]]
function NexusUI:Load(config)
	config = config or {}
	local theme = table.clone(DEFAULT_THEME) -- Start with default
	if config.Theme then -- Merge custom theme over default
		for k, v in pairs(config.Theme) do
			theme[k] = v
		end
	end
	local parentGui = config.ParentGui

	-- Determine parent GUI if not provided
	if not parentGui then
		local success, playerGui = pcall(function() return Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") end)
		if success and playerGui then
			parentGui = playerGui
		else
			-- More specific warning if LocalPlayer isn't available
			if not Players.LocalPlayer then
				warn("NexusUI Error: Cannot access LocalPlayer. Ensure this is run from a LocalScript.")
				return nil
			end
			-- Fallback or error if PlayerGui is not available
			warn("NexusUI Warning: Could not find PlayerGui for LocalPlayer:", Players.LocalPlayer, ". UI will not be created.")
			return nil
		end
	end

	-- Ensure ParentGui is valid
	if not (typeof(parentGui) == "Instance" and (parentGui:IsA("ScreenGui") or parentGui:IsA("Folder") or parentGui:IsA("PlayerGui") or parentGui == game:GetService("CoreGui"))) then
		warn("NexusUI Error: Invalid ParentGui provided. Must be a valid GUI container.")
		return nil
	end


	-- Destroy previous UI if it exists
	self:Destroy() -- Use the Destroy method which handles cleanup

	-- Create the main ScreenGui
	local screenGui = Create("ScreenGui", {
		Name = "NexusUI_ScreenGui_" .. math.random(1000, 9999), -- Unique name
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, -- Or Global if needed for CoreGui
		Parent = parentGui,
		DisplayOrder = 1000, -- Try to render on top
		Enabled = true,
	})

	-- Create the Window instance using the integrated class
	local windowObject = nil
	local success, result = pcall(function()
		windowObject = Window.new(screenGui, config, theme)
	end)

	if not success or not windowObject or not windowObject.Instance then
		warn("NexusUI Error: Window creation failed.", result)
		pcall(screenGui.Destroy, screenGui) -- Clean up the ScreenGui if window failed
		currentWindowInstance = nil -- Ensure global tracker is nil
		return nil
	end

	-- Return the window object so the user can add tabs/elements
	return windowObject
end

--[[**
	Destroys the currently active NexusUI window and all associated elements/connections.
**--]]
function NexusUI:Destroy()
	-- Disconnect all tracked connections first
	CleanupConnections()

	if currentWindowInstance and currentWindowInstance.Parent then
		-- Find the ScreenGui parent reliably
		local screenGui = currentWindowInstance:FindFirstAncestorOfClass("ScreenGui")
		if screenGui and screenGui.Name:match("^NexusUI_ScreenGui_") then
			-- Destroy the ScreenGui, which removes everything parented to it
			pcall(screenGui.Destroy, screenGui)
		else
			-- If parent isn't the expected ScreenGui (shouldn't happen with Load logic),
			-- just destroy the window frame as a fallback.
			pcall(currentWindowInstance.Destroy, currentWindowInstance)
		end
	elseif currentWindowInstance then
		-- If instance exists but no parent (already removed?), try destroying directly.
		pcall(currentWindowInstance.Destroy, currentWindowInstance)
	end

	-- Clear state regardless
	currentWindowInstance = nil
	-- Note: Child tabs/elements are destroyed when their parent (ScreenGui or Window Frame) is destroyed.
	-- Manual destruction loops in Window/Tab destroy methods are mostly for internal state cleanup now.
	print("NexusUI Destroyed")
end


return NexusUI
