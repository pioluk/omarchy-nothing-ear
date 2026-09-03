import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.pioluk.omnothingear"
  ipcTarget: "omnothingear"
  manageIpc: false

  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", true) === true
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color barIconColor: pods.hasEarbuds ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool guidanceVisible: !pods.hasEarbuds && !pods.hasBattery && !pods.schemaUnsupported

  property int phraseIndex: 0

  readonly property int lowBatteryPercent: 20
  readonly property int phraseIntervalMs: 2800

  readonly property var activePhrases: [
    "Nothing's perfect",
    "Ear to the ground",
    "Sound and vision",
    "Listening intently",
    "Crystal clear",
    "Bass dropping low",
    "Silence is golden",
    "Transparency mode engaged",
    "Noise? What noise?",
    "Ears wide open"
  ]
  readonly property string heroPhraseText: activePhrases[phraseIndex % activePhrases.length]
  readonly property string heroMetaText: {
    var parts = []
    parts.push("ANC: " + Model.ancModeName(pods.ancMode))
    parts.push("EQ: " + Model.eqPresetName(pods.eqPreset))
    return parts.join(" · ")
  }

  readonly property bool ancVisible: pods.hasEarbuds
  readonly property bool eqVisible: pods.hasEarbuds
  readonly property bool modesVisible: pods.hasEarbuds
  readonly property bool lowLatencyVisible: pods.hasEarbuds

  readonly property var cursorRows: {
    var rows = []
    if (!pods.hasEarbuds) return rows
    for (var i = 0; i < ancModes.length; i++) rows.push("anc:" + ancModes[i])
    for (var j = 0; j < eqPresets.length; j++) rows.push("eq:" + eqPresets[j])
    rows.push("inEar")
    rows.push("lowLatency")
    return rows
  }

  readonly property var ancModes: [Model.ANC_OFF, Model.ANC_LOW, Model.ANC_MID, Model.ANC_HIGH, Model.ANC_ADAPTIVE, Model.ANC_TRANSPARENCY]
  readonly property var eqPresets: [Model.EQ_BALANCED, Model.EQ_MORE_BASS, Model.EQ_MORE_TREBLE, Model.EQ_VOICE]

  readonly property string cursorRow: cursorRows.length === 0
    ? ""
    : cursorRows[Math.max(0, Math.min(cursorIndex, cursorRows.length - 1))]

  function rowHasCursor(name) {
    return cursorActive && cursorRow === name
  }

  function moveCursor(dy) {
    cursorActive = true
    if (cursorRows.length === 0) return
    cursorIndex = Math.max(0, Math.min(cursorRows.length - 1, cursorIndex + dy))
  }

  function activateCursor() {
    var name = cursorRow
    if (name.indexOf("anc:") === 0) pods.setAncMode(parseInt(name.substring(4), 10))
    else if (name.indexOf("eq:") === 0) pods.setEqPreset(parseInt(name.substring(3), 10))
    else if (name === "inEar") pods.cycleEarDetection()
    else if (name === "lowLatency") pods.setLowLatencyMode(!pods.lowLatencyMode)
  }

  function focusRow(name) {
    var at = cursorRows.indexOf(name)
    if (at < 0) return
    cursorActive = true
    cursorIndex = at
  }

  visible: !hideWhenDisconnected || pods.hasEarbuds || pods.hasBattery
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    if (panelFlick) panelFlick.contentY = 0
    pods.refresh()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: pods
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { pods.refresh(); return "ok" }
    function anc(): string { pods.cycleAncMode(); return "ok" }
    function status(): string { return Model.ancModeName(pods.ancMode) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        NothingEarIcon {
          anchors.centerIn: parent
          iconSize: Style.space(13)
          color: root.barIconColor
        }
      }
    }
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) pods.cycleAncMode()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        var key = String(t).toLowerCase()
        if (key === "r") pods.refresh()
        else if (!pods.hasEarbuds) return
        else if (key === "o") pods.setAncMode(Model.ANC_OFF)
        else if (key === "l") pods.setAncMode(Model.ANC_LOW)
        else if (key === "m") pods.setAncMode(Model.ANC_MID)
        else if (key === "h") pods.setAncMode(Model.ANC_HIGH)
        else if (key === "a") pods.setAncMode(Model.ANC_ADAPTIVE)
        else if (key === "t") pods.setAncMode(Model.ANC_TRANSPARENCY)
        else if (key === "e") pods.cycleEqPreset()
        else if (key === "d") pods.cycleEarDetection()
        else if (key === "g") pods.setLowLatencyMode(!pods.lowLatencyMode)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: pods.modelName !== "" ? pods.modelName : (pods.deviceName !== "" ? pods.deviceName : "Nothing Ear")
            meta: pods.hasEarbuds ? root.heroMetaText
              : pods.schemaUnsupported ? "Unsupported status schema"
              : pods.daemonReachable ? "Not connected"
              : "nothingear daemon is not running"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: pods.hasEarbuds ? 1.0 : 0.5
            iconComponent: Component {
              NothingEarIcon {
                iconSize: Style.font.displayLarge
                color: pods.hasEarbuds ? root.foreground : root.dim
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: pods.actionStatus !== "" || (pods.lastError !== "" && pods.daemonReachable)
            width: parent.width
            text: pods.actionStatus !== "" ? pods.actionStatus : pods.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: pods.hasEarbuds || pods.hasBattery
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "BATTERY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              PodRow {
                width: parent.width
                label: "Left"
                pod: pods.leftPod
                meta: pods.leftPod.level === Model.LEVEL_UNKNOWN ? "Unknown" : ""
              }
              PodRow {
                width: parent.width
                label: "Right"
                pod: pods.rightPod
                meta: pods.rightPod.level === Model.LEVEL_UNKNOWN ? "Unknown" : ""
              }
              PodRow {
                width: parent.width
                label: "Case"
                pod: ({ level: pods.caseBattery.level, charging: pods.caseBattery.charging, inEar: false })
                meta: pods.caseBattery.level === Model.LEVEL_UNKNOWN ? "Unknown" : ""
              }
            }
          }

          PanelSeparator {
            visible: pods.hasEarbuds
            foreground: root.foreground
          }

          Column {
            visible: root.ancVisible
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "NOISE CONTROL"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.ancModes
                AncModeRow {
                  required property var modelData
                  width: parent.width
                  mode: modelData
                }
              }
            }
          }

          PanelSeparator {
            visible: root.eqVisible
            foreground: root.foreground
          }

          Column {
            visible: root.eqVisible
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "EQUALIZER"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.eqPresets
                EqPresetRow {
                  required property var modelData
                  width: parent.width
                  preset: modelData
                }
              }
            }
          }

          PanelSeparator {
            visible: pods.hasEarbuds
            foreground: root.foreground
          }

          Column {
            visible: pods.hasEarbuds
            width: parent.width
            spacing: Style.space(6)

            ToggleRow {
              width: parent.width
              rowName: "inEar"
              label: "In-ear detection"
              caption: "Pause when earbuds are removed"
              checked: pods.inEarDetection
              onToggled: pods.setInEarDetection(!pods.inEarDetection)
            }

            ToggleRow {
              width: parent.width
              rowName: "lowLatency"
              label: "Low latency mode"
              caption: "Reduce audio delay for gaming"
              checked: pods.lowLatencyMode
              onToggled: pods.setLowLatencyMode(!pods.lowLatencyMode)
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.guidanceVisible
            width: parent.width
            text: pods.daemonReachable
              ? "Connect your Nothing Ear to see battery and controls."
              : "Start the nothingear daemon to see battery and controls."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  Timer {
    id: phraseTimer
    interval: root.phraseIntervalMs
    running: root.opened && pods.hasEarbuds
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  component PodRow: Item {
    id: podRow
    property string label: ""
    property var pod: Model.defaultPod()
    property string meta: ""

    readonly property string metaText: meta !== "" ? meta : Model.podMeta(pod)
    readonly property bool low: pod.level !== Model.LEVEL_UNKNOWN
      && pod.level <= root.lowBatteryPercent && !pod.charging

    implicitHeight: podLayout.implicitHeight

    RowLayout {
      id: podLayout
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: podRow.label
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.preferredWidth: Math.max(Style.space(44), implicitWidth + Style.space(10))
      }

      Rectangle {
        id: meterTrack
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: Style.space(6)
        radius: height / 2
        color: Qt.darker(root.foreground, 3.2)

        Rectangle {
          width: meterTrack.width * Model.levelFraction(podRow.pod.level)
          height: parent.height
          radius: parent.radius
          color: podRow.low ? root.urgent : root.foreground
        }
      }

      Text {
        textFormat: Text.PlainText
        text: Model.levelText(podRow.pod.level)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Style.space(38)
      }

      Text {
        textFormat: Text.PlainText
        text: podRow.metaText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        Layout.preferredWidth: Style.space(56)
      }
    }
  }

  component AncModeRow: CursorSurface {
    id: ancRow
    property int mode: 0

    readonly property string rowName: "anc:" + mode
    readonly property bool selected: pods.ancMode === mode

    hasCursor: root.rowHasCursor(rowName)
    foreground: root.foreground
    implicitHeight: modeLabel.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.focusRow(ancRow.rowName)
      onClicked: pods.setAncMode(ancRow.mode)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        id: modeLabel
        Layout.fillWidth: true
        text: Model.ancModeName(ancRow.mode)
        color: root.foreground
        opacity: ancRow.selected ? 1.0 : 0.75
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignVCenter
        text: Model.GLYPH_CHECK
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        opacity: ancRow.selected ? 1.0 : 0.0
      }
    }
  }

  component EqPresetRow: CursorSurface {
    id: eqRow
    property int preset: 0

    readonly property string rowName: "eq:" + preset
    readonly property bool selected: pods.eqPreset === preset

    hasCursor: root.rowHasCursor(rowName)
    foreground: root.foreground
    implicitHeight: presetLabel.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.focusRow(eqRow.rowName)
      onClicked: pods.setEqPreset(eqRow.preset)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        id: presetLabel
        Layout.fillWidth: true
        text: Model.eqPresetName(eqRow.preset)
        color: root.foreground
        opacity: eqRow.selected ? 1.0 : 0.75
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignVCenter
        text: Model.GLYPH_CHECK
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        opacity: eqRow.selected ? 1.0 : 0.0
      }
    }
  }

  component ToggleRow: CursorSurface {
    id: toggleRow
    property string rowName: ""
    property string label: ""
    property string caption: ""
    property bool checked: false

    signal toggled()

    hasCursor: root.rowHasCursor(rowName)
    foreground: root.foreground
    implicitHeight: toggleContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.focusRow(toggleRow.rowName)
      onClicked: toggleRow.toggled()
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      ColumnLayout {
        id: toggleContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: toggleRow.label
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: toggleRow.caption
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      ToggleSwitch {
        Layout.alignment: Qt.AlignVCenter
        checked: toggleRow.checked
        busy: pods.busy
        hasCursor: toggleRow.hasCursor
        foreground: root.foreground
        onToggled: toggleRow.toggled()
      }
    }
  }
}
