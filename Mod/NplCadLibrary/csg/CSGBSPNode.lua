--[[
Title: CSGBSPNode
Author(s): leio
Date: 2016/3/29
Desc: 
Holds a node in a BSP tree. A BSP tree is built from a collection of polygons
by picking a polygon to split along. That polygon (and all other coplanar
polygons) are added directly to that node and the other polygons are added to
the front and/or back subtrees. This is not a leafy BSP tree since there is
no distinction between internal and leaf nodes.

This class uses copy on write policy
-------------------------------------------------------
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGBSPNode.lua");
local CSGBSPNode = commonlib.gettable("Mod.NplCadLibrary.csg.CSGBSPNode");
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/math/Plane.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGPolygon.lua");
NPL.load("(gl)Mod/NplCadLibrary/utils/tableext.lua");

local tableext = commonlib.gettable("Mod.NplCadLibrary.utils.tableext");
local CSGPolygon = commonlib.gettable("Mod.NplCadLibrary.csg.CSGPolygon");
local CSGBSPNode = commonlib.inherit(nil, commonlib.gettable("Mod.NplCadLibrary.csg.CSGBSPNode"));

-- move polygons from source to result, if result is nil, a new table is created. 
-- @param source: array of polygons
-- @param result: [inout] nil or target polygon tables.
-- @return result
local function movePolygons(source, result)
	if(not source)then
		return
	end
	result = result or {};
	for i = 1, #source do
		result[#result+1] = source[i];
	end
	return result;
end

function CSGBSPNode:ctor()
end

function CSGBSPNode:init(polygons,convex)
	self.plane = nil;
	self.front = nil;
	self.back = nil;
	if (polygons) then
		if(convex) then
			self:buildConvex(polygons);
		else
			self:build(polygons);
		end
	end
	return self;
end

-- this is a copy on write clone
function CSGBSPNode:clone()
	local node = CSGBSPNode:new();
	node.plane = self.plane;
	if(self.front)then
		node.front = self.front:clone();
	end
	if(self.back)then
		node.back = self.back:clone();
	end
	if(self.polygons) then
		node.polygons = movePolygons(self.polygons);
	end
	return node;
end

-- performs a deep copy of all its internal data. 
-- used whenever data is about to be modified for implicit copy-on-write object.
function CSGBSPNode:detach()
	self.plane = self.plane and self.plane:clone();
	local polygons = self.polygons;
	if(polygons) then
		for i=1, #polygons do
			polygons[i] = polygons[i]:clone();
		end
	end
	return self;
end

--Convert solid space to empty space and empty space to solid space.
function CSGBSPNode:invert(bInplace)
	local polygons = self.polygons;
	if(polygons) then
		for i=1, #polygons do
			polygons[i] = polygons[i]:clone():flip();
		end
	end
	if(self.plane)then
		self.plane = self.plane:clone():inverse();
	end
	if(self.front)then
		self.front:invert(bInplace);
	end
	if(self.back)then
		self.back:invert(bInplace);
	end
	self.front, self.back = self.back, self.front;
end

--Recursively remove all polygons in `polygons` that are inside this BSP tree.
function CSGBSPNode:clipPolygons(polygons)
	if(not polygons) then
		return
	end
	if(not self.plane)then
		return movePolygons(polygons);
	end
	local front, back;
	for k,p in ipairs(polygons) do
		local front1, back1, coplanarFront, coplanarBack = self:splitPolygon(p,front, back, front, back);
		if(not front) then
			front = front1 or coplanarFront;
		end
		if(not back) then
			back = back1 or coplanarBack;
		end
	end
	if(self.front)then
		front = self.front:clipPolygons(front);
	end
	if(self.back)then
		back = self.back:clipPolygons(back);
	else
		back = nil; 
	end
	return front and movePolygons(front, back) or back;
end

--Remove all polygons in this BSP tree that are inside the other BSP tree 'bsp'.
-- @param bsp: another CSGBSPNode
function CSGBSPNode:clipTo(bsp)
	if(not bsp)then return end
	if(self.polygons) then
		self.polygons = bsp:clipPolygons(self.polygons);
	end
	if(self.front)then
		self.front:clipTo(bsp);
	end
	if(self.back)then
		self.back:clipTo(bsp);
	end
end

--Return a list of all polygons in this BSP tree.
-- @param result: inout, array of polygons
function CSGBSPNode:allPolygons(result)
	result = result or {};
	if(self.polygons) then
		movePolygons(self.polygons, result);
	end
	if(self.front)then
		self.front:allPolygons(result);
	end
	if(self.back)then
		self.back:allPolygons(result);
	end
	return result;
end

--Build a BSP tree out of `polygons`. When called on an existing tree, the
--new polygons are filtered down to the bottom of the tree and become new
--nodes there. Each set of polygons is partitioned using the first polygon
--(no heuristic is used to pick a good split).
function CSGBSPNode:build(polygons)
	if(not polygons or #polygons == 0)then
		return;
	end
	local front;
	local back;

	if(not self.plane) then
		self.plane = polygons[1]:GetPlane();
		
		self.polygons = self.polygons or {};
		self.polygons[#self.polygons+1] = polygons[1];

		for i = 2, #polygons do
			front, back, self.polygons = self:splitPolygon(polygons[i], self.polygons, self.polygons, front, back);
		end	
	else
		for i = 1, #polygons do
			front, back, self.polygons = self:splitPolygon(polygons[i], self.polygons, self.polygons, front, back);
		end	
	end
	
	
	if(front)then
		if(not self.front)then
			self.front = CSGBSPNode:new():init();
		end
		self.front:build(front);
	end
	if(back)then
		if(not self.back)then
			self.back = CSGBSPNode:new():init();
		end
		self.back:build(back);
	end
end

function CSGBSPNode:getVertexCnt()
	local cnt = 0;
	if(self.polygons) then
		for k,p in ipairs(self.polygons) do
			cnt  = cnt  + p:getVertexCnt();
		end
	end
	return cnt;
end

local types = {};
local dots = {};

local COPLANAR = 0;
local FRONT = 1;
local BACK = 2;
local SPANNING = 3;
local EPSILON = 0.00001;
local bor = mathlib.bit.bor;

-- Split `polygon` by self plane if needed, then put the polygon or polygon
-- fragments in the appropriate lists. Coplanar polygons go into either
-- `coplanarFront` or `coplanarBack` depending on their orientation with
-- respect to self plane. Polygons in front or in back of self plane go into
-- either `front` or `back`.
-- @param front: inout parameter.  if nil, it will be created and returned.
-- @param back: inout parameter.  if nil, it will be created and returned.
-- @return front, back, coplanarFront, coplanarBack
function CSGBSPNode:splitPolygon(polygon, coplanarFront, coplanarBack, front, back)
	--Classify each point as well as the entire polygon into one of the above four classes.
    local polygonType = 0;
    
	-- tableext.clear(types);
	local vertices = polygon.vertices;
	for i = 1, #vertices do
		local v = vertices[i];
		local t = self.plane:signedDistanceToPoint(v.pos);
		local type;
		if(t < -EPSILON)then
			type = BACK;
		elseif(t > EPSILON)then
			type = FRONT;
		else
			type = COPLANAR;
		end
		polygonType = bor(polygonType, type);
		types[i] = type;
		dots[i] = t;
	end

	if(polygonType == COPLANAR)then
		local plane = polygon:GetPlane();
		if((self.plane[1] == plane[1]) and (self.plane[2] == plane[2]) and (self.plane[3] == plane[3]))then
			coplanarFront = coplanarFront or {};
			coplanarFront[#coplanarFront+1] = polygon;
		else
			coplanarBack = coplanarBack or {};
			coplanarBack[#coplanarBack+1] = polygon;
		end
	elseif(polygonType == FRONT)then
		front = front or {};
		front[#front+1] = polygon;
	elseif(polygonType == BACK)then
		back = back or {};
		back[#back+1] = polygon;
	elseif(polygonType == SPANNING)then
		local backCount, frontCount = 0, 0;
		local f = {};
		local b = {};
		local size = #vertices;
		for i = 1, size do
			local j = (i % size) + 1;
			local ti = types[i];
			local tj = types[j];
			local vi = vertices[i];
			local vj = vertices[j];
			if(ti ~= BACK)then
				frontCount = frontCount + 1;
				f[frontCount] = vi;
			end
			if(ti ~= FRONT)then
				if(ti ~= BACK)then
					backCount = backCount + 1;
					b[backCount] = vi;
				else
					backCount = backCount + 1;
					b[backCount] = vi;
				end
			end
			if(bor(ti, tj) == SPANNING)then
				local t = (-dots[i]) / (dots[j]-dots[i]);
				local v = vi:clone():interpolate(vj, t);
				frontCount = frontCount + 1;
				f[frontCount] = v;
				backCount = backCount + 1;
				b[backCount] = v;
			end
		end
		if(frontCount >= 3)then
			front = front or {};
			front[#front+1] = CSGPolygon:new():init(f,polygon.shared,polygon.plane);
		end
		if(backCount >= 3)then
			back = back or {};
			back[#back+1] = CSGPolygon:new():init(b,polygon.shared,polygon.plane);
		end
	end
	return front, back, coplanarFront, coplanarBack;
end


function CSGBSPNode:buildConvex(polygons)
	if(not polygons or #polygons == 0)then
		return;
	end
	local front;
	local back;

	self.plane = polygons[1]:GetPlane();
	
	self.polygons = self.polygons or {};
	self.polygons[#self.polygons+1] = polygons[1];

	for i = 2, #polygons do
		front, back, self.polygons = self:splitPolygonConvex(polygons[i], self.polygons, front, back);
	end
	
	
	if(front)then
		if(not self.front)then
			self.front = CSGBSPNode:new():init();
		end
		self.front:buildConvex(front);
	end
	if(back)then
		if(not self.back)then
			self.back = CSGBSPNode:new():init();
		end
		self.back:buildConvex(back);
	end
end
function CSGBSPNode:splitPolygonConvex(polygon, coplanar, front, back)
	--Classify each point as well as the entire polygon into one of the above four classes.
    local polygonType = 0;
    
	-- tableext.clear(types);
	local vertices = polygon.vertices;
	local v_count = #vertices;
	for i = 1, v_count do
		local v = vertices[i];
		local t = self.plane:signedDistanceToPoint(v.pos);
		local type;
		if(t < -EPSILON)then
			polygonType = BACK;
		elseif(t > EPSILON)then
			polygonType = FRONT;
		end
		if(polygonType ~= 0) then
			break
		end
	end

	if(polygonType == COPLANAR)then
		coplanar = coplanar or {};
		coplanar[#coplanar+1] = polygon;
	elseif(polygonType == FRONT)then
		front = front or {};
		front[#front+1] = polygon;
	elseif(polygonType == BACK)then
		back = back or {};
		back[#back+1] = polygon;
	end
	return front, back, coplanar;
end