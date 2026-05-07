local OmegaDice = _G.OmegaDice

-- Regular dodecahedron: 20 verts, 30 edges, 12 pentagonal faces
-- Vertices: (±1,±1,±1), (0,±1/φ,±φ), (±1/φ,±φ,0), (±φ,0,±1/φ) — all normalised to unit sphere (÷√3)
local PHI = (1 + math.sqrt(5)) / 2
local S   = 1 / math.sqrt(3)           -- 1/√3
local SP  = PHI / math.sqrt(3)         -- φ/√3
local SI  = 1 / (PHI * math.sqrt(3))   -- 1/(φ√3)

local verts = {
    -- (±1, ±1, ±1) / √3
    { S,  S,  S},   -- 1
    { S,  S, -S},   -- 2
    { S, -S,  S},   -- 3
    { S, -S, -S},   -- 4
    {-S,  S,  S},   -- 5
    {-S,  S, -S},   -- 6
    {-S, -S,  S},   -- 7
    {-S, -S, -S},   -- 8
    -- (0, ±1/φ, ±φ) / √3
    { 0,  SI,  SP},  -- 9
    { 0,  SI, -SP},  -- 10
    { 0, -SI,  SP},  -- 11
    { 0, -SI, -SP},  -- 12
    -- (±1/φ, ±φ, 0) / √3
    { SI,  SP,  0},  -- 13
    { SI, -SP,  0},  -- 14
    {-SI,  SP,  0},  -- 15
    {-SI, -SP,  0},  -- 16
    -- (±φ, 0, ±1/φ) / √3
    { SP,  0,  SI},  -- 17
    { SP,  0, -SI},  -- 18
    {-SP,  0,  SI},  -- 19
    {-SP,  0, -SI},  -- 20
}

-- 30 edges (each vertex has degree 3)
local edges = {
    {1,9}, {1,13},{1,17},
    {2,10},{2,13},{2,18},
    {3,11},{3,14},{3,17},
    {4,12},{4,14},{4,18},
    {5,9}, {5,15},{5,19},
    {6,10},{6,15},{6,20},
    {7,11},{7,16},{7,19},
    {8,12},{8,16},{8,20},
    {9,11},{10,12},{13,15},{14,16},{17,18},{19,20},
}

-- 12 pentagonal faces (verified: each of the 30 edges appears in exactly 2 faces)
local faces = {
    { 1,  9, 11,  3, 17},   -- 1
    { 1, 17, 18,  2, 13},   -- 2
    { 1, 13, 15,  5,  9},   -- 3
    { 2, 10,  6, 15, 13},   -- 4
    { 2, 18,  4, 12, 10},   -- 5
    { 3, 11,  7, 16, 14},   -- 6
    { 3, 14,  4, 18, 17},   -- 7
    { 4, 14, 16,  8, 12},   -- 8
    { 5, 15,  6, 20, 19},   -- 9
    { 5,  9, 11,  7, 19},   -- 10
    { 6, 10, 12,  8, 20},   -- 11
    { 7, 16,  8, 20, 19},   -- 12
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

OmegaDice.D12Geometry = { sides=12, verts=verts, edges=edges, faces=faces, normals=normals }
