import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "local.omwhop"
  ipcTarget: "local.omwhop"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var whopState: hostWidget && hostWidget.whopState
    ? hostWidget.whopState
    : Model.emptyState()
  readonly property bool busy: hostWidget ? hostWidget.refreshing === true : false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string firstWarning: Model.firstWarning(whopState)

  function syncState() {
    if (keyCatcher) keyCatcher.forceActiveFocus()
  }

  function showAdapterError() {
    adapterError.visible = true
  }

  function refresh() {
    if (hostWidget) hostWidget.refresh()
  }

  function runTerminal(command) {
    if (!hostWidget || !hostWidget.openTerminal) return
    hostWidget.openTerminal(command)
  }

  function openUrl(url) {
    Quickshell.execDetached(["omarchy-launch-browser", url])
  }

  function signIn() {
    runTerminal("omarchy-launch-floating-terminal-with-presentation whop login --method oauth --format jsonl")
  }

  function runQuickstart() {
    runTerminal("omarchy-launch-floating-terminal-with-presentation whop quickstart")
  }

  function openWhopLink(kind) {
    var paths = {
      dashboard: "https://whop.com/dashboard",
      products: "https://whop.com/dashboard/products",
      memberships: "https://whop.com/dashboard/users",
      analytics: "https://whop.com/dashboard/analytics",
      apps: "https://whop.com/dashboard/apps"
    }
    var url = paths[String(kind || "")]
    if (url) openUrl(url)
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  onOpenedChanged: if (opened) {
    syncState()
    refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: Model.accountTitle(root.whopState)
            meta: Model.statusLabel(root.whopState)
            detail: root.whopState.installed === true ? "WHOP" : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Item {
                implicitWidth: Style.font.display
                implicitHeight: Style.font.display

                BorderSurface {
                  anchors.centerIn: parent
                  width: Style.space(54)
                  height: Style.space(54)
                  radius: Style.space(14)
                  color: Style.normalFillFor(root.foreground, Color.accent)
                  borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

                  Text {
                    anchors.centerIn: parent
                    text: root.busy ? "↻" : Model.iconFor(root.whopState)
                    color: Model.iconColor(root.whopState, root.foreground, root.urgent)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                  }
                }
              }
            }

            trailingControl: Component {
              Button {
                text: root.busy ? "Refreshing" : "Refresh"
                iconText: root.busy ? "↻" : "↻"
                iconSpinning: root.busy
                focusable: true
                enabled: !root.busy
                foreground: root.foreground
                onClicked: root.refresh()
              }
            }
          }

          CursorSurface {
            id: adapterError
            visible: false
            width: parent.width
            implicitHeight: errorText.implicitHeight + Style.space(20)
            foreground: root.foreground

            Text {
              id: errorText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              text: "OmWhop could not read Whop status. Try Refresh."
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }

          CursorSurface {
            visible: root.whopState.installed !== true
            width: parent.width
            implicitHeight: missingColumn.implicitHeight + Style.space(20)
            foreground: root.foreground

            Column {
              id: missingColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                width: parent.width
                text: "Whop CLI is not installed"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                width: parent.width
                text: "Run the OmWhop installer, then restart the shell."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }

          Column {
            visible: root.whopState.installed === true && root.whopState.loggedIn !== true
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: "Sign in to show your Whop business."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Row {
              spacing: Style.space(8)

              Button {
                text: "Sign in"
                iconText: "→"
                focusable: true
                foreground: root.foreground
                onClicked: root.signIn()
              }

              Button {
                text: "Run quickstart"
                focusable: true
                foreground: root.foreground
                onClicked: root.runQuickstart()
              }
            }
          }

          Column {
            visible: root.whopState.installed === true && root.whopState.loggedIn === true && !root.whopState.account
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: "No business is selected."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Button {
              text: "Choose a business"
              iconText: "→"
              focusable: true
              foreground: root.foreground
              onClicked: root.runQuickstart()
            }
          }

          Column {
            visible: !!root.whopState.account
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              width: parent.width
              text: "BUSINESS SNAPSHOT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: [
                  { label: "Products", key: "products" },
                  { label: "Plans", key: "plans" },
                  { label: "Active", key: "activeMemberships" },
                  { label: "Apps", key: "apps" }
                ]

                BorderSurface {
                  required property var modelData
                  width: (column.width - Style.space(8) * 3) / 4
                  height: Style.space(62)
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.foreground, Color.accent)
                  borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: {
                        var value = Model.count(root.whopState, modelData.key)
                        if (value === null) return "—"
                        var lowerBound = root.whopState.countsAreLowerBounds
                          && root.whopState.countsAreLowerBounds[modelData.key] === true
                        return String(value) + (lowerBound ? "+" : "")
                      }
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: true
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modelData.label
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }

            Text {
              width: parent.width
              visible: root.whopState.cliVersion !== ""
              text: root.whopState.cliVersion
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            visible: !!root.whopState.account
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "RECOMMENDATIONS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              visible: root.whopState.recommendations.length === 0
              text: root.firstWarning !== ""
                ? "Recommendations are unavailable for this business."
                : "No ready Whop recommendations yet."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.whopState.recommendations

              BorderSurface {
                required property var modelData
                width: parent.width
                implicitHeight: recommendationColumn.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: Style.normalFillFor(root.foreground, Color.accent)
                borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

                Column {
                  id: recommendationColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(8)
                  spacing: Style.space(3)

                  Text {
                    width: parent.width
                    text: Model.recommendationTitle(modelData)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    wrapMode: Text.WordWrap
                  }

                  Text {
                    width: parent.width
                    visible: Model.recommendationDescription(modelData) !== ""
                    text: Model.recommendationDescription(modelData)
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                  }

                  Text {
                    width: parent.width
                    visible: Model.recommendationMeta(modelData) !== ""
                    text: Model.recommendationMeta(modelData)
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          Column {
            visible: !!root.whopState.account
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "OPEN WHOP"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              width: parent.width
              columns: 2
              spacing: Style.space(8)

              Repeater {
                model: [
                  { label: "Dashboard", kind: "dashboard", icon: "⌂" },
                  { label: "Products", kind: "products", icon: "▣" },
                  { label: "Memberships", kind: "memberships", icon: "♙" },
                  { label: "Analytics", kind: "analytics", icon: "↗" },
                  { label: "Apps", kind: "apps", icon: "◇" }
                ]

                Button {
                  required property var modelData
                  width: (column.width - Style.space(8)) / 2
                  leftAlign: true
                  text: modelData.label
                  iconText: modelData.icon
                  focusable: true
                  foreground: root.foreground
                  onClicked: root.openWhopLink(modelData.kind)
                }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.firstWarning !== ""
            text: root.firstWarning
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.whopState.generatedAt !== ""
            text: "Updated " + root.whopState.generatedAt
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
