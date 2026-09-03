-- CategoryService V 2.0.0
-- @Patriots8800
-- Documentation https://example.com

--!strict

----------------------------------------------------------------------------------------------

-- 							[[ Dependencies ]]

const CustomObjects = require("./CategoryService/CustomObjects")

const EasyType = require("./EasyType")
const Logger = require("./Logger")
const SecureClasses = require("./SecureClasses")


----------------------------------------------------------------------------------------------


-- 							[[ Types ]]

type CleanUpInstruction = "All" | "Categories" | "Objects"

export type Category<SubCategories...> = SecureClasses.WrappedMetatable<{
	BindedThread: thread,

	--- Insert: (self: Category<SubCategories...>, SubCategories..., Objects: {any}) -> () -- Waiting for added support
	Insert: (self:Category<SubCategories...>, Objects: {any}, SubCategory:string?) -> (),
    Clean: (((self:Category<SubCategories...>, CleanInstuctions: "All") -> number) & ((self:Category<SubCategories...>, CleanInstuctions: "Categories", ...string) -> number) & ((self:Category<SubCategories...>, CleanInstuctions: "Objects", ...Object | thread) -> number)),
    CleanAndForget: (((self:Category<SubCategories...>, CleanInstuctions: "All") -> number) & ((self:Category<SubCategories...>, CleanInstuctions: "Categories", ...string) -> number) & ((self:Category<SubCategories...>, CleanInstuctions: "Objects", ...Object | thread) -> number)),
    CleanAndDestroy: (((self:Category<SubCategories...>, CleanInstuctions: "All") -> number) & ((self:Category<SubCategories...>, CleanInstuctions: "Categories", ...string) -> number) & ((self:Category<SubCategories...>, CleanInstuctions: "Objects", ...Object | thread) -> number)),
    ForgetSubCategory: <ObjectToRemove>(self:Category<SubCategories...>, SubCategory:string, RemoveSubCategory: boolean?) -> {ObjectToRemove}?,
    ForgetObject: <ObjectToRemove>(self:Category<SubCategories...>, Object:ObjectToRemove) -> ObjectToRemove?,

    Amount: (self:Category<SubCategories...>, SubCategory:(string | "Undefined")?) -> number,
    Contains: (self:Category<SubCategories...>, Object:Object | thread) -> boolean,
}>

type ICategory<SubCategories...> = {
	_TaskTree: {[string]: {any}},
	_QuickLookUpTable: {[any]: string?},

    Clean: (self:ICategory<SubCategories...>, CleanUpInstruction:CleanUpInstruction, ...any) -> number,

	--- Insert: (self: Category<SubCategories...>, SubCategories..., Objects: {any}) -> () -- Waiting for added support
} & Category<...any>



----------------------------------------------------------------------------------------------

-- 							[[ Service Header ]]

const SERVICE_NAME = "CategoryService"


----------------------------------------------------------------------------------------------

-- 							[[ Private functions (helpers) ]]

local BindedThreads: {[thread]: Category<>?} = {}

const CategoryKey = game:GetService("HttpService"):GenerateGUID()

const function BuildTaskTree<T>(...:T) : {[T]:{any}}
	local TaskTree = {}
	TaskTree["Undefined"] = {}

	for _, T:string in { ... } do
		Logger.TypeCheck(T, 1, false, 4, false, "string")

		TaskTree[T] = {}
	end

	return TaskTree
end

const function IsObjectSupported(Object:any): boolean
	return CustomObjects[EasyType(Object, true)] ~= nil or Object.Destroy ~= nil
end

const function RemoveObjectFromTable<T>(T: {T}, Object:T): T?
    for i, V in T do
        if V == Object then
            table.remove(T, i)
            return V
        end
    end
    return nil
end

const function GetLiteralType(O:any): string
    if EasyType(O) == "Instance" then
        if CustomObjects[EasyType(O, true)] then
            return EasyType(O, true)
        end
    end
    return EasyType(O)
end

const function GetDestroyProc<T>(Object:T) : CustomObjects.CategoryDestroyInstructions<T>
    local ObjectType = GetLiteralType(Object)
    if CustomObjects[ObjectType] then
        return CustomObjects[ObjectType]
    else
        return {
            ["MethodOrCall"] = "Method",
            ["FunctionName"] = "Destroy"
        }
    end
end

const function DoCleanProc<T>(T:{T})
    local Count = 0

    for i, Object: any in T do
        local Data = GetDestroyProc(Object)

        if Data.MethodOrCall == "Call" and Data.Library then
            xpcall(function(...)
                Data.Library[Data.FunctionName](...)
                Count += 1
            end, function(err:string)
                Logger.Display("Emphasize", {Object = tostring(Object), Error = err, CleanUpData = Data}, "Object {Object} failed to clean-up it is being ejected from the cache (THIS MAY RESULT IN MEMORY LEAKS): REASON : {Error}", SERVICE_NAME)
            end, Object)

        elseif Data.MethodOrCall == "Method" then
            xpcall(function(...)
                Object[Data.FunctionName](...)
                Count += 1
            end, function(err:string)
                Logger.Display("Emphasize", {Object = tostring(Object), Error = err, CleanUpData = Data}, "Object {Object} failed to clean-up it is being ejected from the cache (THIS MAY RESULT IN MEMORY LEAKS): REASON : {Error}", SERVICE_NAME)
            end, Object)
        end

        T[i] = nil
    end
    
    return Count
end

const function UnstackTable(T: {any}, Final: {any}?): {any}
    Final = Final or {}

    for _, v in T do
        if EasyType(v) == "table" then
            UnstackTable(v, Final)
        else
            table.insert(Final, v)
        end
    end

    return Final
end

const function CleanLookUpCache(LookupCache: {[Object]: string}, ObjectsToClear: {Object})
    for _, O in ObjectsToClear do
        LookupCache[O] = nil
    end
end


----------------------------------------------------------------------------------------------
--					 		[[ MetaData (MetaTable) ]]

const Category = {}
Category.ClassName = "Category"
Category.__typeKey = CategoryKey
Category.__destroy = function(self:ICategory<>)
    BindedThreads[self.BindedThread] = nil
    self.BindedThread = nil :: never
end
Category.__tostring = function(self:ICategory<>)
    return `Category on {self.BindedThread}`
end

-- Update SecureClasses to protect against cleaning against cleaning a running thread

function Category.Insert<T...>(self:ICategory<T...>, Objects: {any}, SubCategory:string?)
	Logger.TypeCheck(Objects, 1, false, 3, false, "table")
	Logger.TypeCheck(SubCategory, 2, true, 3, false, "string")

	local SubCategoryContents = (self[CategoryKey] :: ICategory<T...>)._TaskTree[SubCategory or "Undefined"]
	Logger.Assert(SubCategoryContents ~= nil, `SubCategory {SubCategory} is not a valid SubCategory for Category binded on {tostring(self.BindedThread)}`, 3, SERVICE_NAME)

	local QuickLookUpTable = (self[CategoryKey] :: ICategory<T...>)._QuickLookUpTable
	for _, O: any in Objects do
		Logger.Assert(IsObjectSupported(O), `Object {O} of type {EasyType(O, true)} does not have a supported clean-up method. (Check CustomObjects to declare how custom objects can be destroyed)`, 2, SERVICE_NAME)

		if QuickLookUpTable[O] then
			Logger.Display("Emphasize", {Object = tostring(O), SubCategory = SubCategory or "Undefined"}, "Duplicate object {Object} added; reference is being moved to the most recent updated SubCategory {SubCategory}", SERVICE_NAME)
			self:ForgetObject(O)
		end
		table.insert(SubCategoryContents, O)
		QuickLookUpTable[O] = SubCategory or "Undefined"
	end
end

function Category.Clean<T...>(self:ICategory<T...>, CleanInstuction:CleanUpInstruction, ...:any?)
	Logger.TypeCheck(CleanInstuction, 1, false, 3, true, "All", "Categories", "Objects")
    local ContentsToBeCleaned: { Object }, MetaData = {}, self[CategoryKey] :: ICategory<T...>


    if CleanInstuction == "All" then
        UnstackTable(MetaData._TaskTree, ContentsToBeCleaned)
        for _, v in MetaData._TaskTree do
            table.clear(v)
        end
    elseif CleanInstuction == "Categories" then
        for _, Cat:string in { ... } do
            if MetaData._TaskTree[Cat] then
                UnstackTable(MetaData._TaskTree[Cat], ContentsToBeCleaned)
                table.clear(MetaData._TaskTree[Cat])
            end
        end
    elseif CleanInstuction == "Objects" then
        for _, Object:any in { ... } do
            if self:Contains(Object) then
                local SubCategory = MetaData._QuickLookUpTable[Object] :: string
                table.insert(ContentsToBeCleaned, table.remove(MetaData._TaskTree[SubCategory], table.find(MetaData._TaskTree[SubCategory], Object) :: number) :: Object)
            else
                Logger.Display("Emphasize", {Object = Object, thread = self.BindedThread}, "Object {Object} was not found in Category on {thread} skipping over", SERVICE_NAME)
            end
        end
    end

    CleanLookUpCache(MetaData._QuickLookUpTable, ContentsToBeCleaned)
    return DoCleanProc(ContentsToBeCleaned)
end

function Category.CleanAndForget<T...>(self:ICategory<T...>, CleanInstuction:CleanUpInstruction, ...:any)
    local ObjectsCleaned = self.Clean(self, CleanInstuction, ...)

    if CleanInstuction == "All" then
        for SubCategory, _ in (self[CategoryKey] :: ICategory<T...>)._TaskTree do
            if SubCategory ~= "Undefined" then
                (self[CategoryKey] :: ICategory<T...>)._TaskTree[SubCategory] = nil
            end
        end

    elseif CleanInstuction == "Categories" then
        for _, SubCategory:string in { ... } do
            table.clear((self[CategoryKey] :: ICategory<T...>)._TaskTree[SubCategory])
        end
    end

    return ObjectsCleaned
end

function Category.CleanAndDestroy<T...>(self:ICategory<T...>, CleanInstuction:CleanUpInstruction, ...:string?)
	local ObjectsCleaned = self.Clean(self, CleanInstuction, ...)
    self:Destroy()
    return ObjectsCleaned
end

function Category.ForgetSubCategory<ObjectToRemove, T...>(self:ICategory<T...>, SubCategory:string, RemoveSubCategory: boolean?): { ObjectToRemove }?
	Logger.TypeCheck(SubCategory, 1, false, 3, false, "string")
    Logger.TypeCheck(RemoveSubCategory, 2, true, 3, false, "boolean")

    local MetaData = (self[CategoryKey] :: ICategory<T...>)

    local SubCategoryContents = MetaData._TaskTree[SubCategory]
    --Logger.Assert(SubCategoryContents ~= nil, `SubCategory {SubCategory} is not a valid SubCategory for Category binded on {tostring(self.BindedThread)}`, 3, SERVICE_NAME);

    if SubCategoryContents then
        for _, V:ObjectToRemove in SubCategoryContents do
            MetaData._QuickLookUpTable[V] = nil
        end

        if RemoveSubCategory then
            MetaData._TaskTree[SubCategory] = nil
        else
            table.clear(MetaData._TaskTree[SubCategory])
        end
    end

    return SubCategoryContents
end

function Category.ForgetObject<ObjectToRemove, T...>(self:ICategory<T...>, Object: ObjectToRemove): ObjectToRemove?
	Logger.Assert(Object ~= nil, `Object expected got Nil`, 3, SERVICE_NAME)

    local QuickLookUpTable = (self[CategoryKey] :: ICategory<T...>)._QuickLookUpTable
    local SubCategory = QuickLookUpTable[Object]
    --Logger.Assert(SubCategory ~= nil, `Object {tostring(Object)} was not found in Lookup Cache`, 3, SERVICE_NAME)

    if SubCategory then
        QuickLookUpTable[Object] = nil
        return RemoveObjectFromTable((self[CategoryKey] :: ICategory<T...>)._TaskTree[SubCategory], Object)
    else
        return nil
    end 
end

function Category.Contains<T...>(self:ICategory<T...>, Object: Object): boolean
	Logger.Assert(Object ~= nil, `Object expected got Nil`, 3, SERVICE_NAME)
    return (self[CategoryKey] :: ICategory<T...>)._QuickLookUpTable[Object] ~= nil
end

function Category.Amount<T...>(self:ICategory<T...>, SubCategory: string?): number
    local SubCategoryContents = (self[CategoryKey] :: ICategory<T...>)._TaskTree

    if SubCategory then
        if SubCategoryContents[SubCategory] then
            return #SubCategoryContents[SubCategory]
        else
            return 0
        end
    else
        return #UnstackTable(SubCategoryContents)
    end
end

----------------------------------------------------------------------------------------------
--					 		[[ Public service (constructor) ]]

const CategoryService = {}

function CategoryService.New<T...>(...:string): Category<T...>
	Logger.Assert(BindedThreads[coroutine.running()] == nil, `Attempt to create Category on {tostring(coroutine.running())} that already has a Category assigned to it.`, 3, SERVICE_NAME)

	local self = {}
	self.BindedThread = coroutine.running()
	self._TaskTree = BuildTaskTree(...)
	self._QuickLookUpTable = {}

	const Temp = SecureClasses(self, Category, Category.ClassName) :: Category<T...>

	BindedThreads[Temp.BindedThread] = Temp

	return Temp
end

function CategoryService:GetCategoryOnThread(Thread:thread?): Category<>?
    return BindedThreads[Thread or coroutine.running()]
end

CategoryService.IsObjectSupported = IsObjectSupported

return CategoryService


----------------------------------------------------------------------------------------------

-- Tags: https://eryn.io/moonwave/docs/TagList/

--[=[ 
    @class TEMPLATECLASS
    A class template
]=]

--[=[
    @within TEMPLATECLASS
    @type TEMPLATETYPE Test

    Template type
]=]

--[=[
    @within TEMPLATECLASS
    @interface TEMPLATEINTERFACE

    .T1 TEMPLATETYPE
    .T2 TEMPLATETYPE
    .T3 TEMPLATETYPE

    Template type
]=]

--[=[
    @within TEMPLATECLASS
    @function TEMPLATEFUNCTION

    @param T1 TEMPLATETYPE
    @return TEMPLATEINTERFACE

    Template type

]=]

--[=[
    @within TEMPLATECLASS
    @method TEMPLATEMETHOD

    @param T1 TEMPLATETYPE
    @return TEMPLATEINTERFACE

    Template type

    :::tip
        Tip Container
    :::
    :::info
        info Container
    :::
    :::caution
        caution Container
    :::
    :::danger
        danger Container
    :::

    | Head1 | Head2 | Head3 |
    |-------|-------|-------|
    | Prop1 | Prop2 | Prop3 |
]=]


--[=[
    @within TEMPLATECLASS
    
    @prop TEMPLATEPROPERTY1 boolean

]=]