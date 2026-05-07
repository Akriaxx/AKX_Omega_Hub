local OmegaDice = _G.OmegaDice

local S2 = math.sqrt(2)
local S6 = math.sqrt(6)

local verts = {
    {  0,        0,      1    },   -- 1 apex top
    {  2*S2/3,   0,     -1/3  },   -- 2
    { -S2/3,     S6/3,  -1/3  },   -- 3
    { -S2/3,    -S6/3,  -1/3  },   -- 4
}

local edges = {
    {1,2},{1,3},{1,4},
    {2,3},{2,4},{3,4},
}

local faces = {
    {1,2,3}, {1,3,4}, {1,4,2}, {2,4,3},
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

OmegaDice.D4Geometry = { sides=4, verts=verts, edges=edges, faces=faces, normals=normals }
