require 'sketchup.rb'
require 'json'

include Sketchup

module RodemSoft
    class << self        
        def RunUnity
            entity = Sketchup.active_model.selection.first

            if entity.nil?
                UI.messagebox('평면을 선택해주세요.')
                return
            end

            $data =""

            if entity.is_a?(Group)
                entity.entities.each do |e|
                    if e.is_a?(Face)
                        e.outer_loop.vertices.each do |v|
                            p = v.position
                            $data.concat("#{p.x.to_f},#{p.y.to_f},#{p.z.to_f}\n")
                        end
                        $data.concat("@@@\n")                        
                    end
                end
            end    
            
            puts $data

            File.write('C:\\Users\\Public\\Documents\\border.txt', $data)
            system('C:\\Users\\apple\\Documents\\Unity\\ProceduralBuildingGeneration\\exe\\ProceduralBuildingGeneration.exe','')
        end
    end

    unless file_loaded?("create_broder.rb")
        menu = UI.menu("PlugIns").add_item("Create border") { RunUnity() }
        file_loaded("create_broder.rb")
      end
end