import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.omwhop"

  property var whopState: Model.emptyState()
  property bool refreshing: false

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property color foregroundColor: Model.iconColor(
    whopState,
    bar ? bar.barForeground : Color.foreground,
    bar ? bar.urgent : Color.urgent
  )

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    root.broadcast("refreshInstance")
    if (!statusProcess.running) {
      refreshing = true
      statusProcess.running = true
    }
  }

  function refreshInstance() {
    if (statusProcess.running) return
    refreshing = true
    statusProcess.running = true
  }

  function applyState(raw) {
    root.whopState = Model.parseState(raw)
    root.refreshing = false
    if (panelLoader.item && panelLoader.item.syncState) panelLoader.item.syncState()
  }

  property string statusJson: JSON.stringify(whopState)

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function openTerminal(command) {
    if (root.bar) root.bar.run(command)
  }

  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: {
    injectPanel()
    Qt.callLater(refresh)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Process {
    id: statusProcess
    command: [String(Qt.resolvedUrl("scripts/omwhop")).replace(/^file:\/\//, ""), "status"]
    environment: ({ "PATH": Quickshell.env("PATH") })
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0 && panelLoader.item) panelLoader.item.showAdapterError()
    }
  }

  IpcHandler {
    target: "local.omwhop"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string { return root.statusJson }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: Model.accountTitle(root.whopState) + " — " + Model.statusLabel(root.whopState)

    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: root.refreshing ? "↻" : Model.iconFor(root.whopState)
          color: root.refreshing
            ? Qt.darker(root.foregroundColor, 1.35)
            : root.foregroundColor
          font.family: button.fontFamily
          font.pixelSize: root.refreshing ? Style.font.body : Style.font.icon
        }

        SequentialAnimation on opacity {
          id: refreshPulse
          running: root.refreshing
          loops: Animation.Infinite

          NumberAnimation {
            to: 0.35
            duration: 420
            easing.type: Easing.InOutQuad
          }
          NumberAnimation {
            to: 1
            duration: 420
            easing.type: Easing.InOutQuad
          }

          onStopped: opacity = 1
        }
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }
}
