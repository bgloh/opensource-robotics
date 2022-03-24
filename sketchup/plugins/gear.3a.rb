#-----------------------------------------------------------------------------
# Name        :   gear.3.rb
# Description :   This file creates a involute tooth gear, with or without a hole for shaft and key.
# Parameters  :   The number of teeth, pressure angle, pitch radius, shaft radius, keyway width and depth.
# Menu Item   :   Draw -> Involute Gear
#             :   Draw -> Key Involute Gear
# Context Menu:   NONE
# Usage       :   N/A
# Date        :   9/2/2006
# Author      :   Doug Herrmann
# Modified    :   8/21/2016
# By		  :   Michael Curry
#-----------------------------------------------------------------------------

require 'sketchup.rb'


#=============================================================================
# Generates an Involute Tooth Gear
class Gear

	# default values for dialog box
	@@teeth = 9
	@@ang_pressure = 20.0  # degrees
	@@rad_pitch = 10.0.inch


	def Gear.dialog
		# First prompt for the dimensions.
		prompts = ["Number of Teeth: ", "Pressure Angle: ", "Pitch Radius: "]
		values = [@@teeth, @@ang_pressure, @@rad_pitch]
			
		# Display the inputbox
		results = inputbox prompts, values, [nil,'14.5|20.0|25.0'], "Involute Gear Parameters"
		
		return if not results # This means that the user cancelled the operation
		
		# update default settings
		@@teeth, @@ang_pressure, @@rad_pitch = results

		Gear.new
	end


	def initialize(teeth=@@teeth, ang_pressure=@@ang_pressure, rad_pitch=@@rad_pitch)
		@teeth = teeth
		@ang_pressure = ang_pressure * Math::PI / 180.0  # convert to radians
		@rad_pitch = rad_pitch

		# Constants really -- as long as the original parameters don't change
		@diameter = 2.0 * @rad_pitch
		@rad_outside = @rad_pitch + @diameter/@teeth     # + 1/diametral pitch
		@rad_inside = @rad_pitch - @diameter/@teeth      # - 1/diametral pitch
		@rad_root = @rad_pitch - 1.157*@diameter/@teeth  # - 1.157/diametral pitch
		@rad_base = @rad_pitch * Math.cos(@ang_pressure)
		@rad_fillet = @rad_inside - @rad_root

		# Encapsulate into a single UNDO operation.
		model = Sketchup.active_model
		model.start_operation "Create Involute Gear"

		# Group the entities - And save the SketchUp Group Entities object as a class variable
		entities = model.active_entities
		group = entities.add_group
		@entities = group.entities

		drawGear

		model.commit_operation
	end


	private


	def drawGear
		edges = drawProfile
		face = @entities.add_face edges
	end


	# points on involute curve parameterized by ang (in radians)
	def involute(ang)
		x1 = @rad_base * Math.cos(ang)
		y1 = @rad_base * Math.sin(ang)
		s = ang * @rad_base
		x = x1 + s * Math.sin(ang)
		y = y1 - s * Math.cos(ang)

		[x, y]
	end


	def drawProfile
		points = []

		# Fillet points on right side of tooth
		if @rad_inside <= @rad_base
			points = filletPoints @rad_inside, -@rad_fillet
			ang = 0
		else
			# calc angle and coordinate involute intersects inside radius
			s = Math.sqrt(@rad_inside * @rad_inside - @rad_base * @rad_base)
			ang = s / @rad_base
			x0, y0 = involute(ang)
			points = filletPoints x0, y0 - @rad_fillet
		end

		# calc value of parameter where Involute curve intersects outside radius
		s_max = Math.sqrt(@rad_outside * @rad_outside - @rad_base * @rad_base)
		ang_max = s_max / @rad_base

		# calc Involute curve points along tooth's right side
		ang += 7 * Math::PI / 180.0
		while ang < ang_max
			x, y = involute(ang)
			points.push([x, y, 0])
			ang += 7 * Math::PI / 180.0
		end

		#Compute last point where involute intersects the outside circle
		x, y = involute(ang_max)
		points.push([x, y, 0])

		# Rotate profile CW so that it intersects the x-axis at the Pitch radius
		s = Math.sqrt(@rad_pitch**2 - @rad_base**2)
		delta = (s / @rad_base) - @ang_pressure
		t0 = Geom::Transformation.rotation [0,0,0], Z_AXIS, -delta
		points.collect! {|pnt| t0 * pnt}

		# Reflect about the x-axis
		t1 = Geom::Transformation.rotation [0,0,0], X_AXIS, Math::PI

		# Rotate CW a tooth-space
		t2 = Geom::Transformation.rotation [0,0,0], Z_AXIS, -Math::PI/@teeth

		# The left profile of the adjacent tooth
		t = t2 * t1
		reflect = points.collect {|pnt| t * pnt}

		# Left profile, space, right profile
		points = reflect.reverse! + points

		# Center tooth along x-axis
		t3 = Geom::Transformation.rotation [0,0,0], Z_AXIS, -Math::PI/(2.0*@teeth)
		points.collect! {|pnt| t3 * pnt}

		# vertices for edge
		p1 = points.last
		p2 = [p1.x, -p1.y, 0]
		
		# Now add curves and edges outlining the gear
		edges = []
		0.upto(@teeth - 1) do |n|
			tr = Geom::Transformation.rotation [0,0,0], Z_AXIS, 2 * Math::PI * n / @teeth

			# add curve
			edges += @entities.add_curve points.collect {|pnt| tr * pnt}

			# add edge at top of tooth
			edges += @entities.add_edges tr*p1, tr*p2
		end

		# return edges
		edges
	end


	def filletPoints(x0, y0)
		points = []

		#deg = 180 downto 90
		ang = Math::PI
		4.times do
			x = x0 + @rad_fillet * Math.cos(ang)
			y = y0 + @rad_fillet * Math.sin(ang)
			points.push([x, y, 0])
			ang = ang - Math::PI / 6.0
		end

		points
	end

end


#=============================================================================
# Generates an Involute Tooth Gear with hole for shaft and key
class KeyGear < Gear

	# default values for dialog box
	@@rad_shaft = 4.inch
	@@width_key = 2.inch
	@@height_key = 1.5.inch


	def KeyGear.dialog
		# First prompt for the dimensions
		prompts = ["Number of Teeth: ", "Pressure Angle: ", "Pitch Radius: ", "Shaft Radius: ", "Keyway Width: ", "Keyway Depth: "]
		values = [@@teeth, @@ang_pressure, @@rad_pitch, @@rad_shaft, @@width_key, @@height_key]
			
		# Display the inputbox
		results = inputbox prompts, values, [nil,'14.5|20.0|25.0'], "Key Involute Gear Parameters"
		
		return if not results # This means that the user cancelled the operation
		
		# update default settings
		@@teeth, @@ang_pressure, @@rad_pitch, @@rad_shaft, @@width_key, @@height_key = results

		KeyGear.new
	end


	def initialize(teeth=@@teeth, ang_pressure=@@ang_pressure, rad_pitch=@@rad_pitch, rad_shaft=@@rad_shaft, width_key=@@width_key, height_key=@@height_key)
		# Class variables unique to Key Gear
		@rad_shaft = rad_shaft
		@width_keyhole = width_key
		@height_keyhole = height_key

		super(teeth, ang_pressure, rad_pitch)
	end


	private


	def drawGear
		# Draw gear
		face1 = super

		# Create interior face for shaft and keyway
		edges2 = drawKey
		face2 = @entities.add_face edges2

		# knock out a hole
		face2.erase!
	end


	def drawKey
		opp = @width_keyhole / 2
		adj = Math.sqrt(@rad_shaft**2 - opp**2)
		phi = Math.atan2(opp, adj)

		# Unit vectors along the X-axis and Z-axis
		i = Geom::Vector3d.new 1,0,0;  i.normalize!
		k = Geom::Vector3d.new 0,0,1;  k.normalize!

		# Draw shaft arc
		edges1 = @entities.add_arc [0,0,0], i, k, @rad_shaft, phi, 2*Math::PI - phi, 48

		# points on keyway
		p1 = [adj, -opp, 0]
		p2 = [adj + @height_keyhole, -opp, 0]
		p3 = [adj + @height_keyhole, +opp, 0]
		p4 = [adj, +opp, 0]

		# edges along keyway
		edges2 = @entities.add_edges p1, p2, p3, p4

		# Return edges
		edges1 + edges2
	end

end


#=============================================================================
# User Interface Stuff
if( not file_loaded?("gear.3.rb") )

	# This will add a separator to the menu, but only once
	UI.menu("Tools").add_separator
	
	# Add items to Draw menu
	UI.menu("Tools").add_item("Involute Gear") { Gear.dialog }
	UI.menu("Tools").add_item("Key Involute Gear") { KeyGear.dialog }

end


#-----------------------------------------------------------------------------
file_loaded("gear.3.rb")