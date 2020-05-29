-- dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
-- dofile "$SURVIVAL_DATA/Scripts/game/survival_items.lua"
-- dofile "$SURVIVAL_DATA/Scripts/game/survival_survivalobjects.lua"
-- dofile( "$CHALLENGE_DATA/Scripts/challenge/game_util.lua" )

Printer = class()

function Printer.client_onCreate( self )
	self:cl_init()
end

function Printer.client_onRefresh( self )
	self:cl_init()
end

function Printer.cl_init( self )
	self.cl = {}
end

function Printer.sv_importCreation( self, params )
	sm.creation.importFromFile( params.world, "$SURVIVAL_DATA/Scripts/game/ren/blueprints/"..params.name..".blueprint", params.position )
	self.shape:destroyShape()
end

function Printer.client_onInteract( self, character, state )
	if state == true then
		-- local resolvedBlueprintPath = {}
		-- resolvedBlueprintPath[#resolvedBlueprintPath+1] =  sm.json.open( "$SURVIVAL_DATA/Scripts/game/ren/blueprints/"..self.shape.id..".blueprint" )
		-- local usedShapes = {}
		-- usedShapes = getCreationsShapeCount( resolvedBlueprintPath )
		local importParams = {
			world = sm.localPlayer.getPlayer().character:getWorld(),
			name = self.shape.id,
			position = self.shape.worldPosition
		}
		
		self.network:sendToServer( "sv_importCreation", importParams )
		
	end
end