-- Main type
--!strict

export type Tram = {
	FunctionsBinded: { [string]: any },
	YeildingThreads: {[string] : thread},
	TransversableID: string?,
	Callback: boolean?,
	Timeout: number,
	BindID: string,

	Connect: (self: Tram, (...any) -> ()) -> (),
	Fire: (self: Tram, ...any) -> (),
	Wait: (self: Tram) -> ...any,
	Disconnect: (self: Tram) -> (),
}

-- Specialized tram types.
-- ALL tram types are a Tram type but the different types are for editing the auto complete for certain uses.
-- Ie. Modules using this as events, certain events, Only fire or only receive.

---------------------------------------------------------------------------------------------------------------------------------------------------------------

export type TramConnectOnly = {

	Connect: (self: Tram, (...any) -> ()) -> (),
	Wait: (self: Tram) -> ...any,
}

export type TramDisconnectOnly = {

	Disconnect: (self: Tram) -> (),
}

export type ModuleEvent = {

	Connect: (self: Tram, (...any) -> ()) -> (),
	Wait: (self: Tram) -> ...any,
	Disconnect: (self: Tram) -> (),
}

export type OnlySignaling = {

	Fire: (self: Tram, ...any) -> (),
}

---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 							[[ Service]]

local SERVICE_NAME = "[TramService]"

---------------------------------------------------------------------------------------------------------------------------------------------------------------

local SmartTable = require("./SmartTable")

-- 							[[ Thread caching ]]

local ThreadCache: { thread } = {}

-- Runs the yielded function then resets it
local function Run(FN, Thread, ...)
	FN(...)

	table.insert(ThreadCache, Thread)
	Run(coroutine.yield())
end

-- Creates a thread then yields it and allows you to "inject a function into it"
local function PrimeThread(): thread
	local function Prime()
		return Run(coroutine.yield())
	end

	return task.spawn(Prime)
end

local function RunCachedThread(FN: () -> (), ...)
	local Thread: thread

	if ThreadCache[1] then
		Thread = ThreadCache[math.min(1, #ThreadCache)]
		ThreadCache[#ThreadCache] = nil
	else
		Thread = PrimeThread()
	end

	if coroutine.status(Thread) ~= "suspended" then
		warn(SERVICE_NAME, ": Junk thread found removing from cache")
		return RunCachedThread(FN)
	end

	task.spawn(Thread, FN, Thread, ...)
end

-- Adds a timeout to remote function
local function Timeout(Time: number, FN, ...): (boolean, ...any)
	local Returned, Return, RunThread
	local Start = os.clock()

	Time = math.clamp(Time, 0, 20)
	RunThread = task.spawn(function(...)
		Return = FN(...)
		Returned = true
	end, ...)

	repeat
		task.wait()
	until Returned or os.clock() - Start > Time

	coroutine.close(RunThread)

	if not Returned then
		warn("Function callback time exhausted limit of " .. Time .. " seconds.")
	end
	return not Returned, Return
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cache manager

local TramCache: { [string?]: Tram } = {}

local function PublishUpdate(Tram: Tram)
	if Tram.TransversableID ~= "NonTransversable" then
		TramCache[Tram.TransversableID] = Tram
	end
end

local function GetUpdate(Tram: Tram)
	if Tram.TransversableID == "NonTransversable" then
		return Tram
	end
	local Cache = TramCache[Tram.TransversableID]
	if not Cache then
		return Tram
	end

	Tram.Timeout = Cache.Timeout
	Tram.FunctionsBinded = Cache.FunctionsBinded
	Tram.YeildingThreads = Cache.YeildingThreads
	Tram.Callback = Cache.Callback

	return Tram
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------

local Tram = {}

Tram.ClassName = Tram
Tram.__index = Tram

-- Connect a function to the tram
function Tram:Connect(fn) : ()
	assert(type(fn) == "function", SERVICE_NAME, ": Attempt to index " .. typeof(fn) .. " with function.")

	self = GetUpdate(self)

	if self.Callback then
		self.FunctionsBinded = fn
	else
		self.FunctionsBinded[self.BindID] = fn
	end

	PublishUpdate(self)
end

-- Handles the data sent in a optimized threaded capacity
function Tram:Fire(...) : ()
	local TransversableEvent = GetUpdate(self)
	if not TransversableEvent then
		return error(SERVICE_NAME .. ": Attempt to get Transversable Station for ["..tostring(self.TransversableID).. "] ID has no reciprocal.",100)
	end
	self = TransversableEvent

	--print(self)

	if self.Callback then
		if not self.FunctionsBinded then
			return warn(SERVICE_NAME .. ": Attempt to fire [" .. tostring(self.TransversableID) .. "], No function binded.")
		end
		return Timeout(self.Timeout, (self.FunctionsBinded :: any), ...)
	else
		for _, Thread in self.YeildingThreads do
			coroutine.resume(Thread, ...)
		end

		self.YeildingThreads = {}

		if not next(self.FunctionsBinded) then
			return warn(SERVICE_NAME .. ": Attempt to fire [" .. tostring(self.TransversableID) .. "], No function binded.")
		end

		for _, Func in self.FunctionsBinded do
			RunCachedThread(Func, ...)
		end

		PublishUpdate(self)
	end
end

-- Yields the main thread until :Fire() is called and resumes it
function Tram:Wait(): ()
	assert(not self.Callback, SERVICE_NAME, ": Attempt to yield callback function, cannot yield callbacks")
	assert(self.YeildingThreads[self.BindID] == nil, (SERVICE_NAME..": Attempt to yeild thread that is already yielding"))

	self.YeildingThreads[self.BindID] = coroutine.running()
	PublishUpdate(self)

	return coroutine.yield()
end

-- Disconnects a function from the tram
function Tram:Disconnect() : ()
	self = GetUpdate(self)

	assert(
		type(self.FunctionsBinded[self.BindID]) == "function",
		SERVICE_NAME,
		": Attempt to disconnect nil, No function binded"
	)
	assert(not self.YeildingThreads, SERVICE_NAME, ": Attempt to disconnect tram while a station is yielding")

	if self.Callback then
		self.FunctionsBinded = nil :: any
	else
		self.FunctionsBinded[self.BindID] = nil
	end

	PublishUpdate(self)
end

-- Add a :Destroy()

local TramService = {}

-- TransversableID needed to make the event accessable outside of the main script container
function TramService.NewTram(TransversableID: string?, Function: boolean?, Timeout: number?): Tram
	assert(not TransversableID or type(TransversableID) == "string", "Attempt to index string or nil with " .. typeof(TransversableID))

	local self = {}

	self.Callback = Function or false
	self.TransversableID = TransversableID or "NonTransversable"
	self.FunctionsBinded = if Function then nil else {}
	self.Timeout = Timeout or 5
	self.YeildingThreads = {}
	self.BindID = SmartTable.Helper.GenerateUUID()

	return setmetatable(self, Tram) :: any
end

return TramService

--[[

																	How to use.
	Tram service is a replacement for bindable events, they provide all the same functionallites + new performance upgrades
	
	To create a Tram require the module and call the "NewTram" function, If you want your Trams to be Tranversable between scripts
	Be sure to add a TranversableID as it is required for these, if no id is provided the event will be locked to the script the module
	was required in.
	
	Bindable Functions are supported with a built in timeout, A bindable event timeout will return a tupe (Boolean, ...Any?)
	The boolean with determin if the timeout was exhausted,  true if yes and false if no, and the rest is the returned product.
	Be Careful with calling wait in the same frame as this can cause it to be skipped and then miss being resumed making it forever yield
	
	
														Ill make a documentation soon ;D



]]
