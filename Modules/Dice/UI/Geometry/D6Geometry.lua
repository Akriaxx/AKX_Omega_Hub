local OmegaDice = _G.OmegaDice

local S = 1 / math.sqrt(3)  -- normalize cube vertices to unit sphere

local verts = {
    {-S, -S, -S},  -- 1
    { S, -S, -S},  -- 2
    { S,  S, -S},  -- 3
    {-S,  S, -S},  -- 4
    {-S, -S,  S},  -- 5
    { S, -S,  S},  -- 6
    { S,  S,  S},  -- 7
    {-S,  S,  S},  -- 8
}

local edges = {
    {1,2},{2,3},{3,4},{4,1},   -- bottom ring
    {5,6},{6,7},{7,8},{8,5},   -- top ring
    {1,5},{2,6},{3,7},{4,8},   -- verticals
}

-- Quad faces (4 vertices each). Numbers 1-6 assigned to faces here.
local faces = {
    {1,4,3,2},   -- 1: bottom  (-Z)
    {5,6,7,8},   -- 2: top     (+Z)
    {1,2,6,5},   -- 3: front   (-Y)
    {3,4,8,7},   -- 4: back    (+Y)
    {1,5,8,4},   -- 5: left    (-X)
    {2,3,7,6},   -- 6: right   (+X)
}

local normals = {}
for i, face in ipairs(faces) do
    local va, vb, vc = verts[face[1]], verts[face[2]], verts[face[3]]
    local nx = (vb[2]-va[2])*(vc[3]-va[3]) - (vb[3]-va[3])*(vc[2]-va[2])
    local ny = (vb[3]-va[3])*(vc[1]-va[1]) - (vb[1]-va[1])*(vc[3]-va[3])
    local nz = (vb[1]-va[1])*(vc[2]-va[2]) - (vb[2]-va[2])*(vc[1]-va[1])
    local len = math.sqrt(nx*nx + ny*ny + nz*nz)
    nx, ny, nz = nx/len, ny/len, nz/len
    local cfx, cfy, cfz = 0, 0, 0
    for _, vi in ipairs(face) do cfx=cfx+verts[vi][1]; cfy=cfy+verts[vi][2]; cfz=cfz+verts[vi][3] end
    local nv = #face
    if nx*(cfx/nv) + ny*(cfy/nv) + nz*(cfz/nv) < 0 then nx,ny,nz = -nx,-ny,-nz end
    normals[i] = {nx, ny, nz}
end

OmegaDice.D6Geometry = { sides=6, verts=verts, edges=edges, faces=faces, normals=normals }
