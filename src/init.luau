-- Category Service V 2.0
-- @Patriots8800

--!strict

----------------------------------------------------------------------------------------------

-- Dependenceis

--local SmartTable = require("@self/Dependencies/SmartTable")
local EasyType = require("@self/Dependencies/EasyType")
local TramService = require("@self/Dependencies/TramService")

----------------------------------------------------------------------------------------------

-- Types
export type Category = {
	--Public category type
	TasksOnThread: { [string]: { [number]: any } },
	ThreadLock: thread,

	Insert: (self: Category, ...any) -> (),
	Clean: (self: Category, ..."thread" | "RBXScriptConnection" | "Instance" | "Tween" | "Category") -> (),
	CleanAll: (self: Category) -> (),
	FreeCurrentThread: (self: Category) -> nil,

	Insertion: TramService.ModuleEvent,
}

type InternalCategory = {
	__index: InternalCategory,
	ClassName: string,

	Insertion: TramService.Tram,
} & Category

----------------------------------------------------------------------------------------------
-- Service Header
-- A thread based memory manger similar to Collection service

local SERVICE_NAME = "[CategoryService]:"

----------------------------------------------------------------------------------------------

-- Private Functions (helpers)

local ActiveThreadCategories: { [thread]: Category } = {}

-- A constant
-- Add custom objects here
local AllowedObjects = {
	["RBXScriptConnection"] = {
		["MethodOrCall"] = "Method",
		["FunctionName"] = "Disconnect",
	},
	["thread"] = {
		["MethodOrCall"] = "Call",
		["FunctionName"] = "close",
		["Library"] = coroutine,
	},
	["Instance"] = {
		["MethodOrCall"] = "Method",
		["FunctionName"] = "Destroy",
	},
	["Tween"] = {
		["MethodOrCall"] = "Method",
		["FunctionName"] = "Cancel",
	},

	["Category"] = {
		["MethodOrCall"] = "Method",
		["FunctionName"] = "Destroy",
	},
}

local function CheckIfObjectIsAllowed(object: string): boolean
	return (AllowedObjects[object] ~= nil)
end

-- object must be in allowed objects
local function GetObjectString(object: any): string
	local Type = EasyType(object)

	if Type == "string" then
		return object
	elseif Type == "Instance" and CheckIfObjectIsAllowed(EasyType(object, true)) then
		return EasyType(object, true)
	end
	return Type
end

local function IsObjectAllowed(object: any): boolean
	local Type = EasyType(object)

	if Type == "string" then
		return CheckIfObjectIsAllowed(object)
	else
		return CheckIfObjectIsAllowed(Type)
	end
end

local function IsThreadLocked(thread: thread): boolean
	return (ActiveThreadCategories[thread] ~= nil)
end

local function BuildTaskTree(): {}
	local self = {}
	for Object, _ in AllowedObjects do
		self[Object] = {}
	end
	return self
end
-- ... = What should be cleaned if all then all
local function DoClean(self: Category, WhatShouldBeCleaned: { [number]: string })
	print(WhatShouldBeCleaned)

	for _, SubCategory: string in WhatShouldBeCleaned do
		assert(
			CheckIfObjectIsAllowed(SubCategory),
			string.format("%s Attempt to index %s in Task map got nil", SERVICE_NAME, SubCategory)
		)

		for _, Object: any in self.TasksOnThread[SubCategory] do
			local SubSettings = AllowedObjects[SubCategory]
			local CloseMethod: "Method" | "Call" = SubSettings.MethodOrCall

			if CloseMethod == "Method" then
				xpcall(Object[SubSettings.FunctionName], function(Err: string)
					warn(
						string.format(
							"%s Error occured when trying to clean Subcategory %s as a method on %s\nReason: %s\nRemoving link from category to be Garbage collected",
							SERVICE_NAME,
							SubCategory,
							tostring(self.ThreadLock),
							Err
						)
					)
				end, Object)
			else
				xpcall(SubSettings.Library[SubSettings.FunctionName], function(Err: string)
					warn(
						string.format(
							"%s Error occured when trying to clean Subcategory %s as a function call on %s\nReason: %s\nRemoving link from category to be Garbage collected",
							SERVICE_NAME,
							SubCategory,
							tostring(self.ThreadLock),
							Err
						)
					)
				end, Object)
			end
		end
		-- Clear table of sub-category
		self.TasksOnThread[SubCategory] = {}
	end
end

local function Destroy(self: InternalCategory): never
	ActiveThreadCategories[self.ThreadLock] = nil
	self.Insertion:Disconnect()
	setmetatable(self, nil)
	table.clear(self :: any)
	return self :: never
end

----------------------------------------------------------------------------------------------

-- MetaData (MetaTable)

local CategoryServiceMetaData = {}

CategoryServiceMetaData.__index = CategoryServiceMetaData
CategoryServiceMetaData.ClassName = "Category"

-- Insert function
function CategoryServiceMetaData:Insert(...: any)
	local PackedObjects = { ... }

	for _, object: any in PackedObjects do
		if IsObjectAllowed(object) then
			local SubCategory: string = GetObjectString(object)
			table.insert(self.TasksOnThread[SubCategory], object)
			self.Insertion:Fire(SubCategory)
		else
			warn(
				string.format(
					"%s Attempt to add %s to category on: [[%s]].\nObject is not registered in AllowedObjects.\n skipping",
					SERVICE_NAME,
					EasyType(object),
					tostring(self.ThreadLock)
				)
			)
		end
	end
end

function CategoryServiceMetaData:Clean(...: "thead" | "RBXScriptConnection" | "Instance" | "Tween" | "Category")
	DoClean(self, { ... })
end

function CategoryServiceMetaData:CleanAll()
	local All = {}
	for Object: string, _ in AllowedObjects :: { [string]: any } do
		table.insert(All, Object)
	end
	DoClean(self, All)
end

function CategoryServiceMetaData:FreeCurrentThread(): nil
	assert(
		self.ThreadLock == coroutine.running(),
		string.format(
			"%s Attempt to free thread %s from %s. (Threads must be freed by the same thread they are assigned to)",
			SERVICE_NAME,
			tostring(self.ThreadLock),
			tostring(coroutine.running())
		)
	)
	self:CleanAll()
	return Destroy(self :: InternalCategory)
end

----------------------------------------------------------------------------------------------

-- Public Service (mostly constructors)

local CategoryService = {}

function CategoryService.NewCategory(): Category
	assert(
		not IsThreadLocked(coroutine.running()),
		string.format(
			"\n%s Attempt to assign: [[%s]] while it is already assigned to a category.\n(There can only be 1 category per thread)",
			SERVICE_NAME,
			tostring(coroutine.running())
		)
	)

	local self = setmetatable({}, CategoryServiceMetaData) :: any
	self.TasksOnThread = BuildTaskTree()
	self.ThreadLock = coroutine.running()

	self.Insertion = TramService.NewTram(nil, true) :: TramService.ModuleEvent

	ActiveThreadCategories[coroutine.running()] = self
	return self
end

function CategoryService:GetCategoryOnCurrentThread(): Category?
	return ActiveThreadCategories[coroutine.running()]
end

function CategoryService:CloseCategoryOnCurrentThread(): ()
	local CurrentCategory: Category? = self:GetCategoryOnCurrentThread()
	if CurrentCategory then
		return CurrentCategory:FreeCurrentThread()
	end
end

return CategoryService
