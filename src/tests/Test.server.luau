local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CategoryService = require("../")
local EasyType = require("../Dependencies/EasyType")
local TramService = require("../Dependencies/TramService")

local TestCategory1 = CategoryService.NewCategory()
print(TestCategory1)

local SubThreadCategory

task.spawn(function()
    SubThreadCategory = CategoryService.NewCategory()
end)


local TweenObject1:Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject2:Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject3:Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject4:Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject5:Tween = TweenService:Create(workspace, TweenInfo.new(), {})

local Thread1 = task.spawn(function() end)
local Thread2 = task.spawn(function() end)
local Thread3 = task.spawn(function() end)
local Thread4 = task.spawn(function() end)
local Thread5 = task.spawn(function() end)

local Connection1 = RunService.Heartbeat:Connect(function(a0: number)  end)
local Connection2 = RunService.Heartbeat:Connect(function(a0: number)  end)
local Connection3 = RunService.Heartbeat:Connect(function(a0: number)  end)
local Connectiom4 = RunService.Heartbeat:Connect(function(a0: number)  end)
local Connection5 = RunService.Heartbeat:Connect(function(a0: number)  end)




TestCategory1:Insert(TweenObject1, TweenObject2, TweenObject3, TweenObject4, TweenObject5)
TestCategory1:Insert(Thread1, Thread2, Thread3, Thread4, Thread5)
TestCategory1:Insert(Connection1, Connection2, Connection3, Connectiom4, Connection5)

print(TestCategory1)