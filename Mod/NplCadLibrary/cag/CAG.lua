--[[
Title: CSG Node
Author(s): Skeleton, based on http:--evanw.github.com/csg.js/
Date: 2016/11/26
Desc: 
	CAG: solid area geometry: like CSG but 2D
	Each area consists of a number of sides
	Each side is a line between 2 points
-------------------------------------------------------
NPL.load("(gl)Mod/NplCadLibrary/cag/CAG.lua");
local CAG = commonlib.gettable("Mod.NplCadLibrary.cag.CAG");
-------------------------------------------------------
--]]
NPL.load("(gl)Mod/NplCadLibrary/utils/commonlib_ext.lua");

NPL.load("(gl)script/ide/math/bit.lua");
NPL.load("(gl)script/ide/math/vector.lua");
NPL.load("(gl)script/ide/math/vector2d.lua");
NPL.load("(gl)script/ide/math/Matrix4.lua");

NPL.load("(gl)Mod/NplCadLibrary/cag/CAGVertex.lua");
NPL.load("(gl)Mod/NplCadLibrary/cag/CAGSide.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGConnector.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGOrthoNormalBasis.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSG.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGFactory.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGPolygon.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVertex.lua");
NPL.load("(gl)Mod/NplCadLibrary/utils/tableext.lua");
NPL.load("(gl)Mod/NplCadLibrary/utils/mathext.lua");

local vector3d = commonlib.gettable("mathlib.vector3d");
local vector2d = commonlib.gettable("mathlib.vector2d");
local Matrix4 = commonlib.gettable("mathlib.Matrix4");

local CAGVertex = commonlib.gettable("Mod.NplCadLibrary.cag.CAGVertex");
local CAGSide = commonlib.gettable("Mod.NplCadLibrary.cag.CAGSide");
local CSGConnector = commonlib.gettable("Mod.NplCadLibrary.csg.CSGConnector");
local CSGOrthoNormalBasis = commonlib.gettable("Mod.NplCadLibrary.csg.CSGOrthoNormalBasis");
local CSG = commonlib.gettable("Mod.NplCadLibrary.csg.CSG");
local CSGFactory = commonlib.gettable("Mod.NplCadLibrary.csg.CSGFactory");
local CSGPolygon = commonlib.gettable("Mod.NplCadLibrary.csg.CSGPolygon");
local CSGVertex = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVertex");
local tableext = commonlib.gettable("Mod.NplCadLibrary.utils.tableext");
local mathext = commonlib.gettable("Mod.NplCadLibrary.utils.mathext");

local CAG = commonlib.inherit_ex(nil, commonlib.gettable("Mod.NplCadLibrary.cag.CAG"));


function CAG:ctor()
	self.sides = self.sides or {};
	tableext.clear(self.sides);
end

function CAG:GetSideCount()
	return #self.sides;
end

-- Construct a CAG from a list of `CAG.Side` instances.
function CAG.fromSides(sides)
    local cag = CAG:new();
	tableext.copy(cag.sides,sides,nil);
    return cag;
end

-- Construct a CAG from a list of points (a polygon)
-- Rotation direction of the points is not relevant. Points can be a convex or concave polygon.
-- Polygon must not self intersect
function CAG.fromPoints(points)
	points = points or {};
    local numpoints = #points;
    if numpoints < 3 then
		LOG.std(nil, "error", "CAG.fromPoints", "CAG shape needs at least 3 points");
		return nil;
	end

	local sides = {};
    local prevpoint = vector2d:new(points[numpoints]);
    local prevvertex = CAGVertex:new():init(prevpoint);
	
	-- build side from points array
    for k,v in ipairs(points)  do
		local vertex = CAGVertex:new():init(v);
		local side = CAGSide:new():init(prevvertex, vertex);
		table.insert(sides,side);
		prevvertex = vertex;
	end

	-- build CAF from sides array
	local result = CAG.fromSides(sides);
    if result:isSelfIntersecting() then
		LOG.std(nil, "error", "CAG.fromPoints", "Polygon is self intersecting!");
		return nil;
	end

	local area = result:area();
    if math.abs(area) < tonumber("1e-5") then
        LOG.std(nil, "error", "CAG.fromPoints", "Degenerate polygon!");
		return nil;
	end
	if area < 0 then
		result = result:flipped();
	end
	-- should we use fuzzyFactory for all CSG&CAG?
	-- result = result.canonicalized();
	return result;
end


-- Like CAG.fromPoints but does not check if it's a valid polygon.
-- Points should rotate counter clockwise
function CAG.fromPointsNoCheck(points)
	local sides = {};
	local numpoints = #points;
    local prevpoint = vector2d:new(points[numpoints]);
    local prevvertex = CAGVertex:new():init(prevpoint);
	
	-- build side from points array
    for k,v in ipairs(points)  do
		local vertex = CAGVertex:new():init(v);
		local side = CAGSide:new():init(prevvertex, vertex);
		table.insert(sides,side);
		prevvertex = vertex;
	end
	return CAG.fromSides(sides);
end


-- Converts a CSG to a CAG. The CSG must consist of polygons with only z coordinates +1 and -1
-- as constructed by CAG:_toCSGWall(-1, 1). This is so we can use the 3D union(), intersect() etc
function CAG.fromFakeCSG(csg) 
	local sides = {};
	-- can we sure csg.polygons is an array?
    local polygons = csg:GetPolygons();
	for k,poly in ipairs(polygons) do
		local side = CAGSide._fromFakePolygon(poly);
		table.insert(sides,side);
	end
	return CAG.fromSides(sides);
end

-- see if the line between p0start and p0end intersects with the line between p1start and p1end
-- returns true if the lines strictly intersect, the end points are not counted!
function CAG.linesIntersect(p0start, p0end, p1start, p1end)
    if (p0end:equals(p1start) or p1end:equals(p0start)) then
        local d = p1end:clone():sub(p1start):normalize():add(p0end:clone():sub(p0start):normalize()):length();
        if (d < tonumber("1e-5")) then
            return true;
        end
    else
        local d0 = p0end:clone():sub(p0start);
        local d1 = p1end:clone():sub(p1start);

		-- lines are parallel
        if math.abs(d0:cross(d1)) < tonumber("1e-9") then 
			return false; 
		end

        local alphas = CSG.solve2Linear(-d0[1], d1[1], -d0[2], d1[2], p0start[1] - p1start[1], p0start[2] - p1start[2]);
        if ((alphas[1] > tonumber("1e-6")) and (alphas[1] < 0.999999) and (alphas[2] > tonumber("1e-5")) and (alphas[2] < 0.999999)) then
			return true;
		end
        --    if( (alphas[1] >= 0) and (alphas[1] <= 1) and (alphas[2] >= 0) and (alphas[2] <= 1) ) return true;
    end
    return false;
end

function CAG:_toCSGWall(y0, y1) 
	local polygons = {};
	for k,side in ipairs(self.sides) do
		table.insert(polygons,side:toPolygon3D(y0,y1));
	end
    return CSG.fromPolygons(polygons);
end

function CAG:_toVector3DPairs(m) 
	local pairs = {};
	for k,side in ipairs(self.sides) do
		local p0 = side.vertex0.pos;
		local p1 = side.vertex1.pos;
		local vector0 = p0:toVector3D(0);
		local vector1 = p1:toVector3D(0);
		if m ~= nil then
			vector0 = vector0:transform(m);
			vector1 = vector1:transform(m);
		end
		table.insert(pairs,{vector0,vector1});
	end
	return pairs;
end

--[[
    * transform a cag into the polygons of a corresponding 3d plane, positioned per options
    * Accepts a connector for plane positioning, or optionally
    * single translation, axisVector, normalVector arguments
    * (toConnector has precedence over single arguments if provided)
    */
--]]
function CAG:_toPlanePolygons(options)
    local flipped = options.flipped or false;
	-- reference connector for transformation
    local origin = {0, 0, 0}; 
	local defaultAxis = {0, 1, 0};
	local defaultNormal = {0, 0, -1};
    local thisConnector = CSGConnector:new():init(origin, defaultAxis, defaultNormal);

    -- translated connector per options
    local translation = options.translation or origin;
    local axisVector = options.axisVector or defaultAxis;
    local normalVector = options.normalVector or defaultNormal;
    -- will override above if options has toConnector
    local toConnector = options.toConnector or
        CSGConnector:new():init(translation, axisVector, normalVector);
    -- resulting transform
    local m = thisConnector:getTransformationTo(toConnector, false, 0);

    -- create plane as a (partial non-closed) CSG in XY plane
    local bounds = self:getBounds();
    bounds[1] = bounds[1] - vector2d:new(1, 1);
    bounds[2] = bounds[2] + vector2d:new(1, 1);
    local csgshell = self:_toCSGWall(-1, 1);
    local csgplane = CSG.fromPolygons({CSGPolygon:new():init({
        CSGVertex:new():init(vector3d:new(bounds[1][1], 0, bounds[1][2])),
        CSGVertex:new():init(vector3d:new(bounds[1][1], 0, bounds[2][2])),
        CSGVertex:new():init(vector3d:new(bounds[2][1], 0, bounds[2][2])),
		CSGVertex:new():init(vector3d:new(bounds[2][1], 0, bounds[1][2]))
    })});

    -- intersectSub -> prevent premature retesselate/canonicalize
    csgplane = csgplane:intersect(csgshell);

    -- only keep the polygons in the z plane:
    local polys = {};
	for k,polygon in ipairs(csgplane.polygons) do
		local plane = polygon:GetPlane();
		if(math.abs(plane[2]) > 0.99) then
		    if (flipped) then
				polygon = polygon:clone():flip();
			end
			table.insert(polys,polygon);
		end
	end
    -- finally, position the plane per passed transformations
	local i;
	for i=1,#polys,1 do
		polys[i] = polys[i]:transform(m);
	end
	return polys;
end
--[[
    * given 2 connectors, self returns all polygons of a "wall" between 2
    * copies of self cag, positioned in 3d space as "bottom" and
    * "top" plane per connectors toConnector1, and toConnector2, respectively 
--]]
function CAG:_toWallPolygons(options)
    -- normals are going to be correct as long as toConn2.point - toConn1.point
    -- points into cag normal direction (check in caller)
    -- arguments: options.toConnector1, options.toConnector2, options.cag
    --     walls go from toConnector1 to toConnector2
    --     optionally, target cag to point to - cag needs to have same number of sides as self!
    local origin = {0, 0, 0}; 
	local defaultAxis = {0, 1, 0};
	local defaultNormal = {0, 0, -1};
    local thisConnector = CSGConnector:new():init(origin, defaultAxis, defaultNormal);
    -- arguments:
    local toConnector1 = options.toConnector1;
    -- local toConnector2 = CSGConnector:new():init([0, 0, -30], defaultAxis, defaultNormal);
    local toConnector2 = options.toConnector2;

    if ( toConnector1:class() ~=  CSGConnector or toConnector2:class() ~=  CSGConnector) then
		LOG.std(nil, "error", "CAG:_toWallPolygons", "could not parse CSG.Connector arguments toConnector1 or toConnector2");
		return nil;
    end
    if (options.cag) then
        if (#options.cag.sides ~= #self.sides) then
			LOG.std(nil, "error", "CAG:_toWallPolygons", "target cag needs same sides count as start cag");
			return nil;
        end
    end
    -- target cag is same as self unless specified
    local toCag = options.cag or self;
    local m1 = thisConnector:getTransformationTo(toConnector1, false, 0);
    local m2 = thisConnector:getTransformationTo(toConnector2, false, 0);
    local vps1 = self:_toVector3DPairs(m1);
    local vps2 = toCag:_toVector3DPairs(m2);

    local polygons = {};
	for k,v in ipairs(vps1) do
		table.insert(polygons,CSGPolygon:new():init({CSGVertex:new():init(vps2[k][1]:clone()), CSGVertex:new():init(vps2[k][2]:clone()), CSGVertex:new():init(v[1]:clone())}));
        table.insert(polygons,CSGPolygon:new():init({CSGVertex:new():init(v[1]:clone()), CSGVertex:new():init(vps2[k][2]:clone()), CSGVertex:new():init(v[2]:clone())}));
	end
    return polygons;
end


function CAG:union(cag)
    local cags;
    if (tableext.is_array(cag)) then
        cags = cag;
    else
        cags = {cag};
    end
    local r = self:_toCSGWall(-1, 1);
	for k,cag in ipairs(cags) do
		r = r:union(cag:_toCSGWall(-1, 1));
	end
    return CAG.fromFakeCSG(r);
end

function CAG:subtract(cag)
    local cags;
    if (tableext.is_array(cag)) then
        cags = cag;
    else
        cags = {cag};
    end
    local r = self:_toCSGWall(-1, 1);
	for k,v in ipairs(cags) do
		r = r:subtract(v:_toCSGWall(-1, 1));
	end
    r = CAG.fromFakeCSG(r);
    return r;
end

function CAG:intersect(cag)
    local cags;
    if (tableext.is_array(cag)) then
        cags = cag;
    else
        cags = {cag};
    end
    local r = self:_toCSGWall(-1, 1);
	for k,v in ipairs(cags) do
		r = r:intersect(v:_toCSGWall(-1, 1));
	end
    r = CAG.fromFakeCSG(r);
    return r;
end

function CAG:transform(matrix4x4)
    local ismirror = matrix4x4.isMirroring();
    local newsides = {};
	for k,side in ipairs(self.sides) do
        table.insert(newsides, side:transform(matrix4x4));
    end
    local result = CAG.fromSides(newsides);
    if (ismirror) then
        result = result:flipped();
    end
    return result;
end


-- see http:--local.wasp.uwa.edu.au/~pbourke/geometry/polyarea/ :
-- Area of the polygon. For a counter clockwise rotating polygon the area is positive, otherwise negative
-- Note(bebbi): self looks wrong. See polygon getArea()
function CAG:area()
    local polygonArea = 0.0;
	for k,v in ipairs(self.sides) do
		polygonArea = polygonArea + v.vertex0.pos:cross(v.vertex1.pos);
	end
    polygonArea = polygonArea * 0.5;
    return polygonArea;
end

function CAG:flipped()
    tableext.reverse(self.sides,CAGSide.flipped);
    return self;
end

function CAG:getBounds()
    local minpoint;
    if (#self.sides == 0) then
        minpoint = vector2d:new(0, 0);
    else
        minpoint = self.sides[1].vertex0.pos;
    end
    local maxpoint = minpoint;
	for k,v in ipairs(self.sides) do
        minpoint = minpoint:clone():min(v.vertex0.pos);
        minpoint = minpoint:clone():min(v.vertex1.pos);
        maxpoint = maxpoint:clone():max(v.vertex0.pos);
        maxpoint = maxpoint:clone():max(v.vertex1.pos);
	end
    return {minpoint, maxpoint};
end

function CAG:isSelfIntersecting(debug)
    local numsides = #self.sides;
	local i;
    for i = 1, numsides, 1 do
        local side0 = self.sides[i];
		local ii
        for ii = i + 2, numsides, 1 do
            local side1 = self.sides[ii];
            if (CAG.linesIntersect(side0.vertex0.pos, side0.vertex1.pos, side1.vertex0.pos, side1.vertex1.pos)) then
                if (debug) then
					LOG.std(nil, "info", "CAG:isSelfIntersecting", side0);
					LOG.std(nil, "info", "CAG:isSelfIntersecting", side1);
				end
                return true;
            end
        end
    end
    return false;
end

function CAG:expandedShell(radius, resolution)
    resolution = resolution or 8;
    if (resolution < 4) then
		resolution = 4;
	end
    local cags = {};
    local pointmap = {};
    --local cag = self.canonicalized();

	for k,side in ipairs(self.sides) do
        local d = side.vertex1.pos - side.vertex0.pos;
        local dl = d:length();
        if (dl > tonumber("1e-5")) then
            d = d:MulByFloat(1.0 / dl);
            local normal = d:normal():MulByFloat(radius);
            local shellpoints = {
                side.vertex1.pos + normal,
                side.vertex1.pos - normal,
                side.vertex0.pos - normal,
                side.vertex0.pos + normal
            };
            --  local newcag = CAG.fromPointsNoCheck(shellpoints);
            local newcag = CAG.fromPoints(shellpoints);
            table.insert(cags,newcag);
			local step;
            for step = 0, 1 ,1 do
                local p1;
				local p2;
				if (step == 0) then
					p1 = side.vertex0.pos ;
					p2 = side.vertex1.pos;
				else
					p1 = side.vertex1.pos;
					p2 = side.vertex0.pos;
				end
                local tag = p1[1] .. " " .. p1[2];
                if (pointmap[tag] == nil) then
                    pointmap[tag] = {};
                end
				table.insert(pointmap[tag],{
                    p1 = p1,
                    p2 = p2
                });
            end
        end
    end
    for tag,v in pairs(pointmap) do
        local m = pointmap[tag];
        local angle1, angle2;
        local pcenter = m[1].p1;
        if (m.length == 2) then
            local end1 = m[1].p2;
            local end2 = m[2].p2;
            angle1 = (end1-pcenter):angleDegrees();
            angle2 = (end2-pcenter):angleDegrees();
            if (angle2 < angle1) then
				angle2 = angle2 + 360;
			end
            if (angle2 >= (angle1 + 360)) then
				angle2 = angle2 - 360;
			end
            if (angle2 < angle1 + 180) then
                local t = angle2;
                angle2 = angle1 + 360;
                angle1 = t;
            end
            angle1 = angle1 + 90;
            angle2 = angle2 - 90;
        else
            angle1 = 0;
            angle2 = 360;
        end
        local fullcircle = (angle2 > angle1 + 359.999);
        if (fullcircle) then
            angle1 = 0;
            angle2 = 360;
        end
        if (angle2 > (angle1 + tonumber("1e-5"))) then
            local points = {};
            if (not fullcircle) then
                table.insert(points,pcenter);
            end
            local numsteps = mathext.round(resolution * (angle2 - angle1) / 360);
            if (numsteps < 1) then 
				numsteps = 1;
			end
			local step;
            for step = 0, numsteps, 1 do
                local angle = angle1 + step / numsteps * (angle2 - angle1);
                if (step == numsteps) then
					angle = angle2; -- prevent rounding errors
				end
                local point = pcenter + (vector2d.fromAngleDegrees(angle):MulByFloat(radius));
                if ((not fullcircle) or (step > 0)) then
					table.insert(points,point);
                end
            end
            local newcag = CAG.fromPointsNoCheck(points);
            table.insert(cags,newcag);
        end
    end
    local result = CAG:new();
    result = result:union(cags);
    return result;
end

function CAG:expand(radius, resolution)
    local result = self:union(self:expandedShell(radius, resolution));
    return result;
end

function CAG:contract(radius, resolution)
    local result = self:subtract(self:expandedShell(radius, resolution));
    return result;
end


-- extrude the CAG in a certain plane. 
-- Giving just a plane is not enough, multiple different extrusions in the same plane would be possible
-- by rotating around the plane's origin. An additional right-hand vector should be specified as well,
-- and self is exactly a CSG.OrthoNormalBasis.
-- orthonormalbasis: characterizes the plane in which to extrude
-- depth: thickness of the extruded shape. Extrusion is done symmetrically above and below the plane.
function CAG:extrudeInOrthonormalBasis(orthonormalbasis, depth)
    -- first extrude in the regular Z plane:
    if (orthonormalbasis:class() ~= CSGOrthoNormalBasis) then
		LOG.std(nil, "error", "CAG:extrudeInOrthonormalBasis", "the first parameter should be a CSG.OrthoNormalBasis");
		return nil;
    end
    local extruded = self.extrude({offset = {0, 0, depth}});
    local matrix = orthonormalbasis.getInverseProjectionMatrix();
    extruded = extruded:transform(matrix);
    return extruded;
end

-- Extrude in a standard cartesian plane, specified by two axis identifiers. Each identifier can be
-- one of ["X","Y","Z","-X","-Y","-Z"]
-- The 2d x axis will map to the first given 3D axis, the 2d y axis will map to the second.
-- See CSG.OrthoNormalBasis.GetCartesian for details.
function CAG:extrudeInPlane(axis1, axis2, depth)
    return self.extrudeInOrthonormalBasis(CSG.OrthoNormalBasis.GetCartesian(axis1, axis2), depth);
end

function CAG:toCSG(height)
    if (#self.sides == 0) then
        -- empty!
        return CSG:new();
    end
    local normalVector = vector3d:new(0, 0, -1);
    local polygons = {};
    -- bottom and top
	polygons = tableext.concat(polygons,self:_toPlanePolygons({translation= {0, 0, 0},normalVector= normalVector, flipped = true}));
    polygons = tableext.concat(polygons,self:_toPlanePolygons({translation = {0, height, 0},normalVector = normalVector, flipped = false}));
	for k,side in ipairs(self.sides) do
		table.insert(polygons,side:toPolygon3D(0,height));
	end
	return CSG.fromPolygons(polygons);	
end

-- extruded=cag.extrude({offset: [0,0,10], twistangle: 360, twiststeps: 100});
-- linear extrusion of 2D shape, with optional twist
-- The 2d shape is placed in in y=0 plane and extruded into direction <offset> (a CSG.Vector3D)
-- The final face is rotated <twistangle> degrees. Rotation is done around the origin of the 2d shape (i.e. x=0, y=0)
-- twiststeps determines the resolution of the twist (should be >= 1)
-- returns a CSG object
function CAG:extrude(options)
    if (#self.sides == 0) then
        -- empty!
        return CSG:new();
    end
    local offsetVector = CSGFactory.parseOptionAs3DVector(options, "offset", {0, 1, 0});
    local twistangle = CSGFactory.parseOptionAsFloat(options, "twistangle", 0);
    local twiststeps = CSGFactory.parseOptionAsInt(options, "twiststeps", CSGFactory.defaultResolution3D);
    if (offsetVector[2] == 0) then
		LOG.std(nil, "error", "CAG:extrude", "offset cannot be orthogonal to Y axis");
		return nil;
    end
    if (twistangle == 0 or twiststeps < 1) then
        twiststeps = 1;
    end
    local normalVector = vector3d:new(0, 0, -1);

    local polygons = {};
    -- bottom and top
	polygons = tableext.concat(polygons,self:_toPlanePolygons({translation= {0, 0, 0},normalVector= normalVector, flipped = not (offsetVector[2] < 0)}));
    polygons = tableext.concat(polygons,self:_toPlanePolygons({translation = offsetVector,normalVector = normalVector * Matrix4.rotationY(twistangle + 180), flipped = (offsetVector[2] < 0)}));
    -- walls
	local i;
    for i = 0, twiststeps-1 ,1 do
        local c1 = CSGConnector:new():init(offsetVector:clone():MulByFloat(i / twiststeps), {0, offsetVector[2], 0},
            normalVector * Matrix4.rotationY(i * twistangle/twiststeps + 180));
        local c2 = CSGConnector:new():init(offsetVector:clone():MulByFloat((i + 1) / twiststeps), {0, offsetVector[2], 0},
            normalVector * Matrix4.rotationY((i + 1) * twistangle/twiststeps + 180));
		polygons = tableext.concat(polygons,self:_toWallPolygons({toConnector1 = c1, toConnector2 = c2}));
    end
    return CSG.fromPolygons(polygons);
end
--[[
    * extrude CAG to 3d object by rotating the origin around the y axis
    * (and turning everything into XY plane)
    * arguments: options dict with angle and resolution, both optional
    * --]]
function CAG:rotateExtrude(options)
    local alpha = CSGFactory.parseOptionAsFloat(options, "angle", 360);
    local resolution = CSGFactory.parseOptionAsInt(options, "resolution", CSGFactory.defaultResolution3D);

    local EPS = tonumber("1e-5");
	if(alpha > 360) then
		alpha = alpha % 360;
	end
    local origin = {0, 0, 0};
    local axisV = vector3d:new(0, 0, -1);
    local normalV = {0, 1, 0};
    local polygons = {};
    -- planes only needed if alpha > 0
    local connS = CSGConnector:new():init(origin, axisV, normalV);
    if (alpha > 0 and alpha < 360) then
        -- we need to rotate negative to satisfy wall function condition of
        -- building in the direction of axis vector
        local connE = CSGConnector:new():init(origin, axisV * Matrix4.rotationY(-alpha), normalV);
        polygons = tableext.concat(polygons,
            self:_toPlanePolygons({toConnector = connS, flipped = true}));
        polygons = tableext.concat(polygons,
            self:_toPlanePolygons({toConnector = connE}));
    end
    local connT1 = connS;
	local connT2;
    local step = alpha/resolution;
	local a;
    for a = step, alpha + EPS ,step do
        connT2 = CSGConnector:new():init(origin, axisV * Matrix4.rotationY(-a), normalV);
        polygons = tableext.concat(polygons,self:_toWallPolygons(
            {toConnector1 = connT1, toConnector2 = connT2}));
        connT1 = connT2;
    end
    return CSG.fromPolygons(polygons);
end

-- check if we are a valid CAG (for debugging)
-- NOTE(bebbi) uneven side count doesn't work because rounding with EPS isn't taken into account
function CAG:check()
    local EPS = tonumber("1e-5");
    local errors = {};
    if (self.isSelfIntersecting(true)) then
        table.insert(errors,"Self intersects");
    end
    local pointcount = {};
	for k,side in ipairs(self.sides) do
        function mappoint(p)
            local tag = p[1] .. " " .. p[2];
            if (pointcount[tag] == nil) then
				pointcount[tag] = 0;
			end
            pointcount[tag] = pointcount[tag] + 1;
        end
        mappoint(side.vertex0.pos);
        mappoint(side.vertex1.pos);
    end
    for tag,v in pairs(pointcount) do
        local count = pointcount[tag];
        if (mathlib.bit.band(count, 1)) then
            table.insert(errors,"Uneven number of sides (" .. count .. ") for point " .. tag);
        end
    end
    local area = self.area();
    if (area < EPS*EPS) then
        table.insert(errors,"Area is " .. area);
    end
    if (#errors > 0) then
        local ertxt = table.concat(errors,"\n");
        LOG.std(nil, "error", "CAG:check", ertxt);
		return false;
    end
	return true;
end
--[[
function CAG:getOutlinePaths()
    --local cag = self.canonicalized();
    local sideTagToSideMap = {};
    local startVertexTagToSideTagMap = {};
    for k,side in ipairs(self.sides) do
        local sidetag = side.getTag();
        sideTagToSideMap[sidetag] = side;
        local startvertextag = side.vertex0.getTag();
        if (startVertexTagToSideTagMap[startvertextag] == nil) then
            startVertexTagToSideTagMap[startvertextag] = {};
        end
        table.insert(startVertexTagToSideTagMap[startvertextag],sidetag);
    end
    local paths = {};
    while (true) do
        local startsidetag = nil;
        for (local aVertexTag in startVertexTagToSideTagMap)
            local sidesForThisVertex = startVertexTagToSideTagMap[aVertexTag];
            startsidetag = sidesForThisVertex[1];
            sidesForThisVertex.splice(0, 1);
            if (sidesForThisVertex.length === 0)
                delete startVertexTagToSideTagMap[aVertexTag];
            }
            break;
        }
        if (startsidetag === nil) break; -- we've had all sides
        local connectedVertexPoints = {};
        local sidetag = startsidetag;
        local thisside = sideTagToSideMap[sidetag];
        local startvertextag = thisside.vertex0.getTag();
        while (true)
            connectedVertexPoints.push(thisside.vertex0.pos);
            local nextvertextag = thisside.vertex1.getTag();
            if (nextvertextag == startvertextag) break; -- we've closed the polygon
            if (!(nextvertextag in startVertexTagToSideTagMap))
                throw new Error("Area is not closed!");
            }
            local nextpossiblesidetags = startVertexTagToSideTagMap[nextvertextag];
            local nextsideindex = -1;
            if (nextpossiblesidetags.length == 1)
                nextsideindex = 0;
            } else {
                -- more than one side starting at the same vertex. This means we have
                -- two shapes touching at the same corner
                local bestangle = nil;
                local thisangle = thisside.direction().angleDegrees();
                for (local sideindex = 0; sideindex < nextpossiblesidetags.length; sideindex++)
                    local nextpossiblesidetag = nextpossiblesidetags[sideindex];
                    local possibleside = sideTagToSideMap[nextpossiblesidetag];
                    local angle = possibleside.direction().angleDegrees();
                    local angledif = angle - thisangle;
                    if (angledif < -180) angledif += 360;
                    if (angledif >= 180) angledif -= 360;
                    if ((nextsideindex < 0) or (angledif > bestangle))
                        nextsideindex = sideindex;
                        bestangle = angledif;
                    }
                }
            }
            local nextsidetag = nextpossiblesidetags[nextsideindex];
            nextpossiblesidetags.splice(nextsideindex, 1);
            if (nextpossiblesidetags.length === 0)
                delete startVertexTagToSideTagMap[nextvertextag];
            }
            thisside = sideTagToSideMap[nextsidetag];
        } -- inner loop
        local path = new CSG.Path2D(connectedVertexPoints, true);
        paths.push(path);
    end -- outer loop
    return paths;
end

/*
cag = cag.overCutInsideCorners(cutterradius);

Using a CNC router it's impossible to cut out a true sharp inside corner. The inside corner
will be rounded due to the radius of the cutter. This function compensates for self by creating
an extra cutout at each inner corner so that the actual cut out shape will be at least as large
as needed.
*/
overCutInsideCorners(cutterradius)
    local cag = self.canonicalized();
    -- for each vertex determine the 'incoming' side and 'outgoing' side:
    local pointmap = {}; -- tag => {pos: coord, from: {}, to: {}}
    cag.sides.map(function(side)
        if (!(side.vertex0.getTag() in pointmap))
            pointmap[side.vertex0.getTag()] = {
                pos: side.vertex0.pos,
                from: {},
                to: {}
            };
        }
        pointmap[side.vertex0.getTag()].to.push(side.vertex1.pos);
        if (!(side.vertex1.getTag() in pointmap))
            pointmap[side.vertex1.getTag()] = {
                pos: side.vertex1.pos,
                from: {},
                to: {}
            };
        }
        pointmap[side.vertex1.getTag()].from.push(side.vertex0.pos);
    });
    -- overcut all sharp corners:
    local cutouts = {};
    for (local pointtag in pointmap)
        local pointobj = pointmap[pointtag];
        if ((pointobj.from.length == 1) and (pointobj.to.length == 1))
            -- ok, 1 incoming side and 1 outgoing side:
            local fromcoord = pointobj.from[1];
            local pointcoord = pointobj.pos;
            local tocoord = pointobj.to[1];
            local v1 = pointcoord:sub(fromcoord).unit();
            local v2 = tocoord:sub(pointcoord).unit();
            local crossproduct = v1:cross(v2);
            local isInnerCorner = (crossproduct < 0.001);
            if (isInnerCorner)
                -- yes it's a sharp corner:
                local alpha = v2.angleRadians() - v1.angleRadians() + Math.PI;
                if (alpha < 0)
                    alpha += 2 * Math.PI;
                } else if (alpha >= 2 * Math.PI)
                    alpha -= 2 * Math.PI;
                }
                local midvector = v2:sub(v1).unit();
                local circlesegmentangle = 30 / 180 * Math.PI; -- resolution of the circle: segments of 30 degrees
                -- we need to increase the radius slightly so that our imperfect circle will contain a perfect circle of cutterradius
                local radiuscorrected = cutterradius / Math.cos(circlesegmentangle / 2);
                local circlecenter = pointcoord:add(midvector:MulByFloat(radiuscorrected));
                -- we don't need to create a full circle; a pie is enough. Find the angles for the pie:
                local startangle = alpha + midvector.angleRadians();
                local deltaangle = 2 * (Math.PI - alpha);
                local numsteps = 2 * Math.ceil(deltaangle / circlesegmentangle / 2); -- should be even
                -- build the pie:
                local points = [circlecenter];
                for (local i = 0; i <= numsteps; i++)
                    local angle = startangle + i / numsteps * deltaangle;
                    local p = vector2d.fromAngleRadians(angle):MulByFloat(radiuscorrected):add(circlecenter);
                    points.push(p);
                }
                cutouts.push(CAG.fromPoints(points));
            }
        }
    }
    local result = cag.subtract(cutouts);
    return result;
}
--]]