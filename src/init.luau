-- Category Service V 2.0
-- @Patriots8800

--!strict

----------------------------------------------------------------------------------------------

-- Types
export type Category = {
	--Public category type
	TasksOnThread: { [string]: {[number]:any} },
	ThreadLock: thread,
	ID: string,

    Insert: (self:Category, ...any) -> ()
}

type InternalCategory = {
	__index: InternalCategory,
	ClassName: string,
} & Category
----------------------------------------------------------------------------------------------
-- Service Header
-- A memory manger similar to Collection service

local SERVICE_NAME = "[CategoryService]:"

----------------------------------------------------------------------------------------------

-- Dependenceis

local SmartTable = require("@self/Dependencies/SmartTable")
local EasyType = require("@self/Dependencies/EasyType")
local TramService = require("@self/Dependencies/TramService")

----------------------------------------------------------------------------------------------

-- Private Functions (helpers)

local ActiveThreadCategories: { [thread]: string } = {}

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
local function GetObjectString(object:any) : string
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
            local SubCategory:string = GetObjectString(object)
            table.insert(self.TasksOnThread[SubCategory], object)
		else
			warn(
				string.format(
					"%s Attempt to add %s to category on: [[%s]] with ID: [[%s]].\nObject is not registered in AllowedObjects.\n skipping",
					SERVICE_NAME,
					EasyType(object),
					tostring(self.ThreadLock),
					self.ID
				)
			)
		end
	end
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

	local self = {}
	self.TasksOnThread = BuildTaskTree()
	self.ThreadLock = coroutine.running()

	self.ID = SmartTable.Helper.GenerateUUID()

	ActiveThreadCategories[coroutine.running()] = self.ID
	return setmetatable(self, CategoryServiceMetaData) :: any
end

return CategoryService
