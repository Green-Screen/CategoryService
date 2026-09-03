-- A constant
-- Add custom objects here

-- If a custom object is passed CategoryService will try and index a `Destroy` if a function is present it will be ran as the closure function.
-- A warning will also be raised, to silence it add the class to the dictionary below v.

export type CategoryDestroyInstructions<N> = {
		["MethodOrCall"]: "Method" | "Call",
		["FunctionName"]: N,
		["Library"]: {[N]: (...any) -> ()}?, -- Only needed if MethodOrCall is a Call. "most destroy functions are methods"
	}

export type SupportedExtraTypes = "thread" | "RBXScriptConnection" | "Tween"  -- add to this list if you add more custom objects with "Destroy" methods but not with the call `Object:Destroy()`


-- Add objects whose closure function is not a method of `Destroy` IE: "Instance:Destroy()" would not need to be added to this list
-- Unlike RBXScriptConnections as their destroy function is `Disconnect` IE "Connection:Desconnect()" WOULD need to be added to this list
const D = {
	["RBXScriptConnection"] = {
		["MethodOrCall"] = "Method",
		["FunctionName"] = "Disconnect",
	} :: CategoryDestroyInstructions<"Disconnect">,
	
	["thread"] = {
		["MethodOrCall"] = "Call",
		["FunctionName"] = "cancel",
		["Library"] = task,
	} :: CategoryDestroyInstructions<"cancel">,

	["Tween"] = {
		["MethodOrCall"] = "Method",
		["FunctionName"] = "Cancel",
	} :: CategoryDestroyInstructions<"Cancel">,
}

return D :: {[string]:CategoryDestroyInstructions<string>}