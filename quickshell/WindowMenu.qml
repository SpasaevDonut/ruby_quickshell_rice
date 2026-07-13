//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PopupWindow {
    id: root
    visible: false
    color: "transparent"

    property int targetWindowId: -1
    property var workspaces: []
    property QtObject popupCfg: null

    property int targetX: 0
    property int targetY: 0
    property int menuWidth: 240
    property int menuHeight: 420
    property var parentWin: null
    property double lastCloseTime: 0

    grabFocus: true
    anchor.window: parentWin

    Connections {
        target: anchor
        function onAnchoring() {
            anchor.rect.x = targetX
            anchor.rect.y = targetY
            anchor.rect.width = 1
            anchor.rect.height = 1
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (Date.now() - root.lastCloseTime < 100) return
            root.lastCloseTime = Date.now()
            root.visible = false
        }
    }

    Rectangle {
        id: menuRect
        focus: true

        onActiveFocusChanged: {
            if (!activeFocus && visible) {
                root.lastCloseTime = Date.now()
                root.visible = false
            }
        }

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0
        anchors.leftMargin: 10

        width: 190
        height: menuColumn.height + 12
        color: popupCfg.popupBgColor
        border.color: popupCfg.inactiveColor
        border.width: 1
        radius: 4

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: menuColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 1

            Repeater {
                model: [
                    { text: "✕ Close", cmd: "sh -c \"niri msg action focus-window --id %1 && niri msg action close-window\"" },
                    { text: "⛶ Fullscreen", cmd: "sh -c \"niri msg action focus-window --id %1 && niri msg action fullscreen-window\"" },
                    { text: "⇵ Toggle floating", cmd: "sh -c \"niri msg action focus-window --id %1 && niri msg action toggle-window-floating\"" },
                    { text: "🔔 Set urgent", cmd: "niri msg action set-window-urgent --id %1" },
                ]
                delegate: Rectangle {
                    width: parent.width
                    height: 26
                    color: marea.containsMouse ? popupCfg.inactiveColor : "transparent"
                    radius: 3

                    Text {
                        text: modelData.text
                        color: popupCfg.textColor
                        font.pixelSize: 11
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                    }

                    MouseArea {
                        id: marea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cmdStr = modelData.cmd.replace("%1", root.targetWindowId.toString())
                            actionProc.command = ["sh", "-c", cmdStr]
                            actionProc.running = true
                            root.visible = false
                        }
                    }
                }
            }

            Item { width: parent.width; height: 3 }
            Rectangle {
                width: parent.width
                height: 1
                color: popupCfg.inactiveColor
            }
            Item { width: parent.width; height: 3 }

            Text {
                text: "Move to workspace"
                color: popupCfg.inactiveColor
                font.pixelSize: 10
                font.bold: true
                font.family: "monospace"
                leftPadding: 6
                bottomPadding: 2
            }

            Repeater {
                model: {
                    var list = []
                    for (var i = 0; i < root.workspaces.length; i++) {
                        var w = root.workspaces[i]
                        if (w.exists && w.id >= 0) {
                            list.push(w)
                        }
                    }
                    return list
                }
                delegate: Rectangle {
                    width: parent.width
                    height: 22
                    color: wmarea.containsMouse ? popupCfg.inactiveColor : "transparent"
                    radius: 3

                    Text {
                        text: modelData.name ? modelData.name : ("WS " + modelData.id)
                        color: modelData.is_focused ? popupCfg.accentColor : popupCfg.existingColor
                        font.pixelSize: 11
                        font.family: "monospace"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    MouseArea {
                        id: wmarea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var wsName = modelData.name ? modelData.name : modelData.id.toString()
                            actionProc.command = ["sh", "-c", "niri msg action focus-window --id " + root.targetWindowId + " && niri msg action move-window-to-workspace " + wsName]
                            actionProc.running = true
                            root.visible = false
                        }
                    }
                }
            }
        }
    }

    Process {
        id: actionProc
        running: false
    }

    onVisibleChanged: {
        if (visible) {
            root.width = menuWidth
            root.height = menuHeight
            menuRect.forceActiveFocus()
        }
    }
}
