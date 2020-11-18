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
            entity.outer_loop.vertices.each do |v|
                p = v.position
                $data.concat("#{p.x},#{p.y},#{p.z}\n")
            end

            File.write('C:\\Users\\Public\\Documents\\border.txt', $data)
            system('.\\FloorPlanGenerator\\FloorPlanGenerator.exe','')
        end
    end

    unless file_loaded?("create_broder.rb")
        menu = UI.menu("PlugIns").add_item("룸 생성기 실행") { RunUnity() }
        file_loaded("create_broder.rb")
      end
end