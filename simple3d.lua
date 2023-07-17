-- title:   BTCO Simple3d Lua Script Updated
-- author:  BTCO
-- desc:    An updated version of the simple3d.lua script btco used in their ticgeo3d project.
-- site:    https://github.com/btco/ticgeo3d/blob/95252ebc4a37db63d37e5f86c050106e1d829149/simpl3d.lua
-- license: MIT License (change this to your license of choice)
-- version: 0.1
-- script:  lua

local elapse = 30

local G={
 ex=0, ey=25, ez=100, yaw=0,
}

function Boot()
 S3Init()

 S3WallAdd({lx=0,lz=0,rx=50,rz=0,tid=1})
 S3WallAdd({lx=50,lz=0,rx=50,rz=-50,tid=3})
 S3WallAdd({lx=50,lz=-50,rx=0,rz=-50,tid=5})
 S3WallAdd({lx=0,lz=-50,rx=0,rz=0,tid=7})

 S3WallAdd({lx=100,lz=0,rx=150,rz=0,tid=1})
 S3WallAdd({lx=150,lz=0,rx=150,rz=-50,tid=3})
 S3WallAdd({lx=150,lz=-50,rx=100,rz=-50,tid=5})
 S3WallAdd({lx=100,lz=-50,rx=100,rz=0,tid=7})
end

function TIC()
 if elapse > 0 then
  cls(2)
  local fwd=btn(0) and 1 or btn(1) and -1 or 0
  local right=btn(2) and -1 or btn(3) and 1 or 0
  G.ex=G.ex-math.sin(G.yaw)*fwd*2.0
  G.ez=G.ez-math.cos(G.yaw)*fwd*2.0
  if btn(4) then
    -- strafe
    G.ex=G.ex-math.sin(G.yaw-1.5708)*right*2.0
    G.ez=G.ez-math.cos(G.yaw-1.5708)*right*2.0
  else
    G.yaw=G.yaw-right*0.03
  end
  S3SetCam(G.ex,G.ey,G.ez,G.yaw)
  S3Rend()
  elapse  = elapse - 1
 end
end

---------------------------------------------------

local S={
 ex=0, ey=0, ez=0, yaw=0,
 -- Precomputed from ex,ey,ez,yaw:
 cosMy=0, sinMy=0, termA=0, termB=0,
 -- These are hard-coded into the projection function,
 -- so if you change then, also update the math.
 NCLIP=0.1,
 FCLIP=1000,
 -- min world Y coord of all walls
 W_BOT_Y=0,
 -- max world Y coord of all walls
 W_TOP_Y=50,
 -- list of all walls, each with
 --
 --  lx,lz,rx,rz: x,z coords of left and right endpts
 --  in world coords (y coord is auto, goes from
 --  W_BOT_Y to W_TOP_Y)
 --  tid: texture ID
 --
 --  Computed at render time:
 --   slx,slz,slty,slby: screen space coords of
 --     left side of wall (x, z, top y, bottom y)
 --   srx,srz,srty,srby: screen space coords of
 --     right side of wall (x, z, top y, bottom y)
 walls={},
 -- H-Buffer, used at render time:
 hbuf={},
}

local sin,cos,PI=math.sin,math.cos,math.pi
local floor,ceil=math.floor,math.ceil
local min,max,abs,HUGE=math.min,math.max,math.abs,math.huge
local SCRW=240
local SCRH=136

function S3Init()
 S3SetCam(0,0,0,0)
end

function S3WallAdd(w)
 table.insert(S.walls,{lx=w.lx,lz=w.lz,rx=w.rx,
   rz=w.rz,tid=w.tid})
end

function S3SetCam(ex,ey,ez,yaw)
 S.ex,S.ey,S.ez,S.yaw=ex,ey,ez,yaw
 -- Precompute some factors we will need often:
 S.cosMy,S.sinMy=cos(-yaw),sin(-yaw)
 S.termA=-ex*S.cosMy-ez*S.sinMy
 S.termB=ex*S.sinMy-ez*S.cosMy
end

function S3Proj(x,y,z)
 local c,s,a,b=S.cosMy,S.sinMy,S.termA,S.termB
 -- Hard-coded from manual matrix calculations:
 local px=0.9815*c*x+0.9815*s*z+0.9815*a
 local py=1.7321*y-1.7321*S.ey
 local pz=s*x-z*c-b-0.2
 local pw=x*s-z*c-b
 local ndcx=px/pw
 local ndcy=py/pw
 return 120+ndcx*120,68-ndcy*68,pz
end

function S3Rend()
 -- TODO: compute potentially visible set instead.
 local pvs=S.walls
 local hbuf=S.hbuf
 -- For an explanation of the rendering, see: https://docs.google.com/document/d/1do-iPbUHS2RF-lJAkPX98MsT9ZK5d5sBaJmekU1bZQU/edit#bookmark=id.7tkdwb6fk7e2
 _PrepHbuf(hbuf,pvs)
 _RendHbuf(hbuf)
end

function _S3ResetHbuf(hbuf)
 local scrw,scrh=SCRW,SCRH
 for x=0,scrw-1 do
  -- hbuf is 1-indexed (because Lua)
  hbuf[x+1]=hbuf[x+1] or {}
  local b=hbuf[x+1]
  b.wall=nil
  b.z=HUGE
 end
end

-- Compute screen-space coords for wall.
function _S3ProjWall(w)
 local topy=S.W_TOP_Y
 local boty=S.W_BOT_Y

 -- notation: lt=left top, rt=right top, etc.
 local ltx,lty,ltz=S3Proj(w.lx,topy,w.lz)
 local rtx,rty,rtz=S3Proj(w.rx,topy,w.rz)
 if rtx<=ltx then return false end  -- cull back side
 if rtx<0 or ltx>=SCRW then return false end
 local lbx,lby,lbz=S3Proj(w.lx,boty,w.lz)
 local rbx,rby,rbz=S3Proj(w.rx,boty,w.rz)

 w.slx,w.slz,w.slty,w.slby=ltx,ltz,lty,lby
 w.srx,w.srz,w.srty,w.srby=rtx,rtz,rty,rby

 -- TODO: fix aggressive clipping
 if w.slz<S.NCLIP or w.srz<S.NCLIP
   then return false end
 if w.slz>S.FCLIP or w.srz>S.FCLIP
   then return false end
 return true
end

function _PrepHbuf(hbuf,walls)
 _S3ResetHbuf(hbuf)
 for i=1,#walls do
  local w=walls[i]
  if _S3ProjWall(w) then _AddWallToHbuf(hbuf,w) end
 end
 -- Now hbuf has info about all the walls that we have
 -- to draw, per screen X coordinate.
 -- Fill in the top and bottom y coord per column as
 -- well.
 for x=0,SCRW-1 do
  local hb=hbuf[x+1] -- hbuf is 1-indexed
  if hb.wall then
   local w=hb.wall
   hb.ty=_S3Interp(w.slx,w.slty,w.srx,w.srty,x)
   hb.by=_S3Interp(w.slx,w.slby,w.srx,w.srby,x)
   trace(_S3Interp(w.slx,w.slby,w.srx,w.srby,x))
  end
 end
end

function _AddWallToHbuf(hbuf,w)
 local startx=max(0,S3Round(w.slx))
 local endx=min(SCRW-1,S3Round(w.srx))
 for x=startx,endx do
  -- hbuf is 1-indexed (because Lua)
  local hbx=hbuf[x+1]
  local z=_S3Interp(w.slx,w.slz,w.srx,w.srz,x)
  if hbx.z>z then  -- depth test.
   hbx.z,hbx.wall=z,w  -- write new depth.
  end
 end
end

function _RendHbuf(hbuf)
 local scrw=SCRW
 for x=0,scrw-1 do
  local hb=hbuf[x+1]  -- hbuf is 1-indexed
  local w=hb.wall
  if w then
   local u=_S3PerspTexU(w.slx,w.slz,w.srx,w.srz,x)
   _RendTexCol(w.tid,x,hb.ty,hb.by,u)
  end
 end
end

-- Renders a vertical column of a texture to
-- the screen given:
--   tid: texture ID
--   x: x coordinate
--   ty,by: top and bottom y coordinate.
--   u: horizontal texture coordinate (0 to 1)
function _RendTexCol(tid,x,ty,by,u)
 line(x,ty,x,by,tid)
 local aty,aby=max(ty,0),min(by,SCRH-1)
 for y=aty,aby do
  -- affine texture mapping for the v coord is ok,
  -- since walls are never slanted.
  local v=_S3Interp(ty,0,by,1,y)
  pix(x,y,_S3TexSamp(tid,u,v))
 end
end

function _S3PerspTexU(lx,lz,rx,rz,x)
 local a=_S3Interp(lx,0,rx,1,x)
 -- perspective-correct texture mapping
 return (a/((1-a)/lz+a/rz))/rz
end

function S3Round(x) return floor(x+0.5) end

function _S3Interp(x1,y1,x2,y2,x)
 if x2<x1 then
  x1,x2=x2,x1
  y1,y2=y2,y1
 end
 trace("Unknown A")
 trace(tostring(x<=x1 and y1))
 trace("Unknown B")
 trace(tostring(x>=x2 and y2))
 trace("Unknown C")
 trace(tostring((y1 + (y2-y1) * (x-x1) / (x2-x1))))
 return x<=x1 and y1 or (x>=x2 and y2 or
   (y1+(y2-y1)*(x-x1)/(x2-x1)))
end

-- Sample texture ID tid at texture coords u,v.
-- The texture ID is just the sprite ID where
-- the texture begins in sprite memory.
function _S3TexSamp(tid,u,v)
 -- texture size in pixels
 -- TODO make this variable
 local SX=16
 local SY=16
 local tx=S3Round(u*SX)%SX
 local ty=S3Round(v*SY)%SY
 local spid=tid+(ty//8)*16+(tx//8)
 tx=tx%8
 ty=ty%8
 return peek4(0x8000+spid*64+ty*8+tx)
end


--------------------------------------------------
Boot()


-- <TILES>
-- 001:eccccccccc888888caaaaaaaca888888cacccccccacc0ccccacc0ccccacc0ccc
-- 002:ccccceee8888cceeaaaa0cee888a0ceeccca0ccc0cca0c0c0cca0c0c0cca0c0c
-- 003:eccccccccc888888caaaaaaaca888888cacccccccacccccccacc0ccccacc0ccc
-- 004:ccccceee8888cceeaaaa0cee888a0ceeccca0cccccca0c0c0cca0c0c0cca0c0c
-- 005:3333333333333333333333333333333333333333333333333333333333333333
-- 006:3333333333333333333333333333333333333333333333333333333333333333
-- 007:4444444444444444444444444444444444444444444444444444444444444444
-- 008:4444444444444444444444444444444444444444444444444444444444444444
-- 009:5555555555555555555555555555555555555555555555555555555555555555
-- 010:5555555555555555555555555555555555555555555555555555555555555555
-- 017:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 018:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- 019:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 020:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- 021:3333333333333333333333333333333333333333333333333333333333333333
-- 022:3333333333333333333333333333333333333333333333333333333333333333
-- 023:4444444444444444444444444444444444444444444444444444444444444444
-- 024:4444444444444444444444444444444444444444444444444444444444444444
-- 025:5555555555555555555555555555555555555555555555555555555555555555
-- 026:5555555555555555555555555555555555555555555555555555555555555555
-- </TILES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <TRACKS>
-- 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </TRACKS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

