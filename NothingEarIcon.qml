import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property real iconSize: 16
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real fit: iconSize / 56

  Shape {
    width: 56
    height: 56
    transform: [
      Scale { xScale: root.fit; yScale: root.fit },
      Translate {
        x: (root.iconSize - 56 * root.fit) / 2
        y: (root.iconSize - 56 * root.fit) / 2
      }
    ]
    preferredRendererType: Shape.CurveRenderer
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(width * root.fit * 3, height * root.fit * 3)

    ShapePath {
      fillColor: root.color
      strokeWidth: -1
      fillRule: ShapePath.WindingFill
      // Nothing Ear (a) simplified outline: stem-style earbuds with rounded bodies
      PathSvg {
        path: "M28 8c-6 0-11 3-14 8c-2 3-3 7-3 11c0 2 0 4 1 6l2 4c1 2 2 3 4 4l2 1c1 0 2 1 2 2v6c0 1 1 2 2 2h2c1 0 2-1 2-2v-6c0-1 1-2 2-2l2-1c2-1 3-2 4-4l2-4c1-2 1-4 1-6c0-4-1-8-3-11c-3-5-8-8-14-8zm-16 13c0-4 2-8 5-10c3-3 7-4 11-4s8 1 11 4c3 2 5 6 5 10c0 3-1 5-2 7l-2 4c-1 1-1 2-2 3l-2 1h-6l-2-1c-1-1-2-2-2-3l-2-4c-1-2-2-4-2-7z"
      }
    }
  }
}
