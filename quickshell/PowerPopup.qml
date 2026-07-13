//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PopupWindow {
    id: root
    visible: false
    grabFocus: true
    color: "transparent"
    implicitWidth: 320
    implicitHeight: 280
    
    property double lastCloseTime: 0
    property QtObject popupSysData: null
    property QtObject popupCfg: null
    property var anchorItem: null

    anchor { 
        item: anchorItem
        edges: Edges.Right | Edges.Top
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
        id: powerRect
        focus: true
        
        onActiveFocusChanged: {
            if (!activeFocus && visible) {
                lastCloseTime = Date.now()
                root.visible = false
            }
        }

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 0
        anchors.leftMargin: 10    

        width: 280
        height: 240
        color: popupCfg.popupBgColor
        border.color: popupCfg.inactiveColor
        border.width: 1
        radius: 4

        MouseArea { 
            anchors.fill: parent 
        }

        Process {
            id: powerActionProc
            running: false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // Заголовок и кнопка закрытия
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true } // Распорка
                
                Text { 
                    text: "SYSTEM POWER"
                    color: popupCfg.existingColor
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "AurulentSansMNerdFontPropo"
                }
                
                Item { Layout.fillWidth: true } // Распорка
                
                Text { 
                    text: "✖"
                    color: popupCfg.inactiveColor
                    font.pixelSize: 14
                    font.bold: true
                    
                    MouseArea { 
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            lastCloseTime = Date.now()
                            root.visible = false
                        }
                    }
                }
            }

            // Центральный блок с барами (CPU и RAM) - ГОРИЗОНТАЛЬНЫЙ ВИД
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 25 // Отступ между графиком CPU и RAM

                    // CPU Row
                    RowLayout {
                        spacing: 15
                        Text {
                            text: "󰘚"
                            color: popupCfg.accentColor
                            font.pixelSize: 24
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter
                            Repeater {
                                model: 10
                                Rectangle {
                                    width: 10
                                    height: 16
                                    color: index < Math.round(popupSysData.cpuPercent / 10) ? popupCfg.accentColor : popupCfg.inactiveColor
                                }
                            }
                        }
                        Text {
                            text: popupSysData.cpuPercent + "%"
                            color: popupCfg.existingColor
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 35
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // RAM Row
                    RowLayout {
                        spacing: 15
                        Text {
                            text: "󰍛"
                            color: popupCfg.accentColor
                            font.pixelSize: 24
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter
                            Repeater {
                                model: 10
                                Rectangle {
                                    width: 10
                                    height: 16
                                    color: index < Math.round((popupSysData.ramBlocks / 24) * 10) ? popupCfg.accentColor : popupCfg.inactiveColor
                                }
                            }
                        }
                        Text {
                            text: Math.round((popupSysData.ramBlocks / 24) * 100) + "%"
                            color: popupCfg.existingColor
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 35
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // Круглые кнопки внизу
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Repeater {
                    model: [
                        { icon: "󰤄", cmd: "systemctl suspend" },
                        { icon: "󰑐", cmd: "systemctl reboot" },
                        { icon: "󰐥", cmd: "systemctl poweroff" }
                    ]
                    delegate: Rectangle {
                        width: 44
                        height: 44
                        radius: 22 // Делаем круг
                        color: "transparent"
                        border.width: 2
                        border.color: btnMouse.containsMouse ? popupCfg.accentColor : popupCfg.inactiveColor
                        
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 20
                            color: btnMouse.containsMouse ? popupCfg.accentColor : popupCfg.inactiveColor
                            font.family: "AurulentSansMNerdFontPropo"
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                 powerActionProc.command = ["sh", "-c", modelData.cmd]
                                 powerActionProc.running = true
                                 root.visible = false
                             }
                        }
                    }
                }
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                powerRect.visible = true
                powerRect.forceActiveFocus()
            } 
        }
    }
}
