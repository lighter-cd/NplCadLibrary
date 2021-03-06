--[[
Title: CSGFactory
Author(s): leio
Date: 2016/10/24
Desc: This is a factory to create CSG object.
-------------------------------------------------------
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGFactory.lua");
local CSGFactory = commonlib.gettable("Mod.NplCadLibrary.csg.CSGFactory");
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/math/bit.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVector.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVertex.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGPlane.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGPolygon.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGBSPNode.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSG.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVector2D.lua");


local CSGVector = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVector");
local CSGVertex = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVertex");
local CSGPlane = commonlib.gettable("Mod.NplCadLibrary.csg.CSGPlane");
local CSGPolygon = commonlib.gettable("Mod.NplCadLibrary.csg.CSGPolygon");
local CSGBSPNode = commonlib.gettable("Mod.NplCadLibrary.csg.CSGBSPNode");
local CSG = commonlib.gettable("Mod.NplCadLibrary.csg.CSG");
local CSGVector2D = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVector2D");

local math_floor = math.floor;
local math_mod = math.mod;
local math_max = math.max;
local math_ceil = math.ceil;
local math_sin = math.sin;
local math_cos = math.cos;
local math_pi = 3.1415926;
local CSGFactory = commonlib.gettable("Mod.NplCadLibrary.csg.CSGFactory");
CSGFactory.defaultResolution2D = 32;
CSGFactory.defaultResolution3D = 12;
--[[
	// Construct an axis-aligned solid cuboid.
    // Parameters:
    //   center: center of cube (default {0,0,0})
    //   radius: radius of cube (default {1,1,1}), can be specified as scalar or as 3D vector
    //
    // Example code:
    //
    //     var cube = CSGFactory.cube({
    //       center: {0, 0, 0},
    //       radius: 1
    //     });
--]]
function CSGFactory.cube(options)
	options = options or {};
	if (options["corner1"] or options["corner2"]) then
        if (options["center"] or options["radius"]) then
			LOG.std(nil, "error", "CSGFactory.cube", "should either give a radius and center parameter, or a corner1 and corner2 parameter");
			return
        end
        corner1 = CSGFactory.parseOptionAs3DVector(options, "corner1", {0, 0, 0});
        corner2 = CSGFactory.parseOptionAs3DVector(options, "corner2", {1, 1, 1});
        c = corner1:plus(corner2):times(0.5);
        r = corner2:minus(corner1):times(0.5);
    else 
        c = CSGFactory.parseOptionAs3DVector(options, "center", {0, 0, 0});
        r = CSGFactory.parseOptionAs3DVector(options, "radius", {1, 1, 1});
    end

	local polygons = {};
	local data = {
		{{0, 4, 6, 2}, {-1, 0, 0}},
		{{1, 3, 7, 5}, {1, 0, 0}},
		{{0, 1, 5, 4}, {0, -1, 0}},
		{{2, 6, 7, 3}, {0, 1, 0}},
		{{0, 2, 3, 1}, {0, 0, -1}},
		{{4, 5, 7, 6}, {0, 0, 1}}
	};
	local function tmp(a,b)
		local value = mathlib.bit.band(a, b);
		if(value ~= 0)then
			return 1
		else
			return 0
		end
	end
	for k,info in ipairs(data) do
		local normal = CSGVector:new():init(info[2]);
		local vertices = {};
		for kk,vv in ipairs(info[1]) do
			local x = c[1] + r[1] * (2 * (tmp(vv, 1)) - 1);
			local y = c[2] + r[2] * (2 * (tmp(vv, 2)) - 1);
			local z = c[3] + r[3] * (2 * (tmp(vv, 4)) - 1);

			local pos = CSGVector:new():init(x,y,z);
			local vertex = CSGVertex:new():init(pos,normal);
			table.insert(vertices,vertex);
		end
		local polygon = CSGPolygon:new():init(vertices);
		table.insert(polygons,polygon);
	end
	
	return CSG.fromPolygons(polygons)
end
--[[
//	Construct a solid sphere
    //
    // Parameters:
    //   center: center of sphere (default {0,0,0})
    //   radius: radius of sphere (default 1), must be a scalar
    //   resolution: determines the number of polygons per 360 degree revolution (default 12)
    //
    // Example usage:
    //
    //     var sphere = CSGFactory.sphere({
    //       center = {0, 0, 0},
    //       radius = 2,
    //       slices = 16,
    //       stacks = 8,
    //     });
http://gamedev.stackexchange.com/questions/16585/how-do-you-programmatically-generate-a-sphere
--]]

function CSGFactory.sphere2(options)
	options = options or {};
	local c = CSGFactory.parseOptionAs3DVector(options, "center", {0, 0, 0});
    local r = CSGFactory.parseOptionAsFloat(options, "radius", 1);
    local slices = CSGFactory.parseOptionAsInt(options, "slices", 16);
    local stacks = CSGFactory.parseOptionAsInt(options, "stacks", 8);

	
	local polygons = {};
	local vertices;
	local function vertex(theta, phi) 
		theta = theta * math.pi * 2;
		phi = phi * math.pi;
		local sinPhi = math.sin(phi);
		local dir = CSGVector:new():init(
		  math.cos(theta) * sinPhi,
		  math.sin(theta) * sinPhi,
		  math.cos(phi)
		);
		table.insert(vertices,CSGVertex:new():init(c:plus(dir:times(r)), dir));
	end
	local i;
	local j;
	for i=0,slices-1 do
		for j=0,stacks-1 do
			vertices = {};
			vertex(i / slices, j / stacks);
			if (j > 0) then
				vertex((i + 1) / slices, j / stacks);
			end
			if (j < stacks - 1) then
				vertex((i + 1) / slices, (j + 1) / stacks);
			end
			vertex(i / slices, (j + 1) / stacks);
			table.insert(polygons,CSGPolygon:new():init(vertices));
		end
	end
	return CSG.fromPolygons(polygons);
end
--[[
//	Construct a solid sphere
    //
    // Parameters:
    //   center: center of sphere (default {0,0,0})
    //   radius: radius of sphere (default 1), must be a scalar
    //   resolution: determines the number of polygons per 360 degree revolution (default 12)
    //   axes: (optional) an array with 3 vectors for the x, y and z base vectors
    //
    // Example usage:
    //
    //     var sphere = CSGFactory.sphere({
    //       center: {0, 0, 0},
    //       radius: 2,
    //       resolution: 32,
    //     });

--]]
function CSGFactory.sphere(options)
        options = options or {};
        local center = CSGFactory.parseOptionAs3DVector(options, "center", {0, 0, 0});
        local radius = CSGFactory.parseOptionAsFloat(options, "radius", 1);
        local resolution = CSGFactory.parseOptionAsInt(options, "resolution", CSGFactory.defaultResolution3D);
        local xvector, yvector, zvector;
        if (options["axes"])then
            xvector = options.axes[1]:unit():timesInplace(radius);
            yvector = options.axes[2]:unit():timesInplace(radius);
            zvector = options.axes[3]:unit():timesInplace(radius);
        else
            xvector = CSGVector:new():init(1, 0, 0):timesInplace(radius);
            yvector = CSGVector:new():init(0, 1, 0):timesInplace(radius);
            zvector = CSGVector:new():init(0, 0, 1):timesInplace(radius);
        end
        if (resolution < 4) then
			resolution = 4;
		end
        local qresolution = math_ceil(resolution / 4);
        local prevcylinderpoint;
        local polygons = {};
		for slice1 = 0, resolution do
			local angle = math_pi * 2.0 * slice1 / resolution;
            local cylinderpoint = xvector:times(math_cos(angle)):plus(zvector:times(math_sin(angle)));
            if (slice1 > 0) then
                -- cylinder vertices:
                local vertices = {};
                local prevcospitch, prevsinpitch;
                for slice2 = 0, qresolution do
                    local pitch = 0.5 * math_pi * slice2 / qresolution;
                    local cospitch = math_cos(pitch);
                    local sinpitch = math_sin(pitch);
                    if (slice2 > 0) then
                        vertices = {};
						table.insert(vertices,CSGVertex:new():init(center:plus(prevcylinderpoint:times(prevcospitch):minus(yvector:times(prevsinpitch)))));
                        table.insert(vertices,CSGVertex:new():init(center:plus(cylinderpoint:times(prevcospitch):minus(yvector:times(prevsinpitch)))));
                        
                        if (slice2 < qresolution) then
                            table.insert(vertices,CSGVertex:new():init(center:plus(cylinderpoint:times(cospitch):minus(yvector:times(sinpitch)))));
                        end
                        table.insert(vertices,CSGVertex:new():init(center:plus(prevcylinderpoint:times(cospitch):minus(yvector:times(sinpitch)))));
						table.insert(polygons,CSGPolygon:new():init(vertices));
                        vertices = {};
                        table.insert(vertices,CSGVertex:new():init(center:plus(prevcylinderpoint:times(prevcospitch):plus(yvector:times(prevsinpitch)))));
                        table.insert(vertices,CSGVertex:new():init(center:plus(cylinderpoint:times(prevcospitch):plus(yvector:times(prevsinpitch)))));
                        if (slice2 < qresolution) then
                            table.insert(vertices,CSGVertex:new():init(center:plus(cylinderpoint:times(cospitch):plus(yvector:times(sinpitch)))));
                        end
                        table.insert(vertices,CSGVertex:new():init(center:plus(prevcylinderpoint:times(cospitch):plus(yvector:times(sinpitch)))));

						vertices = CSGFactory.reverseTable(vertices);
						table.insert(polygons,CSGPolygon:new():init(vertices));
                    end
                    prevcospitch = cospitch;
                    prevsinpitch = sinpitch;
                end
            end
            prevcylinderpoint = cylinderpoint;
		end
        
        local result = CSG.fromPolygons(polygons);
        return result;
end
--[[
	 Construct a solid cylinder.
    
     Parameters:
       start: start point of cylinder (default {0, -1, 0})
       end: end point of cylinder (default {0, 1, 0})
       radius: radius of cylinder (default 1), must be a scalar
       resolution: determines the number of polygons per 360 degree revolution (default 12)
    
     Example usage:
    
         var cylinder = CSGFactory.cylinder({
           from = {0, -1, 0},
           to = {0, 1, 0},
           radius = 1,
           resolution = 16
         });
--]]
-- added two params:"radiusStart" and "radiusEnd"
-- CSG.cylinder hasn't included these params.
function CSGFactory.cylinder(options)
	options = options or {};
	local s = CSGFactory.parseOptionAs3DVector(options, "from", {0, -1, 0});
    local e = CSGFactory.parseOptionAs3DVector(options, "to", {0, 1, 0});
    local r = CSGFactory.parseOptionAsFloat(options, "radius", 1);
    local radiusEnd = CSGFactory.parseOptionAsFloat(options, "radiusEnd", r);
    local radiusStart = CSGFactory.parseOptionAsFloat(options, "radiusStart", r);

	if(radiusStart < 0 or radiusEnd < 0)then
		LOG.std(nil, "error", "CSGFactory.cylinder", "Radius should be non-negative");
		return;
	end
	if(radiusStart == 0 and radiusEnd == 0)then
		LOG.std(nil, "error", "CSGFactory.cylinder", "Either radiusStart or radiusEnd should be positive");
		return;
	end
	local slices = CSGFactory.parseOptionAsInt(options, "resolution", CSGFactory.defaultResolution2D);
    local ray = e:minus(s);

	local axisZ = ray:unit()
	local isY = (math.abs(axisZ[2]) > 0.5);
	local isY_v1;
	local isY_v2;
	if(isY)then
		isY_v1 = 1;
		isY_v2 = 0;
	else
		isY_v1 = 0;
		isY_v2 = 1;
	end
	local axisX = CSGVector:new():init(isY_v1, isY_v2, 0):cross(axisZ):unit();
	local axisY = axisX:cross(axisZ):unit();
	local start_value = CSGVertex:new():init(s, axisZ:negated());
	local end_value = CSGVertex:new():init(e, axisZ:unit());
	local polygons = {};


	function point(stack, slice, radius,normalBlend)
		normalBlend = normalBlend or 0;
		local angle = slice * math.pi * 2;
		local out = axisX:times(math.cos(angle)):plus(axisY:times(math.sin(angle)));
		local pos = s:plus(ray:times(stack)):plus(out:times(radius));
		local normal = out:times(1 - math.abs(normalBlend)):plus(axisZ:times(normalBlend));
		return CSGVertex:new():init(pos, normal);
	end
	local i;
	for i = 0,slices-1 do
		local t0 = i / slices;
		local t1 = (i + 1) / slices;
		if(radiusStart == radiusEnd)then
			table.insert(polygons,CSGPolygon:new():init({start_value:clone(true), point(0, t0, radiusEnd, -1), point(0, t1, radiusEnd, -1)}));
			table.insert(polygons,CSGPolygon:new():init({point(0, t1, radiusEnd), point(0, t0, radiusEnd, 0), point(1, t0, radiusEnd, 0), point(1, t1, radiusEnd, 0)}));
			table.insert(polygons,CSGPolygon:new():init({end_value:clone(true), point(1, t1, radiusEnd, 1), point(1, t0, radiusEnd, 1)}));
		else
			if(radiusStart > 0)then
				table.insert(polygons,CSGPolygon:new():init({start_value:clone(true), point(0, t0, radiusStart, -1), point(0, t1, radiusStart, -1)}));
				table.insert(polygons,CSGPolygon:new():init({point(0, t0, radiusStart), point(1, t0, radiusEnd, 0), point(0, t1, radiusStart, 0)}));
			end
			if(radiusEnd > 0)then
				table.insert(polygons,CSGPolygon:new():init({end_value:clone(true), point(1, t1, radiusEnd, 0), point(1, t0, radiusEnd, 0)}));
				table.insert(polygons,CSGPolygon:new():init({point(1, t0, radiusEnd, 1), point(1, t1, radiusEnd, 1), point(0, t1, radiusStart, 1)}));
			end
		end
		
	end
  return CSG.fromPolygons(polygons);
end
--[[
	// Construct an axis-aligned solid rounded cuboid.
    // Parameters:
    //   center: center of cube (default [0,0,0])
    //   radius: radius of cube (default [1,1,1]), can be specified as scalar or as 3D vector
    //   roundradius: radius of rounded corners (default 0.2), must be a scalar
    //   resolution: determines the number of polygons per 360 degree revolution (default 8)
    //
    // Example code:
    //
    //     var cube = CSG.roundedCube({
    //       center = {0, 0, 0},
    //       radius = 1,
    //       roundradius = 0.2,
    //       resolution = 8,
    //     });
--]]
function CSGFactory.roundedCube(options)
		local EPS = tonumber("1e-5");
        local minRR = tonumber("1e-2"); --minroundradius 1e-3 gives rounding errors already
        local center, cuberadius;

        options = options or {};
		if(options["corner1"] or options["corner2"])then
			if(options["center"] or options["radius"])then
				LOG.std(nil, "warning", "CSGFactory", "roundedCube: should either give a radius and center parameter, or a corner1 and corner2 parameter");
				return
			end
			corner1 = CSGFactory.parseOptionAs3DVector(options, "corner1", {0, 0, 0});
            corner2 = CSGFactory.parseOptionAs3DVector(options, "corner2", {1, 1, 1});
            center = corner1:plus(corner2):times(0.5);
            cuberadius = corner2:minus(corner1):times(0.5);
		else
			center = CSGFactory.parseOptionAs3DVector(options, "center", {0, 0, 0});
            cuberadius = CSGFactory.parseOptionAs3DVector(options, "radius", {1, 1, 1});
		end
        
        cuberadius = cuberadius:abs(); -- negative radii make no sense
        local resolution = CSGFactory.parseOptionAsInt(options, "resolution", CSGFactory.defaultResolution3D);
        if (resolution < 4)then
			resolution = 4;
		end
        if (math_mod(resolution,2) == 1 and resolution < 8)then
			resolution = 8; -- avoid ugly
		end
        local roundradius = CSGFactory.parseOptionAs3DVector(options, "roundradius", {0.2, 0.2, 0.2});
        -- slight hack for now - total radius stays ok
        roundradius = CSGVector:new():init(math_max(roundradius[1], minRR), math_max(roundradius[2], minRR), math_max(roundradius[3], minRR));
        local innerradius = cuberadius:minus(roundradius);
        if (innerradius[1] < 0 or innerradius[2] < 0 or innerradius[3] < 0)then
			LOG.std(nil, "error", "CSGFactory.roundedCube", "roundradius <= radius!");
			return
        end
        local res = CSGFactory.sphere({radius = 1, resolution = resolution});
        --res = res:scale(roundradius);
        --innerradius[1] > EPS && (res = res.stretchAtPlane([1, 0, 0], [0, 0, 0], 2*innerradius[1]));
        --innerradius[2] > EPS && (res = res.stretchAtPlane([0, 1, 0], [0, 0, 0], 2*innerradius[2]));
        --innerradius[3] > EPS && (res = res.stretchAtPlane([0, 0, 1], [0, 0, 0], 2*innerradius[3]));
        --res = res.translate([-innerradius[1]+center[1], -innerradius[2]+center[2], -innerradius[3]+center[3]]);
        --res = res.reTesselated();
        --res.properties.roundedCube = new CSG.Properties();
        --res.properties.roundedCube.center = new CSG.Vertex(center);
        --res.properties.roundedCube.facecenters = [
            --new CSG.Connector(new CSG.Vector3D([cuberadius[1], 0, 0]).plus(center), [1, 0, 0], [0, 0, 1]),
            --new CSG.Connector(new CSG.Vector3D([-cuberadius[1], 0, 0]).plus(center), [-1, 0, 0], [0, 0, 1]),
            --new CSG.Connector(new CSG.Vector3D([0, cuberadius[2], 0]).plus(center), [0, 1, 0], [0, 0, 1]),
            --new CSG.Connector(new CSG.Vector3D([0, -cuberadius[2], 0]).plus(center), [0, -1, 0], [0, 0, 1]),
            --new CSG.Connector(new CSG.Vector3D([0, 0, cuberadius[3]]).plus(center), [0, 0, 1], [1, 0, 0]),
            --new CSG.Connector(new CSG.Vector3D([0, 0, -cuberadius[3]]).plus(center), [0, 0, -1], [1, 0, 0])
        --];
        return res;

end

--[[
	polyhedron accepts openscad style arguments. I.e. define face vertices clockwise looking from outside
     Parameters:
       points: points list for this polyhedron
       polygons or triangles: triangles list for this polyhedron
--]]

function CSGFactory.polyhedron(options)
        options = options or {};

        if (options.points == nil) then
			local errorMessage = "polyhedron needs 'points' arrays";
			LOG.std(nil, "error", "CSGFactory.polyhedron", errorMessage);
			error(errorMessage);
        end

		if ((options.polygons or options.triangles) == nil) then
			local errorMessage = "polyhedron needs 'polygons' or 'triangles' arrays";
			LOG.std(nil, "error", "CSGFactory.polyhedron", errorMessage);
			error(errorMessage);
		end
        
		local polyField = "triangles";
		if(options.triangles == nil) then
			polyField = polygons;
		end

		local points = CSGFactory.parseOptionAs3DVectorList(options, "points", {
                {1, 1, 0},
                {1, -1, 0},
                {-1, -1, 0},
                {-1, 1, 0},
                {0, 0, 1}
            });
		local vertices = {};
		for _,pt in ipairs(points) do
			table.insert(vertices,CSGVertex:new():init(pt));
		end

        local polys = CSGFactory.parseOption(options, polyField, {
                {0, 1, 4},
                {1, 2, 4},
                {2, 3, 4},
                {3, 0, 4},
                {1, 0, 3},
                {2, 1, 3}
            });

		local polygons ={};
        -- openscad convention defines inward normals - so we have to invert here
		for kf,face in ipairs(polys) do
			face = CSGFactory.reverseTable(face);
			local vs = {};
			for _,index in ipairs(face) do
				table.insert(vs,vertices[index+1]);
			end
			table.insert(polygons,CSGPolygon:new():init(vs));
		end


        -- TODO: facecenters as connectors? probably overkill. Maybe centroid
        -- the re-tesselation here happens because it's so easy for a user to
        -- create parametrized polyhedrons that end up with 1-2 dimensional polygons.
        -- These will create infinite loops at CSG.Tree()
        return CSG.fromPolygons(polygons);	
end


-- Parse an option from the options object
-- If the option is not present, return the default value
function CSGFactory.parseOption(options, optionname, defaultvalue)
	local result = defaultvalue;
    if (options) then
        if (options[optionname]) then
            result = options[optionname];
        end
    end
    return result;
end
-- Parse an option and force into a CSG.Vector3D. If a scalar is passed it is converted into a vector with equal x,y,z
function CSGFactory.parseOptionAs3DVector(options, optionname, defaultvalue)
	local result = CSGFactory.parseOption(options, optionname, defaultvalue);
    result = CSGVector:new():init(result);
    return result;
end
function CSGFactory.parseOptionAsFloat(options, optionname, defaultvalue)
        local result = CSGFactory.parseOption(options, optionname, defaultvalue);
        if (type(result) == "string") then
            result = tonumber(result);
        end
        if (not result or type(result) ~= "number") then
			LOG.std(nil, "error", "CSGFactory.parseOptionAsFloat", "Parameter %s should be a number",optionname);
        end
        return result;
end
function CSGFactory.parseOptionAsInt(options, optionname, defaultvalue)
        local result = CSGFactory.parseOption(options, optionname, defaultvalue);
        result = tonumber(math_floor(result));
        if (not result) then
			LOG.std(nil, "error", "CSGFactory.parseOptionAsInt", "Parameter %s should be a number",optionname);
        end
        return result;
end

function CSGFactory.parseOptionAsBool(options, optionname, defaultvalue)
        local result = CSGFactory.parseOption(options, optionname, defaultvalue);
        if (type(result) == "string") then
            if (result == "true")then
				result = true;
            elseif (result == "false")then
				result = false;
            elseif(result == 0)then
				result = false;
			end
        end
        result = not (not result);
        return result;
end
function CSGFactory.reverseTable(list)
	if(not list)then
		return
	end
	local result = {};
	local len = #list;
	while(len > 0) do
		table.insert(result,list[len]);
		len = len - 1
	end
	return result;
end


function CSGFactory.parseOptionAs2DVector(options, optionname, defaultvalue)
	local result = CSGFactory.parseOption(options, optionname, defaultvalue);
    result = CSGVector2D:new():init(result);
    return result;
end

function CSGFactory.parseOptionAs3DVectorList(options, optionname, defaultvalue)
	local result = CSGFactory.parseOption(options, optionname, defaultvalue);
	local list = {};
	for _,v in ipairs(result) do
		table.insert(list,CSGVector:new():init(v));
	end
	return list;
end