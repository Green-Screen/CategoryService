local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CategoryService = require("../")
local EasyType = require("../Dependencies/EasyType")
local TramService = require("../Dependencies/TramService")

-- Creates a thread linked category
local TestCategory1 = CategoryService.NewCategory()
print(TestCategory1)

-- Creates a sub thread category
local SubThreadCategory

task.spawn(function()
	SubThreadCategory = CategoryService.NewCategory()
end)

-- Objects to test with
local TweenObject1: Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject2: Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject3: Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject4: Tween = TweenService:Create(workspace, TweenInfo.new(), {})
local TweenObject5: Tween = TweenService:Create(workspace, TweenInfo.new(), {})

local Thread1 = task.spawn(function() end)
local Thread2 = task.spawn(function() end)
local Thread3 = task.spawn(function() end)
local Thread4 = task.spawn(function() end)
local Thread5 = task.spawn(function() end)

local Connection1 = RunService.Heartbeat:Connect(function(a0: number) end)
local Connection2 = RunService.Heartbeat:Connect(function(a0: number) end)
local Connection3 = RunService.Heartbeat:Connect(function(a0: number) end)
local Connectiom4 = RunService.Heartbeat:Connect(function(a0: number) end)
local Connection5 = RunService.Heartbeat:Connect(function(a0: number) end)

-- Insertion test
TestCategory1:Insert(TweenObject1, TweenObject2, TweenObject3, TweenObject4, TweenObject5)
TestCategory1:Insert(Thread1, Thread2, Thread3, Thread4, Thread5)
TestCategory1:Insert(Connection1, Connection2, Connection3, Connectiom4, Connection5)

print(TestCategory1)

-- Creates a delayed thread to resume the yielded thread
task.delay(4, function()
	local P = Instance.new("Part")
	print(CategoryService:GetCategoryOnCurrentThread())
	while task.wait(1) do
		TestCategory1:Insert(P)
	end
end)

-- Event for insertion
TestCategory1.Insertion:Connect(function(SubCategory: string)
	print(SubCategory, "Was inserted to category on:", TestCategory1.ThreadLock)
end)

-- Event insertion wait
TestCategory1.Insertion:Wait()

-- empties and cleans given categories
TestCategory1:Clean("Category", "RBXScriptConnection", "Instance", "thread")

-- Debug tasks
print(TestCategory1.TasksOnThread)

-- Check if they are properly removed 

-- This is to check if indexing and instancing is correct
for _, v: thread in TestCategory1.TasksOnThread.thread do
	print(v, coroutine.status(v))
end

-- Cleans the thread and destroys the category object
TestCategory1:FreeCurrentThread()

-- tests to make sure it is completly cleaned and deallocated
warn(TestCategory1, getmetatable(TestCategory1))

TestCategory1:Insert(Connection1)

print(CategoryService:GetCategoryOnCurrentThread()) -- nil

local NewCat = CategoryService.NewCategory()

print("-------------------------------------------------------------------------")

print(CategoryService:GetCategoryOnCurrentThread()) -- thread object

CategoryService:CloseCategoryOnCurrentThread() -- Closes the current category linked to thread (NewCat) 

print(NewCat, CategoryService:GetCategoryOnCurrentThread()) -- nil, nil

SubThreadCategory:FreeCurrentThread()