dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

PrinterTool = class()

function PrinterTool.client_onCreate( self )
    self.effect = sm.effect.createEffect( "ShapeRenderable" )
	self.effect:setParameter( "uuid", sm.uuid.new("d4e6c84c-a493-44b1-81aa-4f4741ea3ed8") )
	self.effect:setParameter( "visualization", true )
	self.effect:setScale( sm.vec3.new( sm.construction.constants.subdivideRatio, sm.construction.constants.subdivideRatio, sm.construction.constants.subdivideRatio ) )
	self:client_init()
end

function PrinterTool.client_onRefresh( self )
    if self.tool:isLocal() then
		self.lastSentItem = nil
		self.activeItem = sm.localPlayer.getActiveItem()
	end
	self:client_init()
end

function PrinterTool.client_onDestroy()
    self.effect:stop()
end

function PrinterTool.client_init( self )
	self.liftPos = sm.vec3.new( 0, 0, 0 )
	self.hoverBodies = {}
	self.selectedBodies = {}
	self.rotationIndex = 0
end

function PrinterTool.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuildActive )
    if self.tool:isLocal() and self.equipped and sm.localPlayer.getPlayer():getCharacter() then
        if forceBuildActive then
			if self.effect:isPlaying() then
				self.effect:stop()
			end
			return false, false
        end
        local valid, worldPos, worldNormal = self:constructionRayCast()
        local success, raycastResult = sm.localPlayer.getRaycast( 7.5 )
		self:client_interact( primaryState, secondaryState, raycastResult )
        if valid and #self.selectedBodies > 0 then
			self.effect:setPosition( worldPos )
			self.effect:setRotation( sm.quat.angleAxis( math.pi*0.5, sm.vec3.new( 1, 0, 0 ) ) )
			if not self.effect:isPlaying() then
				self.effect:start()
			end
            if primaryState == sm.tool.interactState.start then
				self.network:sendToServer( "sv_n_put_printer", { pos = worldPos, slot = sm.localPlayer.getSelectedHotbarSlot() } )
			end
			return true, false
		else
			self.effect:stop()
			return false, false
        end
        
		
	end
	return true, false
end


function PrinterTool.sv_n_put_printer( self, params, player )
	local obj = sm.json.parseJsonString( sm.creation.exportToString( self.targetBody ) )
	for _, body in ipairs( self.targetBody:getCreationBodies() ) do
		for _, shape in ipairs( body:getShapes() ) do
			shape:destroyShape()
		end
	end
	local rot = math.random( 0, 3 ) * math.pi * 0.5
	local part = sm.shape.createPart( obj_ren_printer, params.pos, sm.quat.angleAxis( rot, sm.vec3.new( 0, 0, 1 ) ) * sm.quat.new( 0.70710678, 0, 0, 0.70710678 ) , false, false )
	sm.json.save( obj, "$SURVIVAL_DATA/Scripts/game/ren/blueprints/"..part.id..".blueprint" )
	sm.effect.playEffect( "Plants - SoilbagUse", params.pos, nil, sm.quat.angleAxis( rot, sm.vec3.new( 0, 0, 1 ) ) * sm.quat.new( 0.70710678, 0, 0, 0.70710678 ) )
end

function PrinterTool.constructionRayCast( self )

	local valid, result = sm.localPlayer.getRaycast( 7.5 )
	if valid then
		if result.type == "terrainSurface" then
			local groundPointOffset = -( sm.construction.constants.subdivideRatio_2 - 0.04 + sm.construction.constants.shapeSpacing + 0.005 )
			local pointLocal = result.pointLocal + result.normalLocal * groundPointOffset

			-- Compute grid pos
			local size = sm.vec3.new( 3, 3, 1 )
			local size_2 = sm.vec3.new( 1, 1, 0 )
			local a = pointLocal * sm.construction.constants.subdivisions
			local gridPos = sm.vec3.new( math.floor( a.x ), math.floor( a.y ), a.z ) - size_2

			-- Compute world pos
			local worldPos = gridPos * sm.construction.constants.subdivideRatio + ( size * sm.construction.constants.subdivideRatio ) * 0.5

			return valid, worldPos, result.normalWorld
		end
	end
	return false
end

function PrinterTool.checkPlaceable( self, raycastResult )
	if raycastResult.valid then
		if raycastResult.type == "lift" or raycastResult.type == "character" then
			return false
		end
		if raycastResult.type == "body" then
			if raycastResult:getBody():isOnLift() then
				return false
			end
		end
		return true
	end
	return false
end

function PrinterTool.client_interact( self, primaryState, secondaryState, raycastResult )
	local targetBody = nil

	if self.importBodies then
		self.selectedBodies = self.importBodies
		self.importBodies = nil
	end

	--Clear states
	if secondaryState ~= sm.tool.interactState.null then
		self.hoverBodies = {}
		self.selectedBodies = {}

		sm.tool.forceTool( nil )
		self.forced = false
	end
	
	--Raycast
	if raycastResult.valid then
		if raycastResult.type == "joint" then
			targetBody = raycastResult:getJoint().shapeA.body
		elseif raycastResult.type == "body" then
			targetBody = raycastResult:getBody()
		end
		
		local liftPos = raycastResult.pointWorld * 4
		self.liftPos = sm.vec3.new( math.floor( liftPos.x + 0.5 ), math.floor( liftPos.y + 0.5 ), math.floor( liftPos.z + 0.5 ) )
	end
	
	local isSelectable = false
	local isCarryable = false
	if self.selectedBodies[1] then
		if sm.exists( self.selectedBodies[1] ) and self.selectedBodies[1]:isDynamic() and self.selectedBodies[1]:isLiftable() then
			local isLiftable = true
			isCarryable = true
			for _, body in ipairs( self.selectedBodies[1]:getCreationBodies() ) do
				for _, shape in ipairs( body:getShapes() ) do
					if not shape.liftable then
						isLiftable = false
						break
					end
				end
				if not body:isDynamic() or not isLiftable then
					isCarryable = false
					break
				end
			end
		end
	elseif targetBody then
		if targetBody:isDynamic() and targetBody:isLiftable() then
			local isLiftable = true
			isSelectable = true
			for _, body in ipairs( targetBody:getCreationBodies() ) do
				for _, shape in ipairs( body:getShapes() ) do
					if not shape.liftable then
						isLiftable = false
						break
					end
				end
				if not body:isDynamic() or not isLiftable then
					isSelectable = false
					break
				end
			end
		end
	end
		
	--Hover
	if isSelectable and #self.selectedBodies == 0 then
		self.hoverBodies = targetBody:getCreationBodies()
	else
		self.hoverBodies = {}
	end

	-- Unselect invalid bodies
	if #self.selectedBodies > 0 and not isCarryable and not self.forced then
		self.selectedBodies = {}
	end

	--Check lift collision and if placeable surface
	local isPlaceable = self:checkPlaceable(raycastResult) 
	
	--Lift level
	local okPosition, liftLevel = sm.tool.checkLiftCollision( self.selectedBodies, self.liftPos, self.rotationIndex )
	isPlaceable = isPlaceable and okPosition

	--Pickup
	if primaryState == sm.tool.interactState.start then

		if isSelectable and #self.selectedBodies == 0 then
			self.targetBody = targetBody
			self.selectedBodies = self.hoverBodies
			self.hoverBodies = {}
		end
		sm.tool.forceTool( nil )
		self.forced = false
	end

	--Visualization
	-- sm.visualization.setCreationValid( isPlaceable )
	-- sm.visualization.setLiftValid( isPlaceable )

	if raycastResult.valid then
		if #self.hoverBodies > 0 then
			sm.visualization.setCreationBodies( self.hoverBodies )
			sm.visualization.setCreationFreePlacement( false )		
			sm.visualization.setCreationValid( true )
			sm.visualization.setLiftValid( true )
			sm.visualization.setCreationVisible( true )
			sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create" ), "Create BluePrint" )
        else
			if isPlaceable and #self.selectedBodies > 0 then
				sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create" ), "Place 3d Printer" )
			end
		end
	else
		-- sm.visualization.setCreationVisible( true )
	end
end

function PrinterTool.client_onToggle( self, backwards )
	
	local nextRotationIndex = self.rotationIndex
	if backwards then
		nextRotationIndex = nextRotationIndex - 1
	else
		nextRotationIndex = nextRotationIndex + 1
	end
	if nextRotationIndex == 4 then
		nextRotationIndex = 0
	elseif nextRotationIndex == -1 then
		nextRotationIndex = 3
	end
	self.rotationIndex = nextRotationIndex

	return true
end

function PrinterTool.client_onEquip( self )
	self.equipped = true
    self:client_init()
    print("equipped printer tool")
end

function PrinterTool.client_onUnequip( self )
    self.equipped = false
    self.effect:stop()
	sm.visualization.setCreationVisible( false )
end

function PrinterTool.client_onForceTool( self, bodies )
	self.equipped = true
    self.importBodies = bodies
    print(importBodies)
	self.forced = true
end