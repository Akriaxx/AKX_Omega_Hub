OmegaDice={}
for _,s in ipairs({4,6,8,10,12,20,100}) do dofile('Modules/Dice/UI/Geometry/D'..s..'Geometry.lua') end
local function json(v)
    if type(v)=='number' then return tostring(v) end
    local out={}
    for _,x in ipairs(v) do out[#out+1]=json(x) end
    return '['..table.concat(out,',')..']'
end
local out={}
for _,s in ipairs({4,6,8,10,12,20,100}) do
    local g=OmegaDice['D'..s..'Geometry']
    out[#out+1]='"'..s..'":{"verts":'..json(g.verts)..',"faces":'..json(g.meshFaces or g.faces)..'}'
end
print('{'..table.concat(out,',')..'}')
