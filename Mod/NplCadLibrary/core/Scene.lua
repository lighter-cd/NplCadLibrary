--[[
Title: Scene 
Author(s): leio
Date: 2016/8/16
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/NplCadLibrary/core/Scene.lua");
local Scene = commonlib.gettable("Mod.NplCadLibrary.core.Scene");
------------------------------------------------------------
]]
NPL.load("(gl)Mod/NplCadLibrary/core/Node.lua");
local Scene = commonlib.inherit(commonlib.gettable("Mod.NplCadLibrary.core.Node"), commonlib.gettable("Mod.NplCadLibrary.core.Scene"));
function Scene.create(id)
	local scene = Scene:new();
	scene:setId(id);
	return scene;
end

function Scene:getTypeName()
	return "Scene";
end

-- depth first traversal 
-- @param preVisitMethod: callback function to be called for each node before child callback invocations. can be nil.
-- @param postVisitMethod: callback function to be called for each node after child callback invocations. can be nil. 
function Scene:visit(preVisitMethod, postVisitMethod)
	local node = self:getFirstChild();
	while(node) do
		self:visitNode(node,preVisitMethod, postVisitMethod);
		node = node:getNextSibling();
	end
end

-- private: 
-- depth first traversal, visiting a single node. 
-- @param preVisitMethod: callback function to be called for each node before child callback invocations. can be nil. 
-- @param postVisitMethod: callback function to be called for each node after child callback invocations. can be nil. 
function Scene:visitNode(node,preVisitMethod, postVisitMethod)
	if(not node)then
		return;
	end
	if(preVisitMethod)then
		preVisitMethod(node);
	end
	local child = node:getFirstChild();
	while(child) do
		self:visitNode(child,preVisitMethod, postVisitMethod);
		child = child:getNextSibling();
	end
	if(postVisitMethod)then
		postVisitMethod(node);
	end
end
