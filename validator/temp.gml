﻿<?xml version="1.0" encoding="UTF-8"?>
<IndoorFeatures xmlns:core="http://www.opengis.net/indoorgml/1.0/core" xmlns:gml="http://www.opengis.net/gml/3.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xlink="http://www.w3.org/1999/xlink" xsi:schemaLocation="http://www.opengis.net/indoorgml/1.0/core/indoorgmlcore.xsd" gml:id="http://www.gml.com/test">
  <core:primalSpaceFeatures>
    <core:PrimalSpaceFeatures gml:id="PS1" />
    <core:CellSpaceMember>
      <core:CellSpace gml:id="cell_cell_0">
        <core:CellSpaceGeometry>
          <core:Geometry3D>
            <gml:Solid gml:id="solid_cell_0">
              <gml:exterior>
                <gml:Shell>
                  <gml:surfaceMember>
                    <gml:Polygon gml:id="polygon_0_cell_0">
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:pos>-260.1098 -47.98612 0</gml:pos>
                          <gml:pos>190.2839 -47.98612 0</gml:pos>
                          <gml:pos>190.2839 -47.98612 99.6063</gml:pos>
                          <gml:pos>-260.1098 -47.98612 99.6063</gml:pos>
                          <gml:pos>-260.1098 -47.98612 0</gml:pos>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                  <gml:surfaceMember>
                    <gml:Polygon gml:id="polygon_1_cell_0">
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:pos>190.2839 -47.98612 0</gml:pos>
                          <gml:pos>190.2839 507.9194 0</gml:pos>
                          <gml:pos>190.2839 507.9194 99.6063</gml:pos>
                          <gml:pos>190.2839 -47.98612 99.6063</gml:pos>
                          <gml:pos>190.2839 -47.98612 0</gml:pos>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                  <gml:surfaceMember>
                    <gml:Polygon gml:id="polygon_2_cell_0">
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:pos>-260.1098 -47.98612 0</gml:pos>
                          <gml:pos>-260.1098 507.9194 0</gml:pos>
                          <gml:pos>190.2839 507.9194 0</gml:pos>
                          <gml:pos>190.2839 -47.98612 0</gml:pos>
                          <gml:pos>-260.1098 -47.98612 0</gml:pos>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                  <gml:surfaceMember>
                    <gml:Polygon gml:id="polygon_3_cell_0">
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:pos>-260.1098 507.9194 0</gml:pos>
                          <gml:pos>-260.1098 -47.98612 0</gml:pos>
                          <gml:pos>-260.1098 -47.98612 99.6063</gml:pos>
                          <gml:pos>-260.1098 507.9194 99.6063</gml:pos>
                          <gml:pos>-260.1098 507.9194 0</gml:pos>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                  <gml:surfaceMember>
                    <gml:Polygon gml:id="polygon_4_cell_0">
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:pos>190.2839 507.9194 0</gml:pos>
                          <gml:pos>-260.1098 507.9194 0</gml:pos>
                          <gml:pos>-260.1098 507.9194 99.6063</gml:pos>
                          <gml:pos>190.2839 507.9194 99.6063</gml:pos>
                          <gml:pos>190.2839 507.9194 0</gml:pos>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                  <gml:surfaceMember>
                    <gml:Polygon gml:id="polygon_5_cell_0">
                      <gml:exterior>
                        <gml:LinearRing>
                          <gml:pos>-260.1098 507.9194 99.6063</gml:pos>
                          <gml:pos>-260.1098 -47.98612 99.6063</gml:pos>
                          <gml:pos>190.2839 -47.98612 99.6063</gml:pos>
                          <gml:pos>190.2839 507.9194 99.6063</gml:pos>
                          <gml:pos>-260.1098 507.9194 99.6063</gml:pos>
                        </gml:LinearRing>
                      </gml:exterior>
                    </gml:Polygon>
                  </gml:surfaceMember>
                </gml:Shell>
              </gml:exterior>
            </gml:Solid>
          </core:Geometry3D>
        </core:CellSpaceGeometry>
      </core:CellSpace>
    </core:CellSpaceMember>
  </core:primalSpaceFeatures>
  <core:multiLayeredGraph>
    <core:MultiLayeredGraph gml:id="MG1">
      <core:spaceLayers gml:id="SL1">
        <core:spaceLayerMember>
          <core:SpaceLayer gml:id="IS1">
            <core:nodes gml:id="N1">
              <core:stateMember>
                <core:State gml:id="state_node_0">
                  <gml:name>cell_0</gml:name>
                  <core:duality xlink:href="cell_cell_0" />
                  <core:geometry>
                    <gml:Point id="P0">
                      <gml:pos>-34.91294 229.9666 49.80315</gml:pos>
                    </gml:Point>
                  </core:geometry>
                </core:State>
              </core:stateMember>
            </core:nodes>
            <edges gml:id="E1" />
          </core:SpaceLayer>
        </core:spaceLayerMember>
      </core:spaceLayers>
    </core:MultiLayeredGraph>
  </core:multiLayeredGraph>
</IndoorFeatures>