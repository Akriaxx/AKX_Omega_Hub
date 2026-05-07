local OmegaDice = _G.OmegaDice

-- Zocchihedron (D100): visually approximated as an icosahedron (sphere-like).
-- 100 face normals distributed via Fibonacci sphere for correct landing orientation.
-- Face labels are suppressed during roll (too many to display on a 20-face mesh).

local d20 = OmegaDice.D20Geometry   -- already loaded; reuse its mesh

-- 100 outward normals evenly distributed on the sphere (golden-angle Fibonacci lattice)
local normals = {}
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
for i = 1, 100 do
    local y     = 1 - (2 * i - 1) / 100    -- maps i=1..100 to y ≈ 0.99 .. -0.99
    local r     = math.sqrt(math.max(0, 1 - y * y))
    local theta = GOLDEN_ANGLE * (i - 1)
    normals[i]  = { r * math.cos(theta), y, r * math.sin(theta) }
end

OmegaDice.D100Geometry = {
    sides       = 100,
    verts       = d20.verts,       -- icosahedron vertices (for edge rendering)
    edges       = d20.edges,       -- icosahedron edges    (looks like a sphere)
    faces       = {},              -- empty → no face labels shown during roll
    normals     = normals,         -- 100 Fibonacci normals for landing targeting
    meshFaces   = d20.faces,       -- icosahedron faces for edge-visibility culling
    meshNormals = d20.normals,     -- icosahedron normals for edge-visibility culling
}
