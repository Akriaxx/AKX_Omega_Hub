local OmegaDice = _G.OmegaDice

local PI = math.pi

-- Pentagonal bipyramid: top (1), bottom (2), equatorial ring (3-7)
local verts = { {0,0,1}, {0,0,-1} }
for k = 0, 4 do
    local a = k * 2 * PI / 5
    verts[3+k] = { math.cos(a), math.sin(a), 0 }
end

local edges = {
    {1,3},{1,4},{1,5},{1,6},{1,7},   -- top to equatorial
    {2,3},{2,4},{2,5},{2,6},{2,7},   -- bottom to equatorial
    {3,4},{4,5},{5,6},{6,7},{7,3},   -- equatorial ring
}

-- 10 triangular faces: 5 upper + 5 lower
local faces = {
    {1,3,4}, {1,4,5}, {1,5,6}, {1,6,7}, {1,7,3},   -- upper
    {2,4,3}, {2,5,4}, {2,6,5}, {2,7,6}, {2,3,7},   -- lower
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

OmegaDice.D10Geometry = { sides=10, verts=verts, edges=edges, faces=faces, normals=normals }
