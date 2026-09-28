import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Rectangle {
  id: panel
  property var widget: null
  property QtObject bar: null
  color: Color.popups.background
  implicitWidth: Style.space(800)
  implicitHeight: 780

  Flickable {
    id: rainScroll
    anchors.fill: parent
    contentHeight: rain.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    RainPanel { id: rain; width: rainScroll.width; widget: panel.widget; bar: panel.bar }
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
  }
}
