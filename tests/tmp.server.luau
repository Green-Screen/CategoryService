--!strict

local CategoryService = require(game:GetService("ReplicatedFirst").CategoryService.CategoryService)

local Test = CategoryService.New("Threads")

local ThreadObject1 = coroutine.create(function(...) end)
local ThreadObject2 = coroutine.create(function(...) end)
local ThreadObject3 = coroutine.create(function(...) end)
local ThreadObject4 = coroutine.create(function(...) end)
local ThreadObject5 = coroutine.create(function(...) end)
local ThreadObject6 = coroutine.create(function(...) end)

print(CategoryService.IsObjectSupported({}))

Test:Insert({ThreadObject1, ThreadObject2, ThreadObject3, ThreadObject4, ThreadObject5}, "Threads")
Test:Insert({ThreadObject6})

print(Test, getmetatable(Test).__metadata)

print(Test:Contains(ThreadObject6))

warn(Test:ForgetObject(ThreadObject3))
warn(Test:ForgetObject(ThreadObject2))

print(Test, getmetatable(Test).__metadata)

--Test:Clean("Objects", ThreadObject1)

print(Test, getmetatable(Test).__metadata)

--Test:Clean("Categories", "Threads")

print(Test, getmetatable(Test).__metadata)

warn(Test.Operatable)

print(Test:Clean("All"))

warn(Test.Operatable)

print(CategoryService:GetCategoryOnThread())

Test:Destroy()

print(CategoryService:GetCategoryOnThread())