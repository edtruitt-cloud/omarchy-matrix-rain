import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ertiv.matrix-rain"

  readonly property string pluginId: "ertiv.matrix-rain"
  readonly property var service: (bar && bar.shell) ? bar.shell.serviceFor(pluginId) : null

  property bool opened: false
  property bool popoutSwitchClosing: false

  function open() { opened = true }
  function close() { opened = false }
  function toggle() { opened = !opened }

  readonly property bool isOn: !!service && service.enabled && !service.manualPaused
  readonly property color iconColor: !service ? Color.muted
                                   : isOn ? Color.accent
                                   : Color.muted

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "ア"
    tooltipText: "Matrix Rain"
    useActiveColor: false
    foreground: root.iconColor
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (service) service.applyToggle()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: kpanel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: kpanel.fittedContentWidth(Style.space(800))
    contentHeight: kpanel.fittedContentHeight(contentLoader.item ? contentLoader.item.implicitHeight : Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Loader {
        id: contentLoader
        anchors.fill: parent
        source: "Panel.qml"
        onLoaded: {
          if (!item) return
          item.widget = root
          item.bar = root.bar
        }
      }
    }
  }
}
