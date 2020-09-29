# (C) 2015 by Aqualung - Permission granted to freely use this code as long
# as this line and the preceding line are included in any derivative work(s)
#
# indoorgml_importer.rb
#
# Import IndoorGml
#
# version 1.0 (beta) - December 2, 2015 - Initial release of working version
# version 1.1 (beta) - April 2, 2020 - Converted for parsing IndoorGml by Young
#----------------------------------------------------------------------------------------
require 'sketchup.rb'
require 'rexml/document'
include REXML
# include REXML - moved into class module per @DanRathbun's suggestion
#----------------------------------------------------------------------------------------
module UNES
  module IndoorGmlImporter
    include REXML
# MAIN BODY -----------------------------------------------------------------------------
    class << self
# MAIN PROCEDURE ------------------------------------------------------------------------
      def indoorgml_import()
        indoorgml_import_init()
        @@model.start_operation("Import IndoorGml File",true)
        indoorgml_import_get_input()
        puts "Start Time: " + @@timestamp.to_s
        import_indoor_gml_geometry()
        puts "Created:    " + @@poly_count.to_s
        @@model.commit_operation
        puts "End Time:   " + Time.now.to_s
      end
# INITIALIZE DATA -----------------------------------------------------------------------
      def indoorgml_import_init()
        @@model = Sketchup.active_model
        @@timestamp = Time.now
        @@scale = 1.0
        @@poly_count = 0
        @@display_bb = "No"
        @@name = @@timestamp.strftime("%Y%m%d%H%M%S")
        @@bbox = []
        @@xnode = Hash.new
        @@ynode = Hash.new
      end
# GET USER INPUT ------------------------------------------------------------------------
      def indoorgml_import_get_input()
        base = UI.openpanel("Select IndoorGml File", "~", "IndoorGml Files|*.gml;||")
#        base = UI.openpanel("Select IndoorGml File", "%HOMEPATH%", "IndoorGml Files|*.gml;||")
#        UI.messagebox(base)
        @@basename = File.dirname(base) + '/' + File.basename(base,".*")
#        puts @@basename
#        UI.messagebox(@@basename)
        puts "Parsing XML File ..."
        indoorgml_import_get_data()
        prompts = ["Name: ","Scale: ","Display BB: "]
        defaults = [@@name,@@scale,"No"]
        list = ["","","No|Yes"]
        input = UI.inputbox prompts, defaults, list, "Enter Import Parameters:"
        @@name = input[0]
        @@scale = input[1].to_f
        @@display_bb = input[2]
      end
# IMPORT INDOORGML ----------------------------------------------------------------------
      def import_indoor_gml_geometry()        
#        @@model.start_operation("Import IndoorGml File",true)
        @@xmldoc.elements.each(".//CellSpace") do |csg|
            id = csg.attributes["gml:id"]
            group = @@model.entities.add_group
            group.name = id
            csg.elements.each(".//gml:LinearRing") do |csm|
                pts = []            
                csm.elements.each(".//gml:pos") do |ps|
                    values = ps.text.split(" ")
                    if(values.length() == 3) 
                        pts.push(Geom::Point3d.new((values[0].to_f) * @@scale ,(values[1].to_f) * @@scale,(values[2].to_f) * @@scale))
                    end
                end

                begin
                    face = group.entities.add_face(pts)
                    @@poly_count = @@poly_count+1
                    rescue => e
                    else                      
                    ensure
                end    
            end

            if group != nil
              group.material = Color.new("red")
              group.material.alpha = 0.3
            end            
        end   
        
        @@xmldoc.elements.each(".//Transition") do |trs|
          pts = []            
          trs.elements.each(".//gml:pos") do |ps|
            values = ps.text.split(" ")
            if(values.length() == 3) 
                pts.push(Geom::Point3d.new((values[0].to_f) * @@scale ,(values[1].to_f) * @@scale,(values[2].to_f) * @@scale))
            end
          end

          if pts.length == 2
            create_sphere(pts[0],0.5 / 1.to_m,Color.new("blue"))
            create_sphere(pts[1],0.5 / 1.to_m,Color.new("blue"))
            Sketchup.active_model.entities.add_cline(pts[0], pts[1])
          end
        end

#        @@model.commit_operation
      end
# GET SHAPEFILE DATA --------------------------------------------------------------------
      def indoorgml_import_get_data()
        include REXML
        file = @@basename + '.gml'
#        UI.messagebox
        xmlfile = File.new(file)
        @@xmldoc = Document.new(xmlfile)
      end

      def create_sphere(center,radius,material)

        model = Sketchup.active_model # why keep switching between model and
      
        # create operation, which can be undone
        model.start_operation "Sphere"
        compdef = Sketchup.active_model.definitions.add # needed 's'
      
        # multiple places show confusion between an Entity and its Entities collection
        ents = compdef.entities
      
        circle = ents.add_circle center, [0, 0, 1], radius
        circle_face = ents.add_face circle
      
        circle_face.material=material
        path = ents.add_circle center, [0, 1, 0], radius+1
      
        circle_face.followme path
        ents.erase_entities path
      
        trans=Geom::Transformation.new
        instance = Sketchup.active_model.active_entities.add_instance(compdef, trans)
        instance.material = material
      
        model.commit_operation

        return instance
      end
    end
#----------------------------------------------------------------------------------------
    unless file_loaded?("IndoorGmlParser.rb")
      menu = UI.menu("PlugIns").add_item("Import IndoorGml File2") { indoorgml_import() }
      file_loaded("IndoorGmlParser.rb")
    end
#----------------------------------------------------------------------------------------
  end
end