local OmegaDice = _G.OmegaDice

local PHI  = (1 + math.sqrt(5)) / 2
local NORM = math.sqrt(1 + PHI * PHI)

local verts = {
    {     0,  1/NORM,  PHI/NORM }, {     0, -1/NORM,  PHI/NORM },
    {     0,  1/NORM, -PHI/NORM }, {     0, -1/NORM, -PHI/NORM },
    { 1/NORM,  PHI/NORM,      0 }, {-1/NORM,  PHI/NORM,      0 },
    { 1/NORM, -PHI/NORM,      0 }, {-1/NORM, -PHI/NORM,      0 },
    { PHI/NORM,      0,  1/NORM }, {-PHI/NORM,      0,  1/NORM },
    { PHI/NORM,      0, -1/NORM }, {-PHI/NORM,      0, -1/NORM },
}

local edges = {
    {1,2},{1,5},{1,6},{1,9},{1,10},{2,7},{2,8},{2,9},{2,10},{3,4},
    {3,5},{3,6},{3,11},{3,12},{4,7},{4,8},{4,11},{4,12},{5,6},{5,9},
    {5,11},{6,10},{6,12},{7,8},{7,9},{7,11},{8,10},{8,12},{9,11},{10,12},
}

local faces = {
    {1,2,9},  {1,2,10}, {1,5,6},  {1,5,9},  {1,6,10},
    {2,7,8},  {2,7,9},  {2,8,10}, {3,4,11}, {3,4,12},
    {3,5,6},  {3,5,11}, {3,6,12}, {4,7,8},  {4,7,11},
    {4,8,12}, {5,9,11}, {6,10,12},{7,9,11},  {8,10,12},
}

local normals = {}
for i, face in ipairs(faces) do
    local va, vb, vc = verts[face[1]], verts[face[2]], verts[face[3]]
    local nx = (vb[2]-va[2])*(vc[3]-va[3]) - (vb[3]-va[3])*(vc[2]-va[2])
    local ny = (vb[3]-va[3])*(vc[1]-va[1]) - (vb[1]-va[1])*(vc[3]-va[3])
    local nz = (vb[1]-va[1])*(vc[2]-va[2]) - (vb[2]-va[2])*(vc[1]-va[1])
    local len = math.sqrt(nx*nx + ny*ny + nz*nz)
    nx, ny, nz = nx/len, ny/len, nz/len
    local cf = {(va[1]+vb[1]+vc[1])/3, (va[2]+vb[2]+vc[2])/3, (va[3]+vb[3]+vc[3])/3}
    if nx*cf[1] + ny*cf[2] + nz*cf[3] < 0 then nx,ny,nz = -nx,-ny,-nz end
    normals[i] = {nx, ny, nz}
end

OmegaDice.D20Geometry = { sides=20, verts=verts, edges=edges, faces=faces, normals=normals }
