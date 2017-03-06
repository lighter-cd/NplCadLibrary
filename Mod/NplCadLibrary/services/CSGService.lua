--[[
Title: CSGService 
Author(s): leio
Date: 2016/8/23
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/NplCadLibrary/services/CSGService.lua");
local CSGService = commonlib.gettable("Mod.NplCadLibrary.services.CSGService");
local output = CSGService.buildPageContent("cube();")
commonlib.echo(output);
------------------------------------------------------------
]]
--NPL.load("(gl)Mod/NplCadLibrary/utils/commonlib_ext.lua");
NPL.load("(gl)script/ide/math/Matrix4.lua");
NPL.load("(gl)script/ide/math/math3d.lua");
NPL.load("(gl)Mod/NplCadLibrary/services/NplCadEnvironment.lua");
NPL.load("(gl)Mod/NplCadLibrary/utils/matrix_decomp.lua");
NPL.load("(gl)Mod/NplCadLibrary/core/Scene.lua");

local Matrix4 = commonlib.gettable("mathlib.Matrix4");
local CSGService = commonlib.gettable("Mod.NplCadLibrary.services.CSGService");
local math3d = commonlib.gettable("mathlib.math3d");
local NplCadEnvironment = commonlib.gettable("Mod.NplCadLibrary.services.NplCadEnvironment");
local Scene = commonlib.gettable("Mod.NplCadLibrary.core.Scene");

function CSGService.operateTwoNodes(pre_drawable_node,cur_drawable_node,drawable_action,operation_node)
	local bResult = false;
	if(pre_drawable_node and cur_drawable_node)then
		local fromTime = ParaGlobal.timeGetTime();

		-- 2d shape and 3d model are mixed 
		local cur_transform,cur_world = cur_drawable_node:getMeshTransform(operation_node);
		local pre_transform,pre_world = pre_drawable_node:getMeshTransform(operation_node);
		local can_combine,new_transform,new_cur,new_pre = false,nil,nil,nil;
		if(pre_drawable_node:getTypeName()=="Model" and cur_drawable_node:getTypeName()=="Model") then
			-- do nothing
		elseif(pre_drawable_node:getTypeName()=="Model" and cur_drawable_node:getTypeName()=="Shape") then
			cur_drawable_node = cur_drawable_node:toCSGModel();
		elseif(pre_drawable_node:getTypeName()=="Shape" and cur_drawable_node:getTypeName()=="Model") then
			pre_drawable_node = pre_drawable_node:toCSGModel();
		elseif(pre_drawable_node:getTypeName()=="Shape" and cur_drawable_node:getTypeName()=="Shape") then
			can_combine,new_transform,cur_transform,pre_transform = Matrix4.canCombineToShape(cur_transform,pre_transform);
			if(not can_combine) then
				cur_drawable_node = cur_drawable_node:toCSGModel();
				pre_drawable_node = pre_drawable_node:toCSGModel();
			elseif(new_transform ~= nil) then
				new_transform = new_transform * cur_world;
				cur_world = Matrix4.IDENTITY;
				pre_world = Matrix4.IDENTITY;
			else
				-- do nothing	
			end
		end
		cur_drawable_node:applyTransform(cur_transform,cur_world);
		pre_drawable_node:applyTransform(pre_transform,pre_world);

		CSGService.scene:log("1.finished applyTransform in %.3f seconds", (ParaGlobal.timeGetTime()-fromTime)/1000);
		fromTime = ParaGlobal.timeGetTime();
		
		-- do action
		if(drawable_action == "union")then
			cur_drawable_node = pre_drawable_node:union(cur_drawable_node);
			bResult = true;
		elseif(drawable_action == "difference")then
			cur_drawable_node = pre_drawable_node:subtract(cur_drawable_node);
			bResult = true;
		elseif(drawable_action == "intersection")then
			cur_drawable_node = pre_drawable_node:intersect(cur_drawable_node);
			bResult = true;
		else
			-- Default action is "union".
			--cur_drawable_node = pre_drawable_node:union(cur_drawable_node);
		end

		CSGService.scene:log("2.finished boolOperation in %.3f seconds", (ParaGlobal.timeGetTime()-fromTime)/1000);

		fromTime = ParaGlobal.timeGetTime();
		if bResult then
			-- result_drawable is build from other drawables,it's node hasn't apply yet.then apply it before be pushed. 
			cur_drawable_node:setNode(operation_node);
			if(new_transform ~= nil) then
				cur_drawable_node:applyTransform(nil,new_transform);
			end
		end
		CSGService.scene:log("3.finished applyTransform for new node in %.3f seconds", (ParaGlobal.timeGetTime()-fromTime)/1000);
	end
	return cur_drawable_node,bResult;
end

-- find tag value in all of its parent recursively
-- @return tagValue, sceneNode: if no tagValue is found, the sceneNode is the rootNode.
function CSGService.findTagValue(node,name)
	if(not node)then
		return
	end
	local p = node;
	local lastNode;
	while(p) do
		local v = p:getTag(name);
		if(v)then
			return v,p;
		end
		lastNode = p;
		p = p:getParent();
	end
	return nil, lastNode;
end

function CSGService.equalsColor(color_1,color_2)
	return color_1 and color_2 and (color_1[1] == color_2[1] and color_1[2] == color_2[2] and color_1[3] == color_2[3]);
end
function CSGService.clearOutPut()
	CSGService.output = {};
end
-- build csg from an existed file or text.
--[[
	return {
		successful = successful,
		csg_node_values = csg_node_values,
		compile_error = compile_error,
		log = string, 
	}
--]]
function CSGService.build(filepathOrText,isFile)
	if(not filepathOrText)then
		return
	end
	CSGService.clearOutPut();
	local fromTime = ParaGlobal.timeGetTime();
	LOG.std(nil, "info", "CSG", "\n------------------------------\nbegin render scene\n");
	-- 1. create a env node
	local env_node = NplCadEnvironment:new({filepath = filepathOrText});
	-- 2. create a scene for renderering
	local scene = Scene.create("nplcad_scene");
	CSGService.scene = scene;
	-- 3. building and get the result
	if(isFile)then
		env_node:buildFile(scene,filepathOrText);
	else
		env_node:build(scene,filepathOrText);
	end

	env_node.root_scene_node:log("finished compile scene in %.3f seconds", (ParaGlobal.timeGetTime()-fromTime)/1000);
	LOG.std(nil, "info", "CSG", "\nfinished compile scene in %.3f seconds\n", (ParaGlobal.timeGetTime()-fromTime)/1000);
		
	local render_list = CSGService.getRenderList(scene)
	env_node.root_scene_node:log("finished render scene in %.3f seconds", (ParaGlobal.timeGetTime()-fromTime)/1000);
	LOG.std(nil, "info", "CSG", "\n\nfinished render scene in %.3f seconds\n------------------------------", (ParaGlobal.timeGetTime()-fromTime)/1000);


	local function write_logs(log_table)
		local logs = "";
		local log_table = log_table or {};
		local len = #log_table;
		while( len > 0) do
			local n = log_table[len];
			if(n)then
				logs = logs .. n .. "\n";
			end
			len = len - 1;
		end
		return logs;
	end
	CSGService.output.log = write_logs(CSGService.output.log);
	CSGService.output.csg_node_values = render_list;
	return CSGService.output;
end
--load xml to build csg
function CSGService.appendLoadXmlFunction(code)
	if(code)then
		local first_line;
		for line in string.gmatch(code,"[^\r\n]+") do
			first_line = line;
			break;
		end
		if(first_line)then
			if(string.find(first_line,"nplcad"))then
				code = string.format("loadXml([[%s]])",code);
				return code;
			end
		end
		return code;
	end
end

function CSGService.getRenderList(scene)
	if(not scene)then
		return
	end
	
	-- apply color to drawable.
	local function applyColor(node,drawable)
		local color = CSGService.findTagValue(node,"color");
		if(color)then
			drawable:setColor(color);
		end
	end

	local function BeforeChildVisit_(node)
		node:getWorldMatrix();
		
		local actionName, actionNode = CSGService.findTagValue(node,"csg_action");
		local drawable = node:getDrawable();
		if(drawable and drawable:getModelNode())then
			applyColor(node,drawable);
			actionNode:pushActionParam(drawable);
			LOG.std(nil, "info", "CSG", "begin drawable_node with %d polygons/sides", drawable:getElements());
		else
			LOG.std(nil, "info", "CSG", "begin node with (%s) tag", node:getTag("csg_action") or "empty");
		end
	end

	local function AfterChildVisit_(node)
		local action_params = node:popAllActionParams();
		if(action_params) then
			local actionName = node:getTag("csg_action");
			local fromTime = ParaGlobal.timeGetTime();
			local result_drawable = CSGService.doDrawablelAction(actionName, action_params,node);
			LOG.std(nil, "info", "CSG", "drawable_node action (%s: with %d nodes) finished in %.3f seconds with %d polygons(sides)", 
				actionName or "none", action_params and #action_params or 0, 
				(ParaGlobal.timeGetTime()-fromTime)/1000, result_drawable and result_drawable:getElements() or 0);
			local actionName, actionNode = CSGService.findTagValue(node:getParent() or scene,"csg_action");
			if(actionNode ~= node) then
				applyColor(node,result_drawable);
				actionNode:pushActionParam(result_drawable);
			end
		end
	end

	scene:visit(BeforeChildVisit_, AfterChildVisit_);

	-- convert all resulting drawable_nodes to meshes
	local render_list = {};

	local result = scene:popAllActionParams();
	if(result) then
		for i = 1, #result do
			local world_matrix,vertices,indices,normals,colors = result[i]:toMesh();
			table.insert(render_list,{
				world_matrix = world_matrix,
				vertices = vertices,
				indices = indices,
				normals = normals,
				colors = colors,
			});
		end
	end
	
	return render_list;
end

-- @param csg_action: name of the operation. 
-- @param drawable_nodes: array of csg node operands
-- @return csgNode, bSucceed:  csgNode is the result.
function CSGService.doDrawablelAction(drawable_action, drawable_nodes, operation_node)
	local len = #drawable_nodes;
	if(len == 0)then
		return;
	end
	local first_node = drawable_nodes[1];
	if(len == 1) then
		first_node:applyTransform(first_node:getMeshTransform(operation_node));
	end

	local result_node = first_node;
	local bSucceed = true;
	for i=2, len do
		result_node, bSucceed = CSGService.operateTwoNodes(result_node, drawable_nodes[i], drawable_action, operation_node);
		if(not bSucceed) then
			break;
		end
	end
	return result_node, bSucceed;
end

function CSGService.visitNode(node,input_params)
	if(not node)then return end
	local nodes_map = input_params.nodes_map;
	if(nodes_map[node]["drawable_node"])then
		return
	end
	local child = node:getFirstChild();
	local top_csg_action = CSGService.findTagValue(node,"csg_action");
	local temp_list = {};
	while(child) do
		local drawable_node = nodes_map[child]["drawable_node"];
		if(drawable_node)then
			if(top_csg_action)then
				table.insert(temp_list,{
					drawable_node = drawable_node,
				});	
			else
				table.insert(input_params.result,{
					drawable_node = drawable_node,
				});	
			end
			
		end
		nodes_map[child]["drawable_node"] = nil;
		child = child:getNextSibling();
	end	
	local drawable_node = CSGService.doCSGOperation(top_csg_action, temp_list);
	nodes_map[node]["drawable_node"] = drawable_node;
end

-- Read csg code from a file.
function CSGService.readFile(filepath)
	if(not filepath)then return end
	local file = ParaIO.open(filepath, "r");
	if(file:IsValid()) then
		local text = file:GetText();
		file:close();
		return text;
	end
end
function CSGService.saveFile(filepath,content)
	if(filepath and content)then
		ParaIO.CreateDirectory(filepath);
		local file = ParaIO.open(filepath, "w");
		if(file:IsValid()) then
			file:WriteString(content);
			file:close();

			return true;
		end
	end
end
