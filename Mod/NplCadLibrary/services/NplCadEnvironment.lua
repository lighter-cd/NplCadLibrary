--[[
Title: NplCadEnvironment 
Author(s): leio
Date: 2016/8/23
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/NplCadLibrary/services/NplCadEnvironment.lua");
local NplCadEnvironment = commonlib.gettable("Mod.NplCadLibrary.services.NplCadEnvironment");
------------------------------------------------------------
]]

NPL.load("(gl)script/ide/math/Quaternion.lua");
NPL.load("(gl)Mod/NplCadLibrary/core/Transform.lua");
NPL.load("(gl)Mod/NplCadLibrary/core/Node.lua");
NPL.load("(gl)Mod/NplCadLibrary/core/Scene.lua");
NPL.load("(gl)Mod/NplCadLibrary/drawables/CSGModel.lua");
NPL.load("(gl)Mod/NplCadLibrary/drawables/CAGModel.lua");
NPL.load("(gl)Mod/NplCadLibrary/doms/DomParser.lua");
NPL.load("(gl)Mod/NplCadLibrary/services/CSGService.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGFactory.lua");
NPL.load("(gl)Mod/NplCadLibrary/cag/CAGFactory.lua");
NPL.load("(gl)Mod/NplCadLibrary/utils/Color.lua");
NPL.load("(gl)Mod/NplCadLibrary/utils/commonlib_ext.lua");
local Quaternion = commonlib.gettable("mathlib.Quaternion");
local Transform = commonlib.gettable("Mod.NplCadLibrary.core.Transform");
local Node = commonlib.gettable("Mod.NplCadLibrary.core.Node");
local Scene = commonlib.gettable("Mod.NplCadLibrary.core.Scene");
local CSGModel = commonlib.gettable("Mod.NplCadLibrary.drawables.CSGModel");
local CAGModel = commonlib.gettable("Mod.NplCadLibrary.drawables.CAGModel");
local DomParser = commonlib.gettable("Mod.NplCadLibrary.doms.DomParser");
local CSGService = commonlib.gettable("Mod.NplCadLibrary.services.CSGService");
local CSGFactory = commonlib.gettable("Mod.NplCadLibrary.csg.CSGFactory");
local CAGFactory = commonlib.gettable("Mod.NplCadLibrary.cag.CAGFactory");
local NplCadEnvironment = commonlib.gettable("Mod.NplCadLibrary.services.NplCadEnvironment");
local Color = commonlib.gettable("Mod.NplCadLibrary.utils.Color");
local math_pi = 3.1415926;
local function is_string(input)
	if(input and type(input) == "string")then
		return true;
	end
end
local function is_table(input)
	if(input and type(input) == "table")then
		return true;
	end
end
local function is_number(input)
	if(input and type(input) == "number")then
		return true;
	end
end
local function is_array(input)
	if(input and type(input) == "table" and (#input) > 0)then
		return true;
	end
end

local function is_node(input)
	if(input and type(input) == "table" and (input.getTypeName) and input.getTypeName()=="Node")then
		return true;
	end
end
local function is_sharp(input)
	if(is_node(input) and input.hasTag and input:hasTag("shape")) then
		return true;
	end
end
local function is_path(input)
	if(input and type(input) == "table" and input.expandToCAG and input.innerToCAG and input.rectangularExtrude) then
		return true;
	end
end

-- number pi are exposed
NplCadEnvironment.PI = 3.1415926;
NplCadEnvironment.pi = NplCadEnvironment.PI;

function NplCadEnvironment:new(params)
	params = params or {}
	local o = {
		filepath = params.filepath,
		root_scene_node = params.root_scene_node or Node.create(""),
		nodes_stack = {},
		math = math,
		string = string,
		specified_indexs = {},
	};
	-- also expose the _G for explaining npl only. 
	o._G = o; 
	setmetatable(o, self);
	self.__index = self;
	return o;
end

function NplCadEnvironment.getNode()
	local self = getfenv(2);
	return self:getNode__();
end
function NplCadEnvironment:getNode__()
	if(self.nodes_stack)then
		local len = #self.nodes_stack;
		local node = self.nodes_stack[len];
		if(node)then
			return node;
		end
		return self.root_scene_node;
	end
end
function NplCadEnvironment.push()
	local self = getfenv(2);
	self:push__(true);
end
function NplCadEnvironment:push__(bSpecified)
	local parent = self:getNode__()
	local node = Node.create("");
	table.insert(self.nodes_stack,node);
	parent:addChild(node);
	if(bSpecified)then
		table.insert(self.specified_indexs,#self.nodes_stack)
	end
	return node;
end
function NplCadEnvironment.pop()
	local self = getfenv(2);
	self:pop__(true);
end
function NplCadEnvironment:pop__(bSpecified)
	if(self.nodes_stack)then
		if(bSpecified)then
			local len = #self.specified_indexs;
			local start_index = self.specified_indexs[len];
			local end_index = #self.nodes_stack;
			while (end_index >= start_index) do
				table.remove(self.nodes_stack,end_index);
				end_index = end_index - 1;
			end
			table.remove(self.specified_indexs,len);
		else
			local len = #self.nodes_stack;
			table.remove(self.nodes_stack,len);
		end
	end
end
function NplCadEnvironment.current()
	local self = getfenv(2);
	local node = self:getNode__();
	return node;
end

-- NplCadEnvironment.log() belongs to NplCadEnvironment, Use NplCadEnvironment:internalLog() to debug code.
function NplCadEnvironment.log(...)
	local self = getfenv(2);
	self:internalLog(...);
end
function NplCadEnvironment:internalLog(...)
	self.root_scene_node:log(...);
end
--include----------------------------------------------------------------------------------------------------
function NplCadEnvironment.include(filepath)
	local self = getfenv(2);
	local node = self:push__();
	self:include__(node,filepath);
end
function NplCadEnvironment:include__(node,filepath)
	if(not filepath)then return end
	local index = string.find(self.filepath, "/[^/]*$")
	local cur_dir = string.sub(self.filepath,1,index);
	local full_filepath = cur_dir .. filepath;
	--create a new env node
	local env_node = NplCadEnvironment:new({ filepath = filepath, });
	env_node:buildFile(node,full_filepath);
end
function NplCadEnvironment:loadFileContent(filepath)
	if(not filepath)then
		return
	end
	local full_path = ParaIO.GetCurDirectory(0)..filepath;
	local file = ParaIO.open(full_path, "r");
	if(file:IsValid()) then
		local text = file:GetText();
		file:close();
		return text;
	end
end
function NplCadEnvironment:buildFile(parent_scene_node,filepath)
	local code = self:loadFileContent(filepath);
	self.root_scene_node:log("start to build file:%s",filepath);
	self:build(parent_scene_node,code);
end
function NplCadEnvironment:build(parent_scene_node,code)
	local code_func, errormsg = loadstring(code);
	if(code_func) then
		setfenv(code_func, self);
		local ok, result = pcall(code_func);
		if(ok)then
			if(parent_scene_node)then
				parent_scene_node:addChild(self.root_scene_node);
			end
		end
		CSGService.output.successful = ok;
		CSGService.output.compile_error = result;
		CSGService.output.log = CSGService.output.log or {};

		local log = table.concat(self.root_scene_node:GetAllLogs() or {}, "\n");

		CSGService.output.log[#(CSGService.output.log)+1] = log;

	else
		CSGService.output.successful = false;
		CSGService.output.compile_error =  errormsg;
		CSGService.output.log = errormsg;
	end
end
--end include----------------------------------------------------------------------------------------------------
function NplCadEnvironment.union()
	local self = getfenv(2);
	self:union__();
end
function NplCadEnvironment:union__()
	local node = self:push__();
	if(node)then
		node:setTag("csg_action","union");
	end
end
function NplCadEnvironment.difference()
	local self = getfenv(2);
	self:difference__();
end
function NplCadEnvironment:difference__()
	local node = self:push__();
	if(node)then
		node:setTag("csg_action","difference");
	end
end
function NplCadEnvironment.intersection()
	local self = getfenv(2);
	self:intersection__();
end
function NplCadEnvironment:intersection__()
	local node = self:push__();
	if(node)then
		node:setTag("csg_action","intersection");
	end
end
function NplCadEnvironment.cube(options)
	local self = getfenv(2);
	return self:cube__(options);
end

function NplCadEnvironment.read_cube(p)
	local node = Node.create("");
	local s = 1;
	local v = nil;
	local off = {0,0,0};
	local round = false;
	local r = 0;
	local fn = 8;

	if(is_array(p))then
		v = p;
	end
	if(is_table(p) and p.size and is_array(p.size))then v = p.size; end --{ size: [1,2,3] }
	if(is_table(p) and p.size and not is_array(p.size))then s = p.size; end --{ size: 1 }
	if(not is_table(p)) then s = p; end -- (2)
	if(is_table(p) and p.round == true)then
		round = true;
		if(v)then
			if(is_array(v))then
				r = (v[1]+v[2]+v[3])/30;
			else 
				r = s / 10;
			end
		end
	end
	if(is_table(p) and p.radius)then
		round = true;
		r = p.radius;
	end
	if(is_table(p) and p.fn)then
		fn = p.fn; --applies in case of round: true
	end

	local x = s;
	local y = s;
	local z = s; 
	if(v and is_array(v))then
		x = v[1];
		y = v[2];
		z = v[3]; 
	end
   
	off = {x/2,y/2,z/2}; -- center: false default
	local o;
	if(round)then
		--NOTE:Unimplemented
		--o = CSGModel:new():init(CSGFactory.roundedCube({radius = {x/2,y/2,z/2}, roundradius = r, resolution = fn}),"roundedCube");
		o = CSGModel:new():init(CSGFactory.cube({radius = {x/2,y/2,z/2}}),"cube");
	else
		o = CSGModel:new():init(CSGFactory.cube({radius = {x/2,y/2,z/2}}),"cube");
	end
	if(is_table(p) and p.center and is_array(p.center))then
		if(p.center[1])then off[1] = 0; else off[1] = x/2;end
		if(p.center[2])then off[2] = 0; else off[2] = y/2;end
		if(p.center[3])then off[3] = 0; else off[3] = z/2;end
	elseif(is_table(p) and p.center == true)then
		off = {0,0,0};
	elseif(is_table(p) and p.center == false)then
		off = {x/2,y/2,z/2};
	end
	node:setDrawable(o);
	if(off[1] ~= 0 or off[2] ~= 0 or off[3] ~= 0)then
		node:translate(off[1],off[2],off[3]);
	end
	return node;
end
--[[
cube(); // openscad like
cube(1);
cube({size = 1});
cube({size = {1,2,3}});
cube({size = 1, center = true}); // default center:false
cube({size = 1, center = {true,true,false}}); // individual axis center true or false
--]]
function NplCadEnvironment:cube__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_cube(options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.sphere(options)
	local self = getfenv(2);
	return self:sphere__(options);
end
function NplCadEnvironment.read_sphere(p)
	local node = Node.create("");
	
	local r = 1;
	local fn = 32;
	local off = {0,0,0};      
	local type = 'normal';
   
	if(is_table(p) and p.r) then 
		r = p.r;
	end
	if(is_table(p) and p.fn) then
		fn = p.fn;
	end
	if(is_table(p) and p.type) then
		type = p.type;
	end

	if(not is_table(p)) then
		r = p;
	end
	off = {0,0,0};       -- center: false (default)

	local o;
	if(type=='geodesic')then
		--NOTE:Unimplemented
		--o = geodesicSphere(p);
		o = CSGModel:new():init(CSGFactory.sphere({radius = r, resolution = fn}),"sphere");
	else 
		o = CSGModel:new():init(CSGFactory.sphere({radius = r, resolution = fn}),"sphere");
	end
	if(is_table(p) and p.center and is_table(p.center)) then         -- preparing individual x,y,z center
		if(p.center[1])then
			off[1] = 0
		else
			off[1] = r
		end
		if(p.center[2])then
			off[2] = 0
		else
			off[2] = r
		end
		if(p.center[3])then
			off[3] = 0
		else
			off[3] = r
		end
	elseif(is_table(p) and p.center==true) then
		off = {0,0,0};
	elseif(is_table(p) and p.center==false) then
		off = {r,r,r};
	end
	node:setDrawable(o);
	if(off[1] ~= 0 or off[2] ~= 0 or off[3] ~= 0)then
		node:translate(off[1],off[2],off[3]);
	end
	return node;
end
--[[
	sphere();                          // openscad like
	sphere(1);
	sphere({r = 2});                    // Note: center = true is default (unlike other primitives, as OpenSCAD)
	sphere({r = 2, center = false});     // Note: OpenSCAD doesn't support center for sphere but we do
	sphere({r = 2, center = {true, true, false}}); // individual axis center 
	sphere({r = 10, fn = 100 });
--]]
function NplCadEnvironment:sphere__(options)
	options = options or {};
	local parent = self:getNode__();
	local node = NplCadEnvironment.read_sphere(options);
	parent:addChild(node);
	return node;
end

function NplCadEnvironment.cylinder(options,...)
	local self = getfenv(2);
	return self:cylinder__(options);
end

function NplCadEnvironment.read_cylinder(p,...)
	local node = Node.create("");
	local r1 = 1;
	local r2 = 1;
	local h = 1;
	local fn = 32;
	local round = false; 
	local a = {...};
	local off = {0,0,0};

	if(is_table(p) and p.d) then
		r1 = p.d/2;
		r2 = r1;
	end
	if(is_table(p) and p.r) then
		r1 = p.r; 
		r2 = p.r; 
	end
	if(is_table(p) and p.h) then
		h = p.h;
	end
	if(is_table(p) and (p.r1 or p.r2)) then
		r1 = p.r1; 
		r2 = p.r2; 
		if(p.h)then
		h = p.h;
		end
	end
	if(is_table(p) and (p.d1 or p.d2)) then
		r1 = p.d1/2; 
		r2 = p.d2/2;
	end
    
	if(is_array(a) and a[1] and is_array(a[1])) then
		a = a[1]; 
		r1 = a[1]; 
		r2 = a[2]; 
		h = a[3]; 
		if(#a == 4)then
		fn = a[4];
		end
	end
	if(is_table(p) and p.fn) then
		fn = p.fn;
	end
	if(is_table(p) and p.round==true) then
		round = true;
	end
	local o;
	if(is_table(p) and (p.from and p.to)) then
		if(round)then
			--NOTE:Unimplemented
			--o = CSGModel:new():init(CSGFactory.roundedCylinder({from = p.from, to = p.to, radiusStart = r1,radiusEnd = r2, resolution = fn}),"roundedCylinder");
			o = CSGModel:new():init(CSGFactory.cylinder({from = p.from,to = p.to,radiusStart = r1,radiusEnd = r2,resolution = fn}),"cylinder");
		else
			o = CSGModel:new():init(CSGFactory.cylinder({from = p.from,to = p.to,radiusStart = r1,radiusEnd = r2,resolution = fn}),"cylinder");
		end
	else
		if(round)then
			--NOTE:Unimplemented
			--o = CSGModel:new():init(CSGFactory.roundedCylinder({from = {0,0,0}, to = {0,0,h},radiusStart = r1, radiusEnd = r2, resolution = fn}),"roundedCylinder");
			o = CSGModel:new():init(CSGFactory.cylinder({from = {0,0,0}, to = {0,h,0}, radiusStart = r1, radiusEnd = r2, resolution = fn}),"cylinder");
		else
			o = CSGModel:new():init(CSGFactory.cylinder({from = {0,0,0}, to = {0,h,0}, radiusStart = r1, radiusEnd = r2, resolution = fn}),"cylinder");
		end
		local r;
		if(r1>r2)then
			r = r1;
		else
			r = r2;
		end

		if(is_table(p) and p.center and is_table(p.center)) then         -- preparing individual x,y,z center
			if(p.center[1])then
				off[1] = 0;
			else
				off[1] = r;
			end
			if(p.center[2])then
				off[2] = -h/2;
			else
				off[2] = 0;
			end
			if(p.center[3])then
				off[3] = 0;
			else
				off[3] = r;
			end
		elseif(is_table(p) and p.center==true) then 
			off = {0,-h/2,0};
		elseif(is_table(p) and p.center==false) then
			off = {r,0,r};
		end
		--if(off[0]||off[1]||off[2]) o = o.translate(off);
		if(off[1] ~= 0 or off[2] ~= 0 or off[3] ~= 0)then
			node:translate(off[1],off[2],off[3]);
		end
	end
	node:setDrawable(o);
	return node;
end
--[[
	cylinder({r = 1, h = 10});                 -- openscad like
	cylinder({d = 1, h = 10});
	cylinder({r = 1, h = 10, center = true});   -- default: center = false
	cylinder({r = 1, h = 10, center = {true, true, false}});  -- individual x,y,z center flags
	cylinder({r1 = 3, r2 = 0, h = 10});
	cylinder({d1 = 1, d2 = 0.5, h = 10});
	cylinder({from = {0,0,0}, to = {0,0,10}, r1 = 1, r2 = 2, fn = 50});
]]
function NplCadEnvironment:cylinder__(options,...)
	options = options or {};
	local parent = self:getNode__();
	local node = NplCadEnvironment.read_cylinder(options,...)
	parent:addChild(node);
	return node;
end
--[[
translate({0,0,10});		--create a new parent node and set translation value 
translate({0,0,10},obj);	--set translation value with obj          
translate(0,1,0, obj);		--set translation 
--]]
function NplCadEnvironment.translate(...)
	local self = getfenv(2);
	self:translate__(...);
end
function NplCadEnvironment:translate__(p1,p2,p3,p4)
	local x,y,z, options,obj;
	if(type(p1) == "table") then
		options = p1;
		if #options == 3 then
			x = options[1];
			y = options[2];
			z = options[3];
		elseif #options == 2 then
			x = options[1];
			y = 0;
			z = options[2];
		else
			self:internalLog("translate should have 2 or 3 coords");
			return;
		end
		obj = p2;
	elseif(type(p1) == "number") then
		if ( type(p2) == "number" and type(p3) == "number" ) then
			x = p1;
			y = tonumber(p2);
			z = tonumber(p3);
			obj = p4;
		elseif (type(p2) == "number" and type(p3) ~= "number") then
			x = p1;
			y = 0;
			z = tonumber(p2);
			obj = p3;	
		else 
			self:internalLog("translate should have 2 or 3 coords");	
		end
	else
		self:internalLog("translate should have a coords array");
		return;		
	end
	if(not obj)then
		obj = self:push__();
	end
	if(obj and obj.setTranslation)then
		obj:setTranslation(x or 0, y or 0, z or 0);
	end
end
--[[
rotate(2);				--create a new parent node and set rotation value          
rotate(2,obj);			--set rotation value with obj          
rotate({1,2,3});		--create a new parent node and set rotation value          
rotate({1,2,3},obj);	--set rotation value with obj  
--]]
function NplCadEnvironment.rotate(options,obj)
	local self = getfenv(2);
	self:rotate__(options,obj);
end
function NplCadEnvironment:rotate__(options,obj)
	if(not options)then return end
	local x_angle,y_angle,z_angle;
	if(is_number(options))then
		x_angle = options;
		y_angle = options;
		z_angle = options;
	end
	if(is_array(options))then
		x_angle = options[1] or 0;
		y_angle = options[2] or 0;
		z_angle = options[3] or 0;
	end
	if(not obj)then
		obj = self:push__();
	end
	local x = x_angle * math_pi / 180;
	local y = y_angle * math_pi / 180;
	local z = z_angle * math_pi / 180;

	if(obj and obj.setRotation)then
		local q =  Quaternion:new();
		local yaw = y;
		local roll = z;
		local pitch = x;
		q =  q:FromEulerAngles(yaw,roll,pitch);
		obj:setRotation(q[1],q[2],q[3],q[4]);
	end
end
--[[
scale(2);			--create a new parent node and set scale value          
scale(2,obj);		--set scale value with obj          
scale({1,2,3});		--create a new parent node and set scale value          
scale({1,2,3},obj); --set scale value with obj          
--]]
function NplCadEnvironment.scale(options,obj)
	local self = getfenv(2);
	self:scale__(options,obj);
end
function NplCadEnvironment:scale__(options,obj)
	if(not options)then return end
	local x,y,z;
	if(is_number(options))then
		x = options;
		y = options;
		z = options;
	elseif(is_array(options))then
		if #options == 3 then
			x = options[1] or 1;
			y = options[2] or 1;
			z = options[3] or 1;
		elseif #options == 2 then
			x = options[1] or 1;
			y = 1;
			z = options[2] or 1;
		else
			self:internalLog("scale should have 2 or 3 coords");
			return;
		end
	else
		self:internalLog("scale should have a coords array");
		return;		
	end
	if(not obj)then
		obj = self:push__();
	end
	if(obj and obj.setScale)then
		obj:setScale(x,y,z);
	end
end
--[[
color({r,g,b});		--create a new parent node and set color value 
color({r,g,b},obj); --set color value with obj 
color(color_name);		--create a new parent node and set color value with color name
color(color_name,obj)		--set color value with obj 
--]]
function NplCadEnvironment.color(options,obj)
	local self = getfenv(2);
	self:color__(options,obj);
end
function NplCadEnvironment:color__(options,obj)
	if(not options)then return end
	local r,g,b;
	if(is_string(options))then
		local v = Color.getValue(options);
		r = v[1];
		g = v[2];
		b = v[3];
	end
	if(is_array(options))then
		r = options[1] or 1;
		g = options[2] or 1;
		b = options[3] or 1;
	end
	if(not obj)then
		obj = self:push__();
	end
	if(obj and obj.setTag)then
		obj:setTag("color",{r,g,b});
	end
end
function NplCadEnvironment.loadXml(str)
	local self = getfenv(2);
	self:loadXml__(str);
end
function NplCadEnvironment:loadXml__(str)
	local parent = self:getNode__();
	local node = DomParser.loadStr(str)
	if(node)then
		parent:addChild(node);
	end
end

--[[
		circle
--]]
function NplCadEnvironment.circle(options,...)
	local self = getfenv(2);
	return self:circle__(options);
end

function NplCadEnvironment.read_circle(p,...)
	local node = Node.create("");
	local r = 1;
	local fn = CSGFactory.defaultResolution2D;
	local a = {...};
	local off = {0,0,0};

	--x
	if(not is_table(p)) then
		r = p;
	end
	-- {d=x}
	if(is_table(p) and p.d) then
		r = p.d/2;
	end
	-- {r=x}
	if(is_table(p) and p.r) then
		r = p.r; 
	end
	--[r,fn]
	if(is_array(a) and a[1] and is_array(a[1])) then
		r = a[1]; 
		if(#a == 2)then
		fn = a[2];
		end
	end
	-- {fn=x}
	if(is_table(p) and p.fn) then
		fn = p.fn;
	end

	local o;
	o = CAGModel:new():init(CAGFactory.circle({radius = r, resolution = fn}),"circle");

	-- {center={}}
	if(is_table(p) and p.center and is_table(p.center)) then         -- preparing individual x,y,z center
		if(p.center[1])then
			off[1] = 0;
		else
			off[1] = r;
		end
		if(p.center[2])then
			off[2] = 0;
		else
			off[2] = r;
		end
	-- {center=true}
	elseif(is_table(p) and p.center==true) then 
		off = {0,0,0};
	-- {center=false}
	elseif(is_table(p) and p.center==false) then
		off = {r,0,r};
	end
	
	--if(off[0]||off[1]||off[2]) o = o.translate(off);
	if(off[1] ~= 0 or off[2] ~= 0 or off[3] ~= 0)then
		node:translate(off[1],off[2],off[3]);
	end

	node:setDrawable(o);
	node:setTag("shape","circle");
	return node;
end
--[[
	circle();                        -- openscad like
	circle(1); 
	circle({d: 2, fn:5});
	circle({r: 2, fn:5});
	circle({r: 3, center = true});    -- center: false (default)
	circle({r: 3, center = {true, true}});    -- individual x,z center flags
]]
function NplCadEnvironment:circle__(options,...)
	options = options or {};
	local parent = self:getNode__();
	local node = NplCadEnvironment.read_circle(options,...)
	parent:addChild(node);
	return node;
end

--[[
		square
--]]
function NplCadEnvironment.square(options)
	local self = getfenv(2);
	return self:square__(options);
end

function NplCadEnvironment.read_square(p)
	local node = Node.create("");
	local s = 1;
	local v = nil;
	local off = {0,0};
	local round = false;
	local r = 0;
	local fn = 8;

	-- [w,h]
	if(is_array(p))then
		v = p;
	end
	--{ size: [w.h] }
	if(is_table(p) and p.size and is_array(p.size))then 
		v = p.size; 
	end 
	--{ size: 1 }
	if(is_table(p) and p.size and not is_array(p.size))then 
		s = p.size; 
	end 
	-- (2)
	if(not is_table(p)) then 
		s = p; 
	end 
	if(is_table(p) and p.round == true)then
		round = true;
		if(v)then
			if(is_array(v))then
				r = (v[1]+v[2])/30;
			else 
				r = s / 10;
			end
		end
	end
	if(is_table(p) and p.radius)then
		round = true;
		r = p.radius;
	end
	if(is_table(p) and p.fn)then
		fn = p.fn; --applies in case of round: true
	end

	local x = s;
	local z = s; 
	if(v and is_array(v))then
		x = v[1];
		z = v[2]; 
	end
   
	off = {x/2,z/2}; -- center: false default
	local o;
	if(round)then
		--NOTE:Unimplemented
		--o = CAGModel:new():init(CSGFactory.roundedCube({radius = {x/2,y/2,z/2}, roundradius = r, resolution = fn}),"roundedSquare");
		o = CAGModel:new():init(CAGFactory.rectangle({radius = {x/2,z/2}}),"square");
	else
		o = CAGModel:new():init(CAGFactory.rectangle({radius = {x/2,z/2}}),"square");
	end
	if(is_table(p) and p.center and is_array(p.center))then
		if(p.center[1])then off[1] = 0; else off[1] = x/2;end
		if(p.center[2])then off[2] = 0; else off[2] = z/2;end
	elseif(is_table(p) and p.center == true)then
		off = {0,0};
	elseif(is_table(p) and p.center == false)then
		off = {x/2,z/2};
	end
	node:setDrawable(o);
	node:setTag("shape","square");

	if(off[1] ~= 0 or off[2] ~= 0)then
		node:translate(off[1],0,off[2]);
	end
	return node;
end
--[[
square(); // openscad like
square(1);
square({size = 1});
square({size = {1,2}});
square({size = 1, center = true}); // default center:false
square({size = 1, center = {true,true}}); // individual axis center true or false
--]]
function NplCadEnvironment:square__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_square(options);
	parent:addChild(node);
	return node;
end


--[[
		polygon
--]]
function NplCadEnvironment.polygon(options)
	local self = getfenv(2);
	return self:polygon__(options);
end
--[[
polygon({ {0,0},{3,0},{3,3} });                // openscad like
polygon({ points = { {0,0},{3,0},{3,3},{0,6} });                    
--]]
function NplCadEnvironment:polygon__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_polygon(options);
	parent:addChild(node);
	return node;
end

function NplCadEnvironment.read_polygon(p)
	local node = Node.create("");
	local points = {};
	local off = {0,0};

	-- { {0,0},{3,0},{3,3} }
	if(is_array(p))then
		points = p;
	end
	--{ points = { {0,0},{3,0},{3,3},{0,6} }
	if(is_table(p) and p.points)then 
		points = p.points; 
	end 
	local o;
	o = CAGModel:new():init(CAGFactory.polygon(points),"polygon");

	if(is_table(p) and p.center and is_array(p.center))then
		if(p.center[1])then off[1] = 0; else off[1] = x/2;end
		if(p.center[2])then off[2] = 0; else off[2] = z/2;end
	elseif(is_table(p) and p.center == true)then
		off = {0,0};
	elseif(is_table(p) and p.center == false)then
		off = {x/2,z/2};
	end
	node:setDrawable(o);
	node:setTag("shape","polygon");

	if(off[1] ~= 0 or off[2] ~= 0)then
		node:translate(off[1],0,off[2]);
	end
	return node;
end

--[[
		path2d
		-- { {0,0},{3,0},{3,3} }
		--{ points = { {0,0},{3,0},{3,3},{0,6} }
		-- { arc = {center={0,0,0},radius=1,startangle=0,endangle= 360,resolution=32,maketangent=false}}
	
--]]
function NplCadEnvironment.path2d(p)
	-- { {0,0},{3,0},{3,3} }
	if(is_array(p)) then
		return CAGFactory.path2dFromPoints(p);

	--{ points = { {0,0},{3,0},{3,3},{0,6} }
	elseif(is_table(p)) then 
		local closed = false;
		local path = nil;
		if(p.closed) then
			closed = p.closed;
		end
		if(p.points) then
			path = CAGFactory.path2dFromPoints(p.points);
		elseif(p.arc) then
			path = CAGFactory.path2dFromArc(p.arc);
		end
		path.closed = closed;
		return path;
	else
		return CAGFactory.path2dFromPoints({});
	end 
end


--[[
innerToCAG( path);
--]]
function NplCadEnvironment.innerToCAG(path)
	local self = getfenv(2);
	return self:innerToCAG__(path);
end
function NplCadEnvironment:innerToCAG__(path)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_innerToCAG(path);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_innerToCAG(path)
	local node = Node.create("");
	local obj = nil;
	local o;
	if(is_path(path)) then
		obj = path;
		if(obj.closed == true) then
			o = CAGModel:new():init(obj:innerToCAG(),"innerToCAG");
			node:setDrawable(o);
			node:setTag("shape","innerToCAG");
		else
			log("the path which innerToCAG should be CLOSED.");
		end
	else
		log("obj isn't a path,cannot be innerToCAG.");
	end
	return node;
end

--[[
expandToCAG(path,0.1);
expandToCAG(path,{pathradius = 0.1, fn = 8});
-- pathradius default is 0.1
-- fn default is 32
--]]
function NplCadEnvironment.expandToCAG(path,options)
	local self = getfenv(2);
	return self:expandToCAG__(path,options);
end
function NplCadEnvironment:expandToCAG__(path,options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_expandToCAG(path,options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_expandToCAG(path,options)
	local node = Node.create("");
	local obj = nil;
	local o;
	local pathradius = 0.1;
	local fn = 32;
	if(is_path(path)) then
		obj = path;
		if (is_number(options)) then 
			pathradius = options;
		elseif (is_table(options)) then
			if(is_number(options.pathradius)) then
				pathradius = options.pathradius;
			end
			if(is_number(options.fn)) then
				fn = options.fn;
			end
		end

		o = CAGModel:new():init(obj:expandToCAG(pathradius,fn),"expandToCAG");
		node:setDrawable(o);
		node:setTag("shape","expandToCAG");
	else
		log("obj isn't a path,cannot be expandToCAG.");
	end
	return node;
end

--[[
rectangular_extrude(path)
rectangular_extrude(path,0.1)
rectangular_extrude(path,{width = 0.1, height = 0.2, fn = 8})
-- width default is 0.1
-- height default is 0.1
-- fn default is 32
--]]

function NplCadEnvironment.rectangular_extrude(path,options)
	local self = getfenv(2);
	return self:rectangular_extrude__(path,options);
end
function NplCadEnvironment:rectangular_extrude__(path,options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_rectangular_extrude(path,options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_rectangular_extrude(path,options)
	local node = Node.create("");
	local obj = nil;
	local o;
	local width = 0.1;
	local height = 0.1
	local fn = 32;
	if(is_path(path)) then
		obj = path;

		if (is_number(options)) then 
			pathradius = options;
		elseif (is_table(options)) then
			if(is_number(options.width)) then
				width = options.width;
			end
			if(is_number(options.height)) then
				height = options.height;
			else
				height = width;
			end
			if(is_number(options.fn)) then
				fn = options.fn;
			end
		end

		o = CSGModel:new():init(obj:rectangularExtrude(width,height,fn),"rectangular_extrude");
		node:setDrawable(o);
		node:setTag("shape","rectangular_extrude");
	else
		log("obj isn't a path,cannot be rectangular_extrude.");
	end
	return node;
end

--[[
extrude(shape)
extrude(shape,{0,10,0})
extrude(shape,{offset = {0,10,0}, twistangle = 360, twiststeps = 100})
-- offset default is {0,0,1}
-- twistangle default is 0
-- twiststeps default is 32
--]]

function NplCadEnvironment.linear_extrude(shape,options)
	local self = getfenv(2);
	return self:linear_extrude__(shape,options);
end
function NplCadEnvironment:linear_extrude__(shape,options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_linear_extrude(shape,options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_linear_extrude(shape,options)
	local node = nil;
	local obj = nil;
	local o;
	local twistangle = 0;
	local twiststeps = 32
	local x,y,z = 0,1,0;
	if(is_sharp(shape)) then
		node = shape;
		obj = node:getDrawable().cag_node;
		if(obj.extrude) then
			if (is_array(options)) then 
				if(is_number(options[1])) then
					x = options[1];
				end
				if(is_number(options[2])) then
					y = options[2];
				end
				if(is_number(options[3])) then
					z = options[3];
				end
			elseif (is_table(options)) then
				if(is_table(options.offset)) then
					if(is_number(options.offset[1])) then
						x = options.offset[1];
					end
					if(is_number(options.offset[2])) then
						y = options.offset[2];
					end
					if(is_number(options.offset[3])) then
						z = options.offset[3];
					end
				end
				if(is_number(options.twistangle)) then
					twistangle = options.twistangle;
				end
				if(is_number(options.twiststeps)) then
					twiststeps = options.twiststeps;
				end
			end
			o = CSGModel:new():init(obj:extrude({offset = {x,y,z},twistangle = twistangle,twiststeps = twiststeps}),"extrude");
			node:setDrawable(o);
			node:setTag("extrude","linear_extrude");
		else
			log("obj isn't a shape,cannot be linear_extrude.");
		end
	end
	return node;
end

--[[
rotate_extrude
arguments: options dict with angle and resolution, both optional
rotate_extrude(shape,angle)
rotate_extrude(shape,{angle = a, fn = 8})
-- angle default is 360
-- fn default is 32
--]]

function NplCadEnvironment.rotate_extrude(shape,options)
	local self = getfenv(2);
	return self:rotate_extrude__(shape,options);
end
function NplCadEnvironment:rotate_extrude__(shape,options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_rotate_extrude(shape,options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_rotate_extrude(shape,options)
	local node = nil;
	local obj = nil;
	local o;
	local angle = 360;
	local fn = CSGFactory.defaultResolution2D;
	if(is_sharp(shape)) then
		node = shape;
		obj = node:getDrawable().cag_node;
		if(obj.rotateExtrude) then
			if (is_number(options)) then 
				angle = options;
			elseif (is_table(options)) then
				if(is_number(options.angle)) then
					angle = options.angle;
				end
				if(is_number(options.fn)) then
					fn = options.fn;
				end
			end
			o = CSGModel:new():init(obj:rotateExtrude({angle = angle,resolution = fn}),"rotate_extrude");
			node:setDrawable(o);	-- cag should be destroy by this.
			node:setTag("extrude","rotate_extrude");
		else
			log("obj isn't a shape,cannot be rotate_extrude.");
		end
	end
	return node;
end


--[[
polyhedron
     Parameters:
       points: points list for this polyhedron
       faces: trangles list for this polyhedron
--]]
function NplCadEnvironment.polyhedron(options)
	local self = getfenv(2);
	return self:polyhedron__(options);
end
function NplCadEnvironment:polyhedron__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_polyhedron(options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_polyhedron(options)
	local node = Node.create("");
	local o = CSGModel:new():init(CSGFactory.polyhedron(options));
	if(o ~= nil) then
		node:setDrawable(o);
	end
	return node;
end


--[[
rectangle();
rectangle({center = x});
rectangle({center = {x,y}});
rectangle({radius = w});
rectangle({radius = {w,h}});
rectangle({center = {0,0}, radius = {w,h}});
--]]
function NplCadEnvironment.rectangle(options)
	local self = getfenv(2);
	return self:rectangle__(options);
end
function NplCadEnvironment:rectangle__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_rectangle(options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_rectangle(p)
	local node = Node.create("");
	local center = {0,0};
	local radius = {1,1};

	if(is_table(p))then 
		if(p.center) then
			if(is_array(p.center))then
				center[1] = p.center[1];
				center[2] = p.center[2]; 
			elseif(is_number(p.center)) then
				center[1] = p.center;
				center[2] = p.center; 				
			end
		end
		if(p.radius)then
			if(is_array(p.radius))then
				radius[1] = p.radius[1]/2;
				radius[2] = p.radius[2]/2; 
			elseif(is_number(p.radius)) then
				radius[1] = p.radius/2;
				radius[2] = p.radius/2; 				
			end			
		end
	end 

	local o = CAGModel:new():init(CAGFactory.rectangle({center = center,  radius = radius}),"rectangle");
	node:setDrawable(o);
	node:setTag("shape","rectangle");
	return node;
end

--[[
roundedRectangle();
roundedRectangle({center = x});
roundedRectangle({center = {x,y}});
roundedRectangle({radius = w});
roundedRectangle({radius = {w,h}});
roundedRectangle({center = {0,0}, radius = {w,h}});
roundedRectangle({center = {0,0}, radius = {w,h},roundradius = 1,resolution = 32});
--]]
function NplCadEnvironment.roundedRectangle(options)
	local self = getfenv(2);
	return self:roundedRectangle__(options);
end
function NplCadEnvironment:roundedRectangle__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_roundedRectangle(options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_roundedRectangle(p)
	local node = Node.create("");
	local center = {0,0};
	local radius = {1,1};
	local roundradius  = 0.2;
	local resolution = 8;

	if(is_table(p))then 
		if(p.center) then
			if(is_array(p.center))then
				center[1] = p.center[1];
				center[2] = p.center[2]; 
			elseif(is_number(p.center)) then
				center[1] = p.center;
				center[2] = p.center; 				
			end
		end
		if(p.radius)then
			if(is_array(p.radius))then
				radius[1] = p.radius[1]/2;
				radius[2] = p.radius[2]/2; 
			elseif(is_number(p.radius)) then
				radius[1] = p.radius/2;
				radius[2] = p.radius/2; 				
			end			
		end
		if(p.roundradius and is_number(p.roundradius))then
			roundradius = p.roundradius;
		end
		if(p.resolution and is_number(p.resolution))then
			resolution = p.resolution;
		end
	end 

	local o = CAGModel:new():init(CAGFactory.roundedRectangle({center = center,  radius = radius, roundradius = roundradius, resolution = resolution}),"roundedRectangle");
	node:setDrawable(o);
	node:setTag("shape","roundedRectangle");
	return node;
end

--[[
ellipse();
ellipse({center = x});
ellipse({center = {x,y}});
ellipse({radius = w});
ellipse({radius = {w,h}});
ellipse({center = {0,0}, radius = {w,h}});
--]]
function NplCadEnvironment.ellipse(options)
	local self = getfenv(2);
	return self:ellipse__(options);
end
function NplCadEnvironment:ellipse__(options)
	options = options or {};
	local parent = self:getNode__();

	local node = NplCadEnvironment.read_ellipse(options);
	parent:addChild(node);
	return node;
end
function NplCadEnvironment.read_ellipse(p)
	local node = Node.create("");
	local center = {0,0};
	local radius = {1,1};

	if(is_table(p))then 
		if(p.center) then
			if(is_array(p.center))then
				center[1] = p.center[1];
				center[2] = p.center[2]; 
			elseif(is_number(p.center)) then
				center[1] = p.center;
				center[2] = p.center; 				
			end
		end
		if(p.radius)then
			if(is_array(p.radius))then
				radius[1] = p.radius[1]/2;
				radius[2] = p.radius[2]/2; 
			elseif(is_number(p.radius)) then
				radius[1] = p.radius/2;
				radius[2] = p.radius/2; 				
			end			
		end
	end 

	local o = CAGModel:new():init(CAGFactory.ellipse({center = center,  radius = radius}),"ellipse");
	node:setDrawable(o);
	node:setTag("shape","ellipse");
	return node;
end