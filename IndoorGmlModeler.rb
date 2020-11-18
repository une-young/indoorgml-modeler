# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'mainTool.rb'
require 'rexml/document'

# IndoorGml modeler
# copyright 2020 UNE.co.kr

include Sketchup
include REXML
include Geom

module UNES
  module IndoorGmlModeler
    module EditMode
      NONE = 0
      CELL = 1
      NODE = 2
      POI = 3
      DOOR = 4
      FLOOR = 5
    end

    class Element
      attr_reader :name
      attr_writer :name
      attr_reader :id
      attr_writer :id

      def initialize
        @name = ''
        # @id = SecureRandom.base64(8).gsub("/","_").gsub(/=+$/,"")
        @id = rand(36**8).to_s(36)
      end
    end

    # transition node
    class Node < Element
      attr_reader :position
      attr_writer :position
      attr_reader :parent
      attr_writer :parent
      attr_reader :component
      attr_writer :component
      attr_reader :node_type
      attr_writer :node_type

      @@node_type_names = %w[NONE DOOR WINDOW ROOM]

      def initialize
        super
        @position = Geom::Point3d.new
        # node가 속한 객체 (cell space나 door 혹은 다른 것들)
        @parent = nil
        # node의 형상 entity (Component)
        @component = nil
        @node_type = NodeType::NONE
      end

      def get_node_type_name
        @@node_type_names[@node_type]
      end
    end

    module CellType
      SPACE = 0
      DOOR = 1
      WINDOW  = 2
      ELEVATOR = 3
      STAIR = 4
    end

    module DoorType
      PASSABLE = 0
      ONESIDE = 1
      NOTPASSABLE = 2
    end

    module PoiType
      NONE = 0
      SPACE = 1
      ETC = 2
    end

    module NodeType
      NONE = 0
      DOOR = 1
      WINDOW =2
      ROOM = 3
    end

    # building
    class Building < Element
      attr_reader :floors
      attr_writer :floors

      def initialize
        @floors = []
      end

      def to_hash
        hash_list = []

        @floors.each do |f|
          hash_list.push f.to_hash
        end

        hash_list
      end
    end

    # floor
    class Floor < Element
      attr_reader :height
      attr_writer :height
      attr_reader :elevation
      attr_writer :elevation
      attr_reader :group
      attr_writer :group

      def initialize(height, elevation)
        @cells = []
        @links = []
        @doors = []
        @nodes = []
        @pois = []
        @layer = nil
        @height = height
        @elevation = elevation
        # @group = nil

        # model = Sketchup.active_model

        # depth = 1000 / 1.to_m # 1000 미터가 되기 위한 인치수를 구함
        # width = 1000 / 1.to_m
        # pts = []
        # pts[0] = [-width, -depth, elevation]
        # pts[1] = [width, -depth, elevation]
        # pts[2] = [width, depth, elevation]
        # pts[3] = [-width, depth, elevation]

        # face = model.entities.add_face pts
        # face.pushpull(-@height, false)

        # @group = model.entities.add_group face.all_connected
        # @group.hidden = true
      end

      def to_hash
        {
          name: @name,
          elevation: @elevation,
          height: @height
        }
      end

      def is_in(entity, parent_group = nil)
        return false if @group.nil? || entity.nil?

        return false if @group.deleted?

        return false if entity.deleted?

        if parent_group.nil?
          bounds = @group.bounds.intersect(entity.bounds)
        else
          outter_bounds = parent_group.bounds
          inner_bounds = entity.bounds

          min = inner_bounds.min
          max = inner_bounds.max

          world_min = min.transform(outter_bounds.transformation)
          world_max = max.transform(outter_bounds.transformation)

          world_bounds = Geom::BoundingBox.new

          world_bounds.add world_min
          world_bounds.add world_max

          bounds = @group.bounds.intersect(world_bounds)
        end

        return false if bounds.empty?

        true
      end
    end

    # cell space
    class Cell < Element
      attr_reader :group
      attr_writer :group
      attr_reader :cell_type
      attr_writer :cell_type
      attr_reader :doors
      attr_writer :doors
      attr_reader :node
      attr_writer :node
      attr_reader :layer
      attr_writer :layer

      @@cell_type_names = %w[SPACE DOOR WINDOW ELEVATOR STAIR]

      def initialize
        super
        @group = nil
        @cell_type = CellType::SPACE
        @doors = []
        @node = nil
        # layer는 그냥 text 이름임
        @layer = 'group 0'
      end

      def get_cell_type_name
        @@cell_type_names[@cell_type]
      end

      def has_entity(entity)
        false if entity.nil?

        if @group.is_a?(Group)
          true unless @group.entities.find_index(entity).nil?
        end

        false
      end
    end

    # transition link
    class Link < Element
      attr_reader :node1
      attr_writer :node1
      attr_reader :node2
      attr_writer :node2
      attr_reader :line
      attr_writer :line

      def initialize
        super
        @node1 = nil
        @node2 = nil
        # 노드 사이 연결을 나타내는 line (polyline이 될수도 있음)
        @line = nil
      end

      def isSame(n1, n2)
        return true if @node1 == n1 && @node2 == n2

        return true if @node1 == n2 && @node2 == n1

        false
      end

      def to_hash
        {
          node1_name: @node1.name,
          node2_name: @node2.name
        }
      end

      def update_line
        return false if @node1.component.deleted?

        point1 = @node1.component.bounds.center

        point1 = point1.transform(node1.parent.group.transformation) if @node1.parent.is_a?(Cell)

        return false if @node2.component.deleted?

        point2 = @node2.component.bounds.center

        point2 = point2.transform(node2.parent.group.transformation) if @node2.parent.is_a?(Cell)

        entities = Sketchup.active_model.active_entities
        entities.erase_entities @line
        @line = entities.add_cline(point1, point2)
      end
    end

    # cell space 사이의 transition을 만들기 위해 필요한 객체
    class Door < Element
      attr_reader :face
      attr_writer :face
      attr_reader :group
      attr_writer :group
      attr_reader :door_type
      attr_writer :door_type
      attr_reader :node
      attr_writer :node
      attr_reader :face_vertices
      attr_writer :face_vertices

      @@door_type_names = %w[PASSABLE ONESIDE NOTPASSABLE]

      def initialize
        super
        @face = nil
        @group = nil
        @door_type = DoorType::PASSABLE
        @node = nil
        @face_vertices = []
      end

      def update_door_face
        # 겹치는 face를 찾음
        if @face.nil? || @face.deleted?
          model = Sketchup.active_model
          i = 0
          while i < model.entities.length() do
            e = model.entities[i]
            if e.is_a?(Face) && !e.deleted?
              result = e.bounds.intersect(node.component.bounds)

              unless result.empty?
                @face = e
                break
              end
            end
            i += 1
          end
        end
      end

      def get_door_type_name
        @@door_type_names[@door_type]
      end
    end

    class Poi < Element
      attr_reader :component
      attr_writer :component
      attr_reader :poi_type
      attr_writer :poi_type
      attr_reader :position
      attr_writer :position


      @@poi_type_names = %w[NONE SPACE ETC]

      def initialize
        super
        # poi 3차원 형태 인스턴스
        @component = nil
        @poi_type = PoiType::NONE
        @position = Geom::Point3d.new
      end

      def get_poi_type_name
        @@poi_type_names[@poi_type]
      end
    end

    class IndoorGmlEntitiesObserver < EntitiesObserver
      def onElementAdded(entities, entity)
        # puts "onElementAdded: #{entity}"
      end

      def onElementModified(entities, entity)
        # puts "onElementModified: #{entity}"
      end
    end

    class DoorObserver < Sketchup::EntityObserver
      attr_reader :door
      attr_writer :door

      @door = nil
      def onEraseEntity(entity)
        if entity.is_a?(Face)
          face = Sketchup.active_model.entities.add_face @door.face_vertices
          @door.face = face
        end
      end
    end

    class CellObserver < Sketchup::EntityObserver
      MAIN = UNES::IndoorGmlModeler

      def onChangeEntity(entity)
        if entity.is_a?(Group)
          cell = MAIN.find_cell_by_group entity

          MAIN.links.each do |l|
            l.update_line if l.node1 == cell.node

            l.update_line if l.node2 == cell.node
          end
        end
      end

      def onEraseEntity(entity)
        if entity.is_a?(Group)
          cell = MAIN.find_cell_by_group entity

          MAIN.cells.delete(cell) if cell.nil?
        end
      end
    end

    class SelectionChangeObserver < Sketchup::SelectionObserver
      MAIN = UNES::IndoorGmlModeler

      def onSelectionAdded(selection, _entity)
        MAIN.on_selection_change(selection)
      end

      def onSelectionBulkChange(selection)
        MAIN.on_selection_change(selection)
      end

      def onSelectionCleared(selection)
        MAIN.on_selection_change(selection)
      end

      def onSelectionRemoved(selection, _entity)
        MAIN.on_selection_change(selection)
      end

      def onSelectedRemoved(selection, _entity)
        MAIN.on_selection_change(selection)
      end
    end

    class AppObserver < Sketchup::AppObserver
      MAIN = UNES::IndoorGmlModeler

      def onNewModel(model)
        observe_model(model)
      end

      def onOpenModel(model)
        observe_model(model)
      end

      def expectsStartupModelNotifications
        true
      end

      private

      def observe_model(model)
        model.selection.add_observer(SelectionChangeObserver.new)
        model.entities.add_observer(IndoorGmlEntitiesObserver.new)
        MAIN.clean_variables
        MAIN.update_materials
      end
    end

    class << self
      attr_reader :cells
      attr_writer :cells
      attr_reader :doors
      attr_writer :doors
      attr_reader :links
      attr_writer :links

      attr_reader :edit_mode
      attr_writer :edit_mode

      def initialize_data
        @command = UI::Command.new('MainTool') do
          begin
            Sketchup.active_model.select_tool(MainTool.new)
          rescue StandardError => e
            puts e.message
            puts e.backtrace
          end
        end

        clean_variables
      end

      def clean_variables
        @nodes = []
        @links = []
        @cells = []
        @doors = []
        @pois = []
        @model = Sketchup.active_model
        @cell_creation_count = 0
        @door_creation_count = 0
        @node_creation_count = 0
        @link_creation_count = 0
        @poi_creation_count = 0
        @floor_creation_count = 0
        @edit_mode = EditMode::NONE
        @building = Building.new

        floor = Floor.new(3.5 / 1.to_m, 0) # 1층
        floor.name = @name = "Floor#{@floor_creation_count}"
        @floor_creation_count += 1
        @building.floors.push floor
      end

      def update_materials
        materials = Sketchup.active_model.materials
        @cell_material = materials.add('indoor_cell')
        @cell_material.color = Color.new('red')
        @cell_material.alpha = 0.3
        @door_material = materials.add('indoor_door')
        @door_material.color = Color.new('green')
        @door_material.alpha = 0.8
        @node_material = materials.add('indoor_link')
        @node_material.color = Color.new('blue')
      end

      def create_link(node1, node2)
        return nil if is_link_exist(node1, node2)

        link = Link.new
        link.node1 = node1
        link.node2 = node2

        return false if node1.component.deleted?

        point1 = node1.component.bounds.center

        point1 = point1.transform(node1.parent.group.transformation) if node1.parent.is_a?(Cell)

        return false if node2.component.deleted?

        point2 = node2.component.bounds.center

        point2 = point2.transform(node2.parent.group.transformation) if node2.parent.is_a?(Cell)

        entities = @model.active_entities
        link.line = entities.add_cline(point1, point2)

        link
      end

      def get_link(node1,node2)
        @links.each do |l|
          return l if l.isSame(node1, node2)
        end

        nil
      end

      def get_links_by_node(node)
        node_links = []
        
        @links.each do |l|
          if l.node1.name == node.name || l.node2.name == node.name
            node_links.push(l) 
          end
        end

        node_links
      end

      def is_link_exist(node1, node2)
        @links.each do |l|
          return true if l.isSame(node1, node2)
        end

        false
      end

      def create_cell(entity)
        cell = nil
        if entity.is_a?(Face)
          unless is_cell_exist(entity)
            cell = Cell.new
            all_connected = entity.all_connected
            all_connected.push entity
            group = Sketchup.active_model.entities.add_group all_connected

            unless group.manifold?
              group.explode
              return nil
            end

            cell.group = group
          end
        elsif entity.is_a?(Group)
          cell = get_cell(entity)
          if cell.nil?
            cell = Cell.new
            cell.group = entity
          end
        elsif entity.is_a?(ComponentInstance)
          cell = get_cell(entity)
          if cell.nil?
            cell = Cell.new
            cell.group = entity
          end
        end

        unless cell.nil?
          cell.name = 'cell_' + @cell_creation_count.to_s
          node = create_node(cell)

          group_name = cell.group.name

          # node를 cell 그룹에 추가
          a = (cell.group.explode.find_all { |e| e if e.respond_to?(:bounds) }).uniq
          a.push node.component
          group = Sketchup.active_model.entities.add_group a
          cell.group = group
          cell.node = node
          # cell.group.name = "#{cell.name}@@@#{cell.id}"
          cell.group.name = group_name
          cell.group.material = @cell_material

          a.each do |e|
            e.material = @cell_material if e.is_a?(Face)
          end

          cell.group.add_observer(CellObserver.new)
          @cell_creation_count += 1

          @cells.push(cell)
        end

        # node link 갱신
        @nodes.each do |n|
          next unless n.parent.is_a?(Cell)

          next unless n.parent.cell_type == CellType::DOOR

          result = get_intersected_cells_from_node(n)

          result.each do |c|
            # link가 존재하지 않는다면 link를 생성
            next if is_link_exist(c.node, n)

            link = create_link c.node, n

            @links.push link unless link.nil?
          end
        end

        cell
      end

      def get_intersected_cells_from_node(node)
        intersected = []

        @cells.each do |c|
          result = c.group.bounds.intersect(node.component.bounds)

          intersected.push c unless result.empty?
        end

        intersected
      end

      def find_cell_by_group(group)
        @cells.each do |c|
          return c if c.group == group
        end

        nil
      end

      def create_node(element)
        nil if element.nil?

        center = nil

        center = element.group.bounds.center if element.is_a?(Cell)

        if element.is_a?(Door)
          center = element.group.bounds.center if element.face.nil? && !element.group.nil?
          center = element.face.bounds.center if element.group.nil? && !element.face.nil?
        end

        # component instance를 반환

        instance = create_sphere(center, 0.25 / 1.to_m, @node_material)
        node = Node.new
        node.name = 'node_' + @node_creation_count.to_s
        node.parent = element
        element.node = node
        node.component = instance
        node.position = center

        node.node_type = NodeType::DOOR if element.is_a?(Door)

        node.node_type = NodeType::ROOM if element.is_a?(Cell)

        @node_creation_count += 1
        @nodes.push(node)
        node
      end

      def is_cell_exist(face)
        cell_exist = false

        @cells.each do |c|
          if c.has_entity face
            cell_exist = true
            break
          end
        end

        cell_exist
      end

      # group에서 cell을 가져온다 없으면 nil
      def get_cell(group)
        @cells.each do |c|
          return c if c.group == group
        end

        nil
      end

      # 이름으로 node를 가져온다.
      def get_node_by_name(name)
        @nodes.each do |n|
          return n if n.name == name
        end

        nil
      end

      def get_node(component)
        @nodes.each do |n|
          return n if n.component == component
        end

        nil
      end

      # group 혹은 componentInstance에서 poi를 생성한다.
      def create_poi(entity)
        if entity.is_a?(ComponentInstance)
          if get_poi(entity).nil?
            poi = Poi.new
            poi.name = 'poi_' + @poi_creation_count.to_s
            @poi_creation_count += 1
            poi.component = entity
            poi.position = entity.bounds.center
            @pois.push poi
            return poi
          end
        end

        nil
      end

      # group 혹은 componentInstance에서 poi를 가져온다 없으면 nil
      def get_poi(entity)
        @pois.each do |p|
          return p if p.component == entity
        end

        nil
      end

      # group에서 문을 생성한다.
      def create_door_from_group(group)
        # group이 이미 door인지 check
        door = get_door(group)

        return door unless door.nil?

        door = Door.new
        door.group = group
        door.face = nil
        door.name = 'door' + @door_creation_count.to_s
        @door_creation_count += 1
        @doors.push door

        group.material = @door_material

        node = create_node(door)

        @cells.each do |c|
          next unless group.bounds.intersect(c.group.bounds).empty? == false

          c.doors.push door
          puts "cell:#{c.name} add door:#{door.name}"
          link = create_link door.node, c.node

          @links.push link unless link.nil?
        end
        door
      end

      # face에서 문을 생성한다.
      def create_door(face)
        if face.is_a?(Group)
          return create_door_from_group(face)
        end

        # face가 이미 door인지 check
        door = get_door(face)

        return door unless door.nil?

        door = Door.new
        door.face = face
        door.face_vertices = face.outer_loop.vertices
        observer = DoorObserver.new
        observer.door = door
        door.face.add_observer(observer)
        door.name = 'door' + @door_creation_count.to_s
        @door_creation_count += 1
        @doors.push door

        face.material = @door_material

        node = create_node(door)

        @cells.each do |c|
          next unless node.component.bounds.intersect(c.group.bounds).empty? == false

          c.doors.push door
          puts "cell:#{c.name} add door:#{door.name}"
          link = create_link door.node, c.node

          @links.push link unless link.nil?
        end

        door
      end

      def get_door(entity)
        if entity.is_a?(Group)
          @doors.each do |d|
            return d if d.group == entity
          end
        elsif entity.is_a?(Face)
          @doors.each do |d|
            return d if d.face == entity
          end
        end

        nil
      end

      # face가 그룹의 어떤 face 안에 포함되는지 판별
      def get_face_layon_group(group, face)
        positions = []

        face.vertices.each do |v|
          positions.push v.position
        end

        result = false

        group.entities.each do |f|
          next unless f.is_a?(Face)

          is_face_layon = true

          positions.each do |pt|
            # pt를 그룹내의 상대좌표로 바꿔야 한다.
            pt = pt.transform(group.transformation.inverse)
            result = f.classify_point(pt)
            puts result
            if result == Sketchup::Face::PointUnknown || result == Sketchup::Face::PointNotOnPlane || result == Sketchup::Face::PointOutside
              is_face_layon = false
            end
          end

          return f if is_face_layon
        end

        nil
      end

      def on_selection_change(_selection)
        # puts "selected:#{selection}"
        update_dialog
      end

      # create dialog

      def create_dialog(url)
        html_file = File.join(__dir__, 'html_template', url)
        puts "edit mode:#{@edit_mode}"

        options = {
          dialog_title: 'IndoorGml Modeler',
          preferences_key: 'unes.indoorgml.modeler',
          style: UI::HtmlDialog::STYLE_DIALOG,
          # Set a fixed size now that we know the content size.
          resizable: true,
          width: 540,
          height: 580
        }

        unless @dialog.nil?
          @dialog.close
          @dialog = nil
        end

        dialog = UI::HtmlDialog.new(options)
        dialog.set_size(options[:width], options[:height]) # Ensure size is set.
        dialog.set_file(html_file)
        dialog.center
        dialog
      end

      def show_dialog
        case @edit_mode
        when EditMode::CELL
          @dialog = create_dialog('cell.html')
        when EditMode::DOOR
          @dialog = create_dialog('cell.html') # door.html 안씀
        when EditMode::NODE
          @dialog = create_dialog('node.html')
        when EditMode::POI
          @dialog = create_dialog('poi.html')
        else
          puts 'show dialog error'
        end

        # @dialog ||= create_dialog
        @dialog.add_action_callback('ready') do |_action_context|
          update_dialog
          nil
        end

        @dialog.add_action_callback('createCell') do |_action_context, _value|
          entity = Sketchup.active_model.selection.first
          create_cell(entity) if entity.is_a?(Face) || entity.is_a?(Group) || entity.is_a?(ComponentInstance)
        end

        @dialog.add_action_callback('createDoor') do |_action_context, _value|
          entity = Sketchup.active_model.selection.first
          if entity.is_a?(Face) || entity.is_a?(Group)
            puts "create door:#{entity}"
            create_door(entity)
          end
          nil
        end

        @dialog.add_action_callback('createNode') do |_action_context, _value|
          entity = Sketchup.active_model.selection.first

          # if entity.is_a?(Face)
          #     create_node(entity)
          # end

          nil
        end

        @dialog.add_action_callback('createPoi') do |_action_context, _value|
          entity = Sketchup.active_model.selection.first
          create_poi(entity) if entity.is_a?(ComponentInstance)

          nil
        end
        @dialog.add_action_callback('cancel') do |_action_context, _value|
          @dialog.close
          nil
        end
        @dialog.add_action_callback('save') do |_action_context, _value|
          export_indoorgml
          nil
        end
        @dialog.add_action_callback('read') do |_action_context, _value|
          indoorgml_import
          nil
        end
        @dialog.add_action_callback('showThisCellOnly') do |_action_context, _value|
          entity = Sketchup.active_model.selection.first

          show_this_cell_only(entity) if entity.is_a?(Group)
        end
        @dialog.add_action_callback('createFloorLayer') do |_action_context, value|
          puts value
          create_floor_layer(value)
        end
        @dialog.add_action_callback('updateCellName') do |_action_context, value|
        end

        @dialog.add_action_callback('updateCellGroup') do |_action_context, value|
        end

        # cell data를 html dialog에서 받아서 업데이트 한다.
        @dialog.add_action_callback('updateCell') do |_action_context, value1, value2|
          value1.each do |d|
            puts d
          end

          puts value2

          update_cell(value1, value2)
        end

        @dialog.add_action_callback('getFloor') do |_action_context, value|
          
        end

        @dialog.add_action_callback('setNodeVisibility') do |_action_context, value|
          @nodes.each do |n|
            n.component.hidden = true?(value)
          end
        end

        @dialog.add_action_callback('setLinkVisibility') do |_action_context, value|
          @links.each do |l|
            l.line.hidden = true?(value)
          end
        end

        # @dialog.add_action_callback('requestLinkInfo') do |_action_context, value|
        #   node = get_node_by_name(value)

        #   return if node.nil?

        #   nodeLinks = get_links_by_node(node)

        #   link_hash = []

        #   # links.each가 안먹음 

        #   i = 0

        #   while i < nodeLinks.length() do
        #     link_hash.push(nodeLinks[i].to_hash)
        #     i += 1
        #   end

        #   # for i in nodeLinks
        #   #   link_hash.push(i.to_hash)
        #   # end
          
        #   # links.each do |ln|
        #   #   link_hash.push(ln.to_hash)
        #   # end

        #   puts link_hash
        #   @dialog.execute_script("updateLinkGrid(#{link_hash})")
        # end

        @dialog.add_action_callback('updateLink') do |_action_context, value1, value2|
          update_link_line(value1, value2)
        end

        @dialog.show
      end

      def true?(obj)
        return true if obj.to_s.downcase == 'true'

        false
      end

      def update_link_line(nodeName1, nodeName2)
        entity = Sketchup.active_model.selection.first

        if entity.nil? 
          UI.messagebox('먼저 링크로 지정할 라인을 선택해주세요.')
          return
        end

        if entity.is_a?(Edge)
          entity.all_connected.each do |e|
           unless e.is_a?(Edge)            
            UI.messagebox('라인만 가능합니다.')
            return
           end
          end
        end

        node1 = get_node_by_name(nodeName1)
        node2 = get_node_by_name(nodeName2)

        return if node1.nil? || node2.nil?

        link = get_link(node1, node2)
        
        return if link.nil?

        link.line = entity.all_connected

        UI.messagebox('링크가 업데이트 되었습니다.')
      end

      def update_node(nodeHash,oldName)
        name = nodeHash['name'];
        visible = true?(cellHash['visible'])
      end      

      def update_cell(cellHash, oldName)
        layer = cellHash['group']
        name = cellHash['name']
        visible = true?(cellHash['visible'])
        selection = cellHash['selection']

        @cells.each do |c|
          next unless c.name == oldName

          c.layer = layer
          c.name = name
          c.group.visible = visible
          break
        end
      end

      def create_floor_layer(floorHash)
        layers = @model.layers
        floorName = floorHash['name']
        new_layer = layers.add "floor layer:#{floorName}"

        @building.floors.each do |f|
          next unless f.name == floorName

          @cells.each do |c|
            c.group.layer = new_layer if f.is_in c.group
          end

          @doors.each do |d|
            next unless f.is_in d.face

            d.face.all_connected.each do |e|
              e.layer = new_layer if e.is_a?(Drawingelement)
            end
          end

          @nodes.each do |n|
            group = nil

            group = n.parent.group if n.parent.is_a?(Cell)

            n.component.layer = new_layer if f.is_in n.component
          end
        end
      end

      def show_this_cell_only(entity)
        cell = get_cell(entity)

        nil if cell.nil?

        cell_Entities = []

        cell_Entities.push entity

        puts "cell doors:#{cell.doors.length}"

        cell.doors.each do |d|

          if d.face == nil && d.group != nil
            cell_Entities.push d.group            
          elsif d.face != nil && d.group == nil
            cell_Entities.push d.face

            d.face.edges.each do |e|
              cell_Entities.push e
            end
          end

          puts "cell has door:#{d.name}"
        end

        puts "cell_entitis:#{cell_Entities.length}"

        unless cell.nil?
          entities = @model.entities

          entities.each do |e|
            e.hidden = true if cell_Entities.find_index(e).nil? && e.is_a?(Drawingelement)
          end
        end
      end

      def save_indoorgml; end

      def cell_to_hash(cell)
        return nil if cell.nil?
        {
          id: cell.id,
          name: cell.name,
          type: cell.get_cell_type_name,
          group: cell.layer,
          visible: cell.group.visible?
        }
      end

      def door_to_hash(door)
        return nil if door.nil?

        {
          name: door.name,
          type: door.get_door_type_name
        }
      end

      def node_to_hash(node)
        return nil if node.nil?

        {
          id: node.id,
          name: node.name,
          type: node.get_node_type_name,
          group: node.layer,
          x: node.position.x.to_f,
          y: node.position.y.to_f,
          z: node.position.z.to_f
        }
      end

      def poi_to_hash(poi)
        return nil if poi.nil?

        {
          id: poi.id,
          name: poi.name,
          type: poi.get_poi_type_name,
          x: poi.position.x.to_f,
          y: poi.position.y.to_f,
          z: poi.position.z.to_f
        }
      end

      def create_sphere(center, radius, material)
        model = Sketchup.active_model # why keep switching between model and

        # create operation, which can be undone
        # model.start_operation "Sphere"
        compdef = Sketchup.active_model.definitions.add # needed 's'

        # multiple places show confusion between an Entity and its Entities collection
        ents = compdef.entities

        circle = ents.add_circle center, [0, 0, 1], radius
        circle_face = ents.add_face circle

        circle_face.material = material
        path = ents.add_circle center, [0, 1, 0], radius + 1

        circle_face.followme path
        ents.erase_entities path

        trans = Geom::Transformation.new
        instance = Sketchup.active_model.active_entities.add_instance(compdef, trans)
        instance.material = material

        # model.commit_operation

        instance
      end

      # Cell, door, node, link를 자동 생성
      def create_all
        puts 'Start Time:   ' + Time.now.to_s
        # cell 생성
        entities = @model.active_entities

        # face와 Group만 옮긴다. (entities를 직접 쓰면 entity가 도중에 추가 되었을 경우 에러 발생)
        faceAndGroups = []

        entities.each do |e|
          faceAndGroups.push e if e.is_a?(Face) || e.is_a?(Group) || e.is_a?(ComponentInstance)
        end

        counter = 0
        faceAndGroups.each do |fg|
          if fg.is_a?(ComponentInstance)
            if fg.layer.name.include?("RM")
              create_cell(fg) if !fg.deleted? && !fg.hidden?
            else
              fg.hidden = true
            end
          else
            create_cell(fg) if !fg.deleted? && !fg.hidden?
          end      
          # puts 'create_cell ' + counter + ' ' + faceAndGroups.length() + '\n'
          counter += 1  
        end
        puts 'create_cell Time:   ' + Time.now.to_s
        # door 생성
        # entities 갱신
        entities = @model.active_entities

        faces = []

        # face 만 array로 옮긴다. (entities를 직접 쓰면 entity가 도중에 추가 되었을 경우 에러 발생)
        entities.each do |e|
          faces.push e if e.is_a?(Face)
        end

        faces.each do |f|
          @cells.each do |c|
            unless c.group.deleted?
              group_face = get_face_layon_group c.group, f
              create_door f unless group_face.nil?
            end
          end
        end

        puts 'create_door Time:   ' + Time.now.to_s
        # node link 갱신
        @nodes.each do |n|
          next unless n.parent.is_a?(Cell)

          result = get_intersected_cells(n.parent)

          result.each do |c|
            # link가 존재하지 않는다면 link를 생성
            next if is_link_exist(c.node, n)

            link = create_link c.node, n

            @links.push link unless link.nil?
          end
        end

        puts 'Node link Time:   ' + Time.now.to_s
      end

      # 겹쳐진 cell 찾기
      def get_intersected_cells(cell)
        intersected = []

        @cells.each do |c|
          result = c.group.bounds.intersect(cell.group.bounds)

          intersected.push c unless result.empty?
        end

        intersected
      end

      # group가 door이 될수 있는지 판별
      def can_transform_door(group); end

      # 모든 indoorgml element를 삭제한다 (Node와 link를 제외한 geometry 객체는 삭제하지 않는다.)
      def clear_all
        @cells.each do |c|
        end
      end

      # 선택된 객체의 정보를 dialog로 업데이트 한다.
      def update_dialog
        return if @dialog.nil?

        cell_data = nil
        model = Sketchup.active_model

        if model.selection.size == 1
          entity = model.selection.first
          case @edit_mode
          when EditMode::CELL
            if entity.is_a?(Group)
              cell = get_cell(entity)

              return if cell.nil?
              
              puts "cell:#{cell}"

              cell_data = cell_to_hash(cell)
              json = cell_data ? JSON.pretty_generate(cell_data) : 'null'
              puts json
              @dialog.execute_script("updateCellDialogProperty(#{json})")
              # @dialog.execute_script("updateCellDialogProperty(#{cell.id})")

              cell_hash = []

              @cells.each do |c|
                cell_hash.push(cell_to_hash(c))
              end

              json2 = cell_hash ? JSON.pretty_generate(cell_hash) : 'null'

              @dialog.execute_script("updateCellGrid(#{json2})")
            else
              # 선택 하지 않았을 경우 빈 내용으로 다이얼로그를 만든다.
              json = ''
              @dialog.execute_script("updateCellDialogProperty(#{json})")
            end
          when EditMode::NODE
            if entity.is_a?(ComponentInstance)

              node = get_node(entity)

              return if node.nil?

              node_data = node_to_hash(node)
              json = node ? JSON.pretty_generate(node_data) : 'null'
              @dialog.execute_script("updateNode(#{json})")             
              
              node_hash = []

              @nodes.each do |n|
                node_hash.push(node_to_hash(n))
              end

              json2 = node_hash ? JSON.pretty_generate(node_hash) : 'null'
              @dialog.execute_script("updateNodeGrid(#{json2})")              


              link_hash = []
              @links.each do |l|
                link_hash.push(l.to_hash)
              end
              json3 = link_hash ? JSON.pretty_generate(link_hash) : 'null'
              @dialog.execute_script("updateLink(#{json3})")
            else
              json = 'null'
              @dialog.execute_script("updateNode(#{json})")
            end
          when EditMode::POI
            if entity.is_a?(ComponentInstance)
              poi = get_poi(entity)
              poi_data = poi_to_hash(poi)

              json = poi_data ? JSON.pretty_generate(poi_data) : 'null'
              @dialog.execute_script("updatePoi(#{json})")

              poi_hash = []

              @pois.each do |p|
                poi_hash.push(poi_to_hash(p))
              end

              json2 = poi_hash ? JSON.pretty_generate(poi_hash) : 'null'
              @dialog.execute_script("updatePoiGrid(#{json2})")
            else
              json = 'null'
              @dialog.execute_script("updatePoi(#{json})")
            end
          when EditMode::DOOR
            if entity.is_a?(Face) || entity.is_a?(Group)
              door = get_door(entity) # face가 이미 door일 경우 존재하는 door를 반환한다.
              puts door
              door_data = door_to_hash(door)
              json = door_data ? JSON.pretty_generate(door_data) : 'null'
              puts json
              @dialog.execute_script("updateDoor(#{json})")
            else
              json = 'null'
              @dialog.execute_script("updateDoor(#{json})")
            end
          when EditMode::FLOOR
            floor_data = @building.to_hash
            json = floor_data ? JSON.pretty_generate(floor_data) : 'null'
            @dialog.execute_script("updateFloor(#{json})")


          end
        end
      end # update_dialog

      def export_indoorgml
        base = UI.savepanel('Save IndoorGml File', '~', 'IndoorGml Files|*.gml;||')
        basename = File.dirname(base) + '/' + File.basename(base, '.*')

        puts base

        $data = ''

        @cells.each do |c|
          $data.concat("cell\n")
          $data.concat("$$$$\n")
          $data.concat("#{c.name}\n")
          $data.concat("$$$$\n")
          # vertices
          c.group.entities.each do |e|
            next unless e.is_a?(Face)

            e.outer_loop.vertices.each do |v|
              p = v.position.transform(c.group.transformation)
              # p = v.position
              $data.concat("#{p.x.to_f},#{p.z.to_f},#{p.y.to_f},")
            end

            p = e.outer_loop.vertices[0].position.transform(c.group.transformation)

            $data.concat("#{p.x.to_f},#{p.z.to_f},#{p.y.to_f}")

            $data.concat('*')
          end

          $data.concat("\n$$$$\n")
          $data.concat("#{c.node.name}\n")
          $data.concat("$$$$\n")
          p = c.node.component.bounds.center.transform(c.group.transformation)
          $data.concat("#{p.x.to_f},#{p.z.to_f},#{p.y.to_f}\n")

          # @cells.each do |c1|
          #   $data.concat(c1.node.name.to_s) if is_link_exist(c.node, c1.node)
          # end

          $data.concat("####\n")
        end

        door_counter = 0;

        @doors.each do |d|
          $data.concat("door\n")
          $data.concat("$$$$\n")
          $data.concat("door_base_#{door_counter}\n")
          $data.concat("$$$$\n")
          # vertices
          # if d.face.nil?
          #   d.group.entities.each do |e|
          #     next unless e.is_a?(Face)
  
          #     e.outer_loop.vertices.each do |v|
          #       p = v.position
          #       $data.concat("#{p.x.to_f},#{p.y.to_f},#{p.z.to_f},")
          #     end
          #     $data.concat('*')
          #   end
          # elsif d.group.nil?
          #   if d.face.deleted?
          #     d.update_door_face
          #   end

          #   d.face.outer_loop.vertices.each do |v|
          #     p = v.position
          #     $data.concat("#{p.x.to_f},#{p.y.to_f},#{p.z.to_f},")
          #   end
          #   # face의 끝
          #   $data.concat('*')
          # end          
          #$data.concat("$$$$\n")
          $data.concat("#{d.node.name}\n")
          $data.concat("$$$$\n")
          p = d.node.component.bounds.center
          $data.concat("#{p.x.to_f},#{p.z.to_f},#{p.y.to_f} ")

          # @cells.each do |c1|
          #   $data.concat(c1.name.to_s) if is_link_exist(c, c1)
          # end

          $data.concat("####\n")
        end

        puts $data
        File.write('C:\\Users\\Public\\Documents\\temp_indoorgml.txt', $data)
        system('C:\\Users\\Public\\Documents\\IndoorGmlConverter.exe', base)
        # system('C:\\Users\\apple\\Documents\\Visual Studio 2017\\Projects\\IndoorGmlConverter\\IndoorGmlConverter\\bin\\Debug\\IndoorGmlConverter.exe', base)
      end

      # MAIN PROCEDURE ------------------------------------------------------------------------
      def indoorgml_import
        indoorgml_import_init
        @@model.start_operation('Import IndoorGml File', true)
        indoorgml_import_get_input
        t1 = Time.now
        puts 'Start Time: ' + @@timestamp.to_s
        import_indoor_gml_geometry
        puts 'Created:    ' + @@poly_count.to_s
        @@model.commit_operation
        puts 'End Time:   ' + Time.now.to_s
        t2 = Time.now
        UI.messagebox("Elapsed time:#{(t2-t1)} sec")
      end

      # INITIALIZE DATA -----------------------------------------------------------------------
      def indoorgml_import_init
        @@model = Sketchup.active_model
        @@timestamp = Time.now
        @@scale = 1.0
        @@poly_count = 0
        @@display_bb = 'No'
        @@name = @@timestamp.strftime('%Y%m%d%H%M%S')
        @@bbox = []
        @@xnode = {}
        @@ynode = {}
      end

      # GET USER INPUT ------------------------------------------------------------------------
      def indoorgml_import_get_input
        base = UI.openpanel('Select IndoorGml File', '~', 'IndoorGml Files|*.gml;||')
        #        base = UI.openpanel("Select IndoorGml File", "%HOMEPATH%", "IndoorGml Files|*.gml;||")
        #        UI.messagebox(base)
        @@basename = File.dirname(base) + '/' + File.basename(base, '.*')
        #        puts @@basename
        #        UI.messagebox(@@basename)
        puts 'Parsing XML File ...'
        indoorgml_import_get_data
        prompts = ['Name: ', 'Scale: ', 'Display BB: ']
        defaults = [@@name, @@scale, 'No']
        list = ['', '', 'No|Yes']
        input = UI.inputbox prompts, defaults, list, 'Enter Import Parameters:'
        @@name = input[0]
        @@scale = input[1].to_f
        @@display_bb = input[2]
      end

      # IMPORT INDOORGML ----------------------------------------------------------------------
      def import_indoor_gml_geometry
        #        @@model.start_operation("Import IndoorGml File",true)
        @@xmldoc.elements.each('.//CellSpace') do |csg|
          id = csg.attributes['gml:id']
          group = @@model.entities.add_group
          group.name = id
          csg.elements.each('.//gml:LinearRing') do |csm|
            pts = []
            csm.elements.each('.//gml:pos') do |ps|
              values = ps.text.split(' ')
              if values.length == 3
                pts.push(Geom::Point3d.new(values[0].to_f * @@scale, values[1].to_f * @@scale, values[2].to_f * @@scale))
              end
            end

            begin
              face = group.entities.add_face(pts)
              @@poly_count += 1
            rescue StandardError => e
            else
            ensure
            end
          end

          next if group.nil?

          group.material = Color.new('red')
          group.material.alpha = 0.3
          
          if group.name.include? "Door_Base"
            create_door(group)
          elsif group.name.include? "door_"
            create_door(group)
          else
            create_cell(group)
          end
        end

        # @@xmldoc.elements.each(".//Transition") do |trs|
        #   pts = []
        #   trs.elements.each(".//gml:pos") do |ps|
        #     values = ps.text.split(" ")
        #     if(values.length() == 3)
        #         pts.push(Geom::Point3d.new((values[0].to_f) * @@scale ,(values[1].to_f) * @@scale,(values[2].to_f) * @@scale))
        #     end
        #   end

        #   if pts.length == 2
        #     create_sphere(pts[0],0.5 / 1.to_m,Color.new("blue"))
        #     create_sphere(pts[1],0.5 / 1.to_m,Color.new("blue"))
        #     Sketchup.active_model.entities.add_cline(pts[0], pts[1])
        #   end
        # end

        # GET SHAPEFILE DATA --------------------------------------------------------------------

        #        @@model.commit_operation
      end

      def indoorgml_import_get_data
        file = @@basename + '.gml'
        #        UI.messagebox
        xmlfile = File.new(file)
        @@xmldoc = Document.new(xmlfile)
      end
    end # class << self

    # create toolbar
    def self.create_step(fileName, title, &block)
      cmd = UI::Command.new(title, &block)
      cmd.tooltip = title
      ext = 'png'
      # https://www.flaticon.com/free-icons/numbers_931
      icon = File.join(__dir__, 'images', "#{fileName}.#{ext}")
      cmd.small_icon = icon
      cmd.large_icon = icon
      cmd
    end

    initialize_data

    item_create_cell = create_step('cell_space', 'Create Cell Space') do
      # entity = Sketchup.active_model.selection.first
      # if entity.is_a?(Face)
      #     create_cell(entity)
      # end
      self.edit_mode = EditMode::CELL
      show_dialog
    end

    toolbar = UI::Toolbar.new('IndoorGML')
    toolbar.add_item(item_create_cell)

    item_create_poi = create_step('poi', 'Create Poi') do
      # entity = Sketchup.active_model.selection.first
      self.edit_mode = EditMode::POI
      show_dialog
    end
    toolbar.add_item(item_create_poi)

    item_create_door = create_step('door', 'Create Door') do
      # entity = Sketchup.active_model.selection.first
      self.edit_mode = EditMode::DOOR
      show_dialog
    end
    toolbar.add_item(item_create_door)

    item_create_node = create_step('node', 'Create Node') do
      # entity = Sketchup.active_model.selection.first
      self.edit_mode = EditMode::NODE
      show_dialog
    end
    toolbar.add_item(item_create_node)

    item_create_all = create_step('create_all', 'Create All') do
      # entity = Sketchup.active_model.selection.first
      self.edit_mode = EditMode::NONE
      create_all
    end
    toolbar.add_item(item_create_all)

    item_floor = create_step('floor2', 'Manage floor') do
      self.edit_mode = EditMode::FLOOR
      show_dialog
    end
    toolbar.add_item(item_floor)

    Sketchup.add_observer(AppObserver.new) unless file_loaded?(__FILE__)
  end # module IndoorGmlModeler
end
