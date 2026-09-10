--!strict
--!optimize 2

--> [`toolbar`]
local Toolbar = plugin:CreateToolbar("Éclat")
local Toggle = Toolbar:CreateButton("EclatOpen", "Open Éclat", "", "Éclat")

local EclatData = script.Parent:WaitForChild("EclatData") :: ModuleScript
local Eclat = require(EclatData)

Toggle.Click:Connect(function()
	Eclat.open(plugin)
end)
