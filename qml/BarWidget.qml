import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Api.js" as Api

// Bar icon plus the settings dropdown. Every color and font comes from the
// bar and the shell theme, so the panel follows whatever Omarchy theme is set.
Panel {
  id: root
  moduleName: "io.github.dankestrick.omakraken"
  // The service is shared by every monitor's bar; no per-instance IPC target.
  manageIpc: false

  readonly property var kraken: bar && bar.shell
    ? bar.shell.serviceFor("io.github.dankestrick.omakraken") : null
  readonly property var status: kraken ? kraken.status : ({})
  readonly property var saved: kraken ? kraken.saved : ({})
  readonly property bool dongle: !!(kraken && kraken.dongle)
  readonly property bool connected: !!(kraken && kraken.connected)

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var tabs: ["Lighting", "Sound", "Haptics", "Power", "Device"]
  property string tab: "Lighting"

  readonly property string effect: saved.effect || "static"
  readonly property bool lightingOn: saved.lighting !== false
  // The headset turns its lights off while charging, whatever is sent.
  readonly property bool charging: !!(kraken && kraken.charging)
  readonly property bool lightingEditable: connected && !charging
  readonly property bool lightsLive: lightingEditable && lightingOn

  readonly property string statusLine: {
    if (!kraken) return "Starting"
    if (!dongle) return "Dongle not found"
    if (!connected) return "Headset not answering"
    return kraken.batteryText
  }

  function set(key, value) {
    if (kraken) kraken.change(key, value)
  }

  onOpenedChanged: if (kraken) kraken.panelOpen = opened

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋋"
    dimmed: !root.connected
    tooltipText: root.kraken ? "Kraken V3 Pro · " + root.kraken.batteryText : "Kraken V3 Pro"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (root.kraken) root.kraken.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: effectMenu.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx === 0) return
        var i = root.tabs.indexOf(root.tab) + dx
        root.tab = root.tabs[(i + root.tabs.length) % root.tabs.length]
      }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(12)

        // ---------- Hero: headset · battery ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰋋"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.connected ? 1.0 : 0.5
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "Kraken V3 Pro"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusLine.toUpperCase()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        ButtonGroup {
          width: parent.width
          options: root.tabs
          value: root.tab
          focusable: false
          foreground: root.fg
          fontFamily: root.fontFamily
          onChanged: function(v) { root.tab = v }
        }

        Text {
          textFormat: Text.PlainText
          visible: !!root.kraken && root.dongle && !root.connected
          width: parent.width
          wrapMode: Text.WordWrap
          text: "The headset is not answering. Turn it on. If it stays like this after plugging or unplugging the charger, replug the dongle."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          textFormat: Text.PlainText
          visible: !!root.kraken && root.kraken.lastError !== "" && root.connected
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.kraken ? root.kraken.lastError : ""
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        PanelSeparator { foreground: root.fg }

        // ---------- Lighting ----------
        Column {
          visible: root.tab === "Lighting"
          width: parent.width
          spacing: Style.space(10)

          Toggle {
            width: parent.width
            label: "Lighting"
            description: root.charging ? "The headset turns its lights off while charging." : ""
            checked: root.lightingOn
            enabled: root.lightingEditable
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.set("lighting", !root.lightingOn)
          }

          LabeledRow {
            label: "Effect"
            Dropdown {
              id: effectMenu
              width: Style.space(190)
              showLabel: false
              enabled: root.lightsLive
              options: Api.EFFECTS
              value: root.effect
              fontFamily: root.fontFamily
              onChanged: function(v) { root.set("effect", v) }
            }
          }

          SliderRow {
            label: "Brightness"
            minimum: 0
            maximum: 100
            level: root.saved.brightness !== undefined ? root.saved.brightness : 100
            suffix: "%"
            active: root.lightsLive
            onPicked: function(v) { root.set("brightness", v) }
          }

          SliderRow {
            visible: Api.effectUsesSpeed(root.effect)
            label: "Speed"
            minimum: 1
            maximum: 10
            ticks: 10
            level: root.saved.speed || 5
            active: root.lightsLive
            onPicked: function(v) { root.set("speed", v) }
          }

          // Color, for the effects that use one.
          Column {
            visible: Api.effectUsesColor(root.effect)
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader { text: "COLOR"; foreground: root.fg; fontFamily: root.fontFamily }

            Rectangle {
              width: parent.width
              height: Style.space(22)
              radius: Style.cornerRadius
              opacity: root.lightsLive ? 1 : 0.5
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ff0000" }
                GradientStop { position: 1 / 6; color: "#ffff00" }
                GradientStop { position: 2 / 6; color: "#00ff00" }
                GradientStop { position: 3 / 6; color: "#00ffff" }
                GradientStop { position: 4 / 6; color: "#0000ff" }
                GradientStop { position: 5 / 6; color: "#ff00ff" }
                GradientStop { position: 1.0; color: "#ff0000" }
              }

              MouseArea {
                anchors.fill: parent
                enabled: root.lightsLive
                cursorShape: Qt.PointingHandCursor
                onClicked: function(m) {
                  root.set("color", Api.hueHex(Math.max(0, Math.min(0.9999, m.x / width))))
                }
              }
            }

            Grid {
              columns: 7
              spacing: Style.space(8)

              Repeater {
                model: Api.PRESET_COLORS
                delegate: Rectangle {
                  required property string modelData
                  readonly property bool picked: String(root.saved.color || "").toLowerCase() === modelData
                  width: Style.space(40)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  color: modelData
                  opacity: root.lightsLive ? 1 : 0.5
                  border.width: picked ? 2 : 1
                  border.color: picked ? root.fg : Util.alpha(root.fg, 0.2)

                  MouseArea {
                    anchors.fill: parent
                    enabled: root.lightsLive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.set("color", modelData)
                  }
                }
              }
            }
          }
        }

        // ---------- Sound ----------
        Column {
          visible: root.tab === "Sound"
          width: parent.width
          spacing: Style.space(10)

          Toggle {
            width: parent.width
            label: "Sidetone"
            description: "Hear your own voice in the headset while you talk."
            checked: !!root.status.sidetone
            enabled: root.connected
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.set("sidetone", !root.status.sidetone)
          }

          SliderRow {
            label: "Sidetone level"
            minimum: 0
            maximum: 4
            ticks: 5
            level: root.status.sidetoneLevel || 0
            display: function(v) { return String(v + 1) }
            active: !!root.status.sidetone
            onPicked: function(v) { root.set("sidetoneLevel", v) }
          }

          PanelSeparator { foreground: root.fg }

          SliderRow {
            label: "Mic volume"
            minimum: 0
            maximum: 100
            suffix: "%"
            level: root.kraken && root.kraken.micVolume >= 0 ? Math.round(root.kraken.micVolume * 100) : 0
            active: !!root.kraken && root.kraken.micVolume >= 0
            needsHeadset: false
            onPicked: function(v) { if (root.kraken) root.kraken.setMicVolume(v / 100) }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Equalizer, bass boost, sound normalization and voice clarity are effects of Razer's Windows app. The headset has no setting for them."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // ---------- Haptics ----------
        Column {
          visible: root.tab === "Haptics"
          width: parent.width
          spacing: Style.space(10)

          Toggle {
            width: parent.width
            label: "Haptic intensity"
            description: "HyperSense vibration that follows the sound."
            checked: root.saved.haptics !== false
            enabled: root.connected
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.set("haptics", root.saved.haptics === false)
          }

          ButtonGroup {
            width: parent.width
            options: Api.HAPTIC_LEVELS
            value: Api.HAPTIC_LEVELS[(root.saved.hapticsLevel || 1) - 1]
            enabled: root.connected && root.saved.haptics !== false
            opacity: enabled ? 1 : 0.5
            focusable: false
            foreground: root.fg
            fontFamily: root.fontFamily
            onChanged: function(v) { root.set("hapticsLevel", Api.HAPTIC_LEVELS.indexOf(v) + 1) }
          }
        }

        // ---------- Power ----------
        Column {
          visible: root.tab === "Power"
          width: parent.width
          spacing: Style.space(10)

          Toggle {
            width: parent.width
            label: "Power saving"
            description: "Turn the headset off after this many minutes of inactivity on battery."
            checked: !!root.status.powerSaving
            enabled: root.connected
            foreground: root.fg
            fontFamily: root.fontFamily
            onClicked: root.set("powerSaving", !root.status.powerSaving)
          }

          SliderRow {
            label: "Minutes"
            minimum: 15
            maximum: 60
            level: root.status.powerSavingMinutes || 15
            active: !!root.status.powerSaving
            onPicked: function(v) { root.set("powerSavingMinutes", v) }
          }
        }

        // ---------- Device ----------
        Column {
          visible: root.tab === "Device"
          width: parent.width
          spacing: Style.space(8)

          InfoRow { label: "Battery"; value: root.kraken ? root.kraken.batteryText : "—" }
          InfoRow { label: "Serial number"; value: root.status.serial || "—" }
          InfoRow { label: "Dongle"; value: root.dongle ? (root.status.port || "Found") : "Not found" }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.WordWrap
            topPadding: Style.space(6)
            text: "Right-click the bar icon to read the headset again."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // Label on the left, value on the right.
  component InfoRow: Item {
    property string label: ""
    property string value: ""
    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
      id: labelText
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      id: valueText
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  // Label on the left, one control on the right.
  component LabeledRow: Item {
    id: labeled
    property string label: ""
    default property alias control: slot.data
    width: parent ? parent.width : 0
    implicitHeight: Math.max(rowLabel.implicitHeight, slot.childrenRect.height)

    Text {
      id: rowLabel
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: labeled.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Item {
      id: slot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  // A labeled slider with its number. Sends only the released value.
  component SliderRow: Item {
    id: sliderRow
    property string label: ""
    property int minimum: 0
    property int maximum: 100
    property int ticks: 0
    property int level: 0
    property string suffix: ""
    property bool active: true
    property bool needsHeadset: true
    property var display: null
    signal picked(int value)
    readonly property bool usable: active && (!needsHeadset || root.connected)
    // The stock slider jumps back to `value` on release and waits for the
    // owner to report the new one. The headset confirms a change a moment
    // later, so hold the released value until it does (or 3 s pass).
    property int pending: -1
    readonly property int current: pending >= 0 ? pending : level
    readonly property int shown: Math.round(slider.dragging ? slider.liveValue : current)
    onLevelChanged: pending = -1

    Timer {
      id: settle
      interval: 3000
      onTriggered: sliderRow.pending = -1
    }
    width: parent ? parent.width : 0
    implicitHeight: sliderLabel.implicitHeight + Style.space(4) + slider.implicitHeight
    opacity: usable ? 1 : 0.5

    Text {
      id: sliderLabel
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.top: parent.top
      text: sliderRow.label
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    PanelSlider {
      id: slider
      bar: root.bar
      anchors.left: parent.left
      anchors.right: sliderValue.left
      anchors.rightMargin: Style.space(12)
      anchors.top: sliderLabel.bottom
      anchors.topMargin: Style.space(4)
      minimum: sliderRow.minimum
      maximum: sliderRow.maximum
      step: 1
      integer: true
      tickCount: sliderRow.ticks
      enabled: sliderRow.usable
      value: sliderRow.current
      onReleased: function(v) {
        sliderRow.pending = Math.round(v)
        settle.restart()
        sliderRow.picked(Math.round(v))
      }
    }

    Text {
      id: sliderValue
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.verticalCenter: slider.verticalCenter
      width: Style.space(44)
      horizontalAlignment: Text.AlignRight
      text: (sliderRow.display ? sliderRow.display(sliderRow.shown) : String(sliderRow.shown)) + sliderRow.suffix
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
