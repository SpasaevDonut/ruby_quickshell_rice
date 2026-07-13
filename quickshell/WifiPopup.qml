//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PopupWindow {
    id: root
    visible: false
    color: "transparent"
    implicitWidth: 320
    implicitHeight: 450

    property double lastCloseTime: 0
    property QtObject popupSysData: null
    property QtObject popupCfg: null
    property var anchorItem: null
    property string connectTargetSsid: ""

    anchor {
        item: anchorItem
        edges: Edges.Right | Edges.Bottom
        gravity: Edges.Right | Edges.Top
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            lastCloseTime = Date.now()
            root.visible = false
        }
    }

    Rectangle {
        id: wifiRect
        focus: true

        onActiveFocusChanged: {
            if (!activeFocus && visible) {
                lastCloseTime = Date.now()
                root.visible = false
            }
        }

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 0
        anchors.leftMargin: 10

        width: 300
        height: 400
        color: popupCfg.popupBgColor
        border.color: popupCfg.inactiveColor
        border.width: 1
        radius: 4
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "NETWORKS"
                    color: popupCfg.accentColor
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "AurulentSansMNerdFontPropo"
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 24
                    height: 24
                    color: popupCfg.inactiveColor

                    Text {
                        text: "\uF0D3"
                        color: popupCfg.textColor
                        anchors.centerIn: parent
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiModel.clear()
                            wifiScanProc.running = true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 2
                color: popupCfg.accentColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ScrollView {
                    id: networkView
                    anchors.fill: parent
                    clip: true

                    ListView {
                        model: wifiModel
                        spacing: 4
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 36
                            color: wMouseArea.containsMouse ? popupCfg.inactiveColor : "transparent"
                            border.color: model.inUse ? popupCfg.accentColor : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: model.inUse ? "\uF5A9" : (model.signal > 70 ? "\uF9A8" : (model.signal > 40 ? "\uF9A5" : "\uF9A2"))
                                    color: model.inUse ? popupCfg.accentColor : popupCfg.textColor
                                    font.pixelSize: 16
                                }

                                Text {
                                    text: model.ssid
                                    color: model.inUse ? popupCfg.accentColor : popupCfg.textColor
                                    font.pixelSize: 13
                                    font.family: "monospace"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: model.secured ? "\uF023" : ""
                                    color: popupCfg.accentColor
                                    font.pixelSize: 12
                                    visible: model.secured
                                }
                            }

                            MouseArea {
                                id: wMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.secured && !model.inUse) {
                                        connectTargetSsid = model.ssid
                                        zenityProc.running = true
                                    } else if (!model.inUse) {
                                        wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", model.ssid]
                                        wifiConnectProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: wifiModel
    }

    property bool __firstShow: true

    Process {
        id: wifiScanProc
        running: true
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi"]
        stdout: SplitParser {
            onRead: data => {
                let f1 = data.indexOf(":")
                let f2 = data.indexOf(":", f1 + 1)
                let f3 = data.indexOf(":", f2 + 1)
                if (f1 > 0 && f2 > 0 && f3 > 0) {
                    let inUse = data.substring(0, f1) === "*"
                    let signal = parseInt(data.substring(f1 + 1, f2))
                    let sec = data.substring(f2 + 1, f3)
                    let ssid = data.substring(f3 + 1).replace(/\\\\:/g, ':')
                    if (ssid.length > 0) {
                        let exists = false
                        for (let i = 0; i < wifiModel.count; i++) {
                            if (wifiModel.get(i).ssid === ssid) {
                                exists = true
                                break
                            }
                        }
                        if (!exists) {
                            wifiModel.append({ inUse: inUse, signal: signal, secured: (sec.length > 0 && sec !== "--"), ssid: ssid })
                        }
                    }
                }
            }
        }
    }

    Process {
        id: zenityProc
        property string pwd: ""
        command: ["sh", "-c", "zenity --password --title='Wi-Fi Password'"]
        stdout: SplitParser {
            onRead: data => {
                if (data.length > 0) {
                    zenityProc.pwd = data.trim()
                }
            }
        }
        onExited: {
            if (zenityProc.pwd.length > 0) {
                var ssid = connectTargetSsid.replace(/'/g, "'\\''")
                var pwd = zenityProc.pwd.replace(/'/g, "'\\''")
                wifiConnectProc.command = ["sh", "-c", "nmcli dev wifi connect '" + ssid + "' password '" + pwd + "'"]
                wifiConnectProc.running = true
            }
        }
    }

    Process {
        id: wifiConnectProc
        onExited: {
            wifiModel.clear()
            wifiScanProc.running = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            wifiRect.forceActiveFocus()
            if (__firstShow) {
                __firstShow = false
            } else {
                wifiModel.clear()
            }
            wifiScanProc.running = true
        }
    }
}
