dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

PrinterTool = class()

function PrinterTool.server_onCreate( self )
	self.sv_loadBlueprints();
end

function PrinterTool.sv_saveBlueprints( self )
	sm.storage.save( STORAGE_CHANNEL_BLUEPRINTS, self.blueprints )
end

function PrinterTool.sv_loadBlueprints( self )
	self.blueprints = {}
	self.blueprints = sm.storage.load( STORAGE_CHANNEL_BLUEPRINTS )
	if self.blueprints then
		print( self.blueprints )
	else
		self.blueprints = {
			name = nil
		}
		print( self.blueprints )
		self:sv_saveBlueprints()
	end
end

function PrinterTool.client_onCreate( self )
	self.gui = nil
	self.blueprintsFiles = sm.json.open( "$SURVIVAL_DATA/Scripts/game/ren/blueprints.json" )
	self.blueprintSelectedIndex = 1
    self.effect = sm.effect.createEffect( "ShapeRenderable" )
	self.effect:setParameter( "uuid", sm.uuid.new("d4e6c84c-a493-44b1-81aa-4f4741ea3ee0") )
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
	self.blueprintBodies = {}
	self.rotationIndex = 0
	self.selectedContainer = nil
end

function PrinterTool.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuildActive )
	if self.tool:isLocal() and self.equipped and sm.localPlayer.getPlayer():getCharacter() then
		self.tool:setInteractionTextSuppressed( true )
		-- print(self.tool)
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
				self.network:sendToServer( "sv_n_put_printer", { pos = worldPos } )
			end
			return true, false
		else
			self.effect:stop()
			return false, false
        end
	end
	return true, false
end

function PrinterTool.cl_no_blueprint( self )
	sm.gui.displayAlertText( "Please set blueprint name using /blueprint <NAME_OF_BLUEPRINT>", 10 )
end


function PrinterTool.sv_n_put_printer( self, params, player )
	self.blueprints = sm.storage.load( STORAGE_CHANNEL_BLUEPRINTS )
	if self.blueprints == nil then
		self.network:sendToClients( "cl_no_blueprint" )
	elseif self.blueprints.name == nil  then
		self.network:sendToClients( "cl_no_blueprint" )
	else
		local obj = {}
		obj[#obj+1] = sm.json.parseJsonString( sm.creation.exportToString( self.targetBody, true ) )

		local usedShapes = {}
		usedShapes = getCreationsShapeCount( obj )
		for _, body in ipairs( self.targetBody:getCreationBodies() ) do
			for _, shape in ipairs( body:getShapes() ) do
				shape:destroyShape()
			end
		end
		local rot = math.random( 0, 3 ) * math.pi * 0.5
		local shape = sm.shape.createPart( obj_ren_container, params.pos, sm.quat.angleAxis( rot, sm.vec3.new( 0, 0, 1 ) ) * sm.quat.new( 0.70710678, 0, 0, 0.70710678 ) , false, false )
		local container = shape:getInteractable():getContainer()
		local index = 0
		sm.container.beginTransaction()
		for shape in pairs( usedShapes ) do
			sm.container.collect( container, sm.uuid.new( shape ), usedShapes[shape], false )
			index = index + 1
		end
		sm.container.endTransaction()
		sm.json.save( obj[1], "$SURVIVAL_DATA/Scripts/game/ren/blueprints/"..self.blueprints.name..".blueprint" )
		if contains(self.blueprintsFiles, self.blueprints.name) ~= true then
			self.blueprintsFiles[#self.blueprintsFiles+1] = self.blueprints.name
			sm.json.save( self.blueprintsFiles, "$SURVIVAL_DATA/Scripts/game/ren/blueprints.json" )
		end
		self.blueprints.name = nil
		self:sv_saveBlueprints()
	end
end

function PrinterTool.cl_no_blueprintQ( self )
	sm.gui.displayAlertText( "Please set blueprint using Q", 10 )
end


function PrinterTool.sv_n_spawn_blueprint( self, params, player )
	if self.blueprintsFiles[self.blueprintSelectedIndex] == "" then
		self.network:sendToClients( "cl_no_blueprintQ" )
	else
		local containerContent = getContainerContents(params.container:getInteractable():getContainer())
		local obj = {}
		local usedShapes = {}
		local buildable = true


		obj[#obj+1] = sm.json.open( "$SURVIVAL_DATA/Scripts/game/ren/blueprints/".. self.blueprintsFiles[self.blueprintSelectedIndex] ..".blueprint" )
		usedShapes = getCreationsShapeCount( obj )

		for shapeID in pairs(usedShapes) do
			local uid = sm.uuid.new( shapeID )
			local item_name = sm.shape.getShapeTitle( uid )

			if containerContent[shapeID] then
				if usedShapes[shapeID] > containerContent[shapeID] then
					local qty = usedShapes[shapeID] - containerContent[shapeID]
					if qty > 0 then
						print("Could not consume enough of ", item_name, " Needed ", qty, " more")
						sm.gui.chatMessage("#7eddde Need "..item_name .. " x " .. qty)
						buildable = false
					end
				end
			else
				sm.gui.chatMessage("#7eddde Need "..item_name .. " x " .. usedShapes[shapeID])
				buildable = false
			end
		end

		if buildable == true then
			sm.creation.importFromFile( player.character:getWorld(), "$SURVIVAL_DATA/Scripts/game/ren/blueprints/"..self.blueprintsFiles[self.blueprintSelectedIndex]..".blueprint", params.container.worldPosition )
			params.container:destroyShape()
			self.blueprints.name = nil
			self:sv_saveBlueprints()
		end
		
	end
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
	self.selectedContainer = nil
	if self.importBodies then
		self.selectedBodies = self.importBodies
		self.importBodies = nil
	end

	--Clear states
	if secondaryState ~= sm.tool.interactState.null then
		self.hoverBodies = {}
		self.selectedBodies = {}
		self.selectedContainer = nil
		sm.tool.forceTool( nil )
		self.forced = false
	end
	
	--Raycast
	if raycastResult.valid then
		if raycastResult.type == "joint" then
			targetBody = raycastResult:getJoint().shapeA.body
		elseif raycastResult.type == "body" then
			targetBody = raycastResult:getBody()
			for _, shape in ipairs( targetBody:getShapes() ) do
				-- container ren
				if shape.shapeUuid == obj_ren_container then
					self.selectedContainer = shape
					sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create" ), "Extract Blueprint : "..self.blueprintsFiles[self.blueprintSelectedIndex] )
					local keyBindingText =  sm.gui.getKeyBinding( "Use" )
					sm.gui.setInteractionText( "", keyBindingText, "Press Q to toggle through Blueprints" )
					break
				end
			end
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
		if self.selectedContainer and self.selectedContainer.shapeUuid == obj_ren_container then
			self.network:sendToServer( "sv_n_spawn_blueprint", { container = self.selectedContainer } )
		end
		if isSelectable and #self.selectedBodies == 0 then
			self.targetBody = targetBody
			self.selectedBodies = self.hoverBodies
			self.hoverBodies = {}
		end
		sm.tool.forceTool( nil )
		self.forced = false
	end

	--Visualization
	sm.visualization.setCreationValid( isPlaceable )
	sm.visualization.setLiftValid( isPlaceable )

	if raycastResult.valid then
		local showLift = #self.hoverBodies == 0
		if #self.blueprintBodies > 0 then
			sm.visualization.setLiftPosition( self.liftPos * 0.25 )
			sm.visualization.setLiftLevel( liftLevel )
			sm.visualization.setLiftVisible( showLift )
			sm.visualization.setCreationBodies( self.blueprintBodies )
			sm.visualization.setCreationFreePlacement( true )
			sm.visualization.setCreationFreePlacementPosition( self.liftPos * 0.25 + sm.vec3.new(0,0,0.5) + sm.vec3.new(0,0,0.25) * liftLevel )
			sm.visualization.setCreationFreePlacementRotation( self.rotationIndex )
			sm.visualization.setCreationVisible( true )
			sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create" ), "#{INTERACTION_PLACE_LIFT_ON_GROUND}" )
		elseif #self.hoverBodies > 0 then
			sm.visualization.setCreationBodies( self.hoverBodies )
			sm.visualization.setCreationFreePlacement( false )		
			sm.visualization.setCreationValid( true )
			sm.visualization.setLiftValid( true )
			sm.visualization.setCreationVisible( true )
			sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create" ), "Create Blueprint" )
        elseif isPlaceable and #self.selectedBodies > 0 then
				sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Create" ), "Place 3d Printer" )
		end
	else
	end
end

function contains(list, x)
	for v in pairs(list) do
		if list[v] == x then return true end
	end
	return false
end

function PrinterTool.client_onToggle( self, backwards )
	print( contains(self.blueprintsFiles, "asd")  )
	self.blueprintsFiles = sm.json.open( "$SURVIVAL_DATA/Scripts/game/ren/blueprints.json" )
	if self.blueprintSelectedIndex >= #self.blueprintsFiles then
		self.blueprintSelectedIndex = 1
	else
		self.blueprintSelectedIndex = self.blueprintSelectedIndex + 1
	end
	sm.gui.displayAlertText( self.blueprintsFiles[self.blueprintSelectedIndex], 2 )
	


	return true
end

function PrinterTool.client_onEquip( self )
	self.equipped = true
	print(self.blueprints)
	self:client_init()
end

function PrinterTool.client_onUnequip( self )
    self.equipped = false
	self.effect:stop()
	sm.visualization.setCreationVisible( false )
	sm.visualization.setLiftVisible( false )
	if self.gui then
		
		self.gui = nil
		-- self.gui:destroy()
	end

	
	sm.visualization.setCreationVisible( false )
end

function PrinterTool.client_onForceTool( self, bodies )
	self.equipped = true
    self.importBodies = bodies
	self.forced = true
end


function getCreationsShapeCount( creations )
	local usedShapes = {}
	for _, blueprintObject in ipairs( creations ) do

		-- Count joints used in the blueprint
		if blueprintObject.joints then
			for _, joint in ipairs( blueprintObject.joints ) do
				if usedShapes[joint.shapeId] == nil then
					usedShapes[joint.shapeId] = 0
				end
				usedShapes[joint.shapeId] = usedShapes[joint.shapeId] + 1
			end
		end
		
		-- Count parts and blocks used in the blueprint
		if blueprintObject.bodies then
			for _, body in ipairs( blueprintObject.bodies ) do
				if body.childs then
					for _, child in ipairs( body.childs ) do
						if child.bounds then
							if usedShapes[child.shapeId] == nil then
								usedShapes[child.shapeId] = 0
							end
							usedShapes[child.shapeId] = usedShapes[child.shapeId] + child.bounds.x * child.bounds.y * child.bounds.z
						else
							if usedShapes[child.shapeId] == nil then
								usedShapes[child.shapeId] = 0
							end
							usedShapes[child.shapeId] = usedShapes[child.shapeId] + 1
						end									
					end
				end
			end
		end
	end
	
	return usedShapes
end

function getContainerContents( container )
	local content = {}
	for i=0,container:getSize()-1 do 
		local item = container:getItem(i)
		if item.uuid ~= sm.uuid.new() then
			if content[ tostring( item.uuid ) ] == nil then
				content[ tostring( item.uuid ) ] = 0
			end
			content[ tostring( item.uuid ) ] = content[ tostring( item.uuid ) ] + item.quantity
		end
	end

	return content
end
