local OmegaDice = _G.OmegaDice

-- Regular octahedron: 6 verts, 12 edges, 8 triangular faces
local verts = {
    { 1,  0,  0},  -- 1
    {-1,  0,  0},  -- 2
    { 0,  1,  0},  -- 3
    { 0, -1,  0},  -- 4
    { 0,  0,  1},  -- 5  (top)
    { 0,  0, -1},  -- 6  (bottom)
}

local edges = {
    {1,3},{1,4},{1,5},{1,6},
    {2,3},{2,4},{2,5},{2,6},
    {3,5},{3,6},{4,5},{4,6},
}

local faces = {
    {5,1,3}, {5,3,2}, {5,2,4}, {5,4,1},  -- upper (sharing top pole)
    {6,3,1}, {6,2,3}, {6,4,2}, {6,1,4},  -- lower (sharing bottom pole)
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

OmegaDice.D8Geometry = { sides=8, verts=verts, edges=edges, faces=faces, normals=normals }
