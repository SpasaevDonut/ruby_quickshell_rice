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
    implicitHeight: 450
    
    property double lastCloseTime: 0
    property QtObject popupSysData: null
    property QtObject popupCfg: null
    property var anchorItem: null

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
        id: calRect
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

        width: 270
        height: 400
        color: popupCfg.popupBgColor
        border.color: popupCfg.inactiveColor
        border.width: 1
        radius: 4

        MouseArea { 
            anchors.fill: parent 
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 6

            Text { 
                id: popupTime
                color: popupCfg.accentColor
                font.pixelSize: 36
                font.bold: true
                font.family: "monospace"
                Layout.alignment: Qt.AlignHCenter 
            }
            
            Text { 
                id: popupDate
                color: popupCfg.textColor
                font.pixelSize: 13
                font.family: "monospace"
                Layout.alignment: Qt.AlignHCenter 
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                
                Text { 
                    text: "SYS_TIME"
                    font.pixelSize: 12
                    color: popupCfg.inactiveColor
                    font.family: "monospace" 
                }
                
                Text {
                    id: popupRegion
                    color: popupCfg.accentColor
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "monospace"
                    
                    Component.onCompleted: { 
                        try { 
                            text = Intl.DateTimeFormat().resolvedOptions().timeZone 
                        } catch(e) { 
                            text = "LOCAL" 
                        } 
                    }
                }
            }

            Rectangle { 
                Layout.fillWidth: true
                height: 2
                color: popupCfg.accentColor
                Layout.topMargin: 10
                Layout.bottomMargin: 10 
            }

            GridLayout {
                columns: 7
                Layout.alignment: Qt.AlignHCenter
                rowSpacing: 8
                columnSpacing: 10
                
                Repeater { 
                    model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                    Text { 
                        text: modelData
                        color: (index > 4) ? popupCfg.accentColor : popupCfg.inactiveColor
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true 
                    } 
                }
                
                Repeater { 
                    model: { 
                        let d = new Date(new Date().getFullYear(), new Date().getMonth(), 1).getDay()
                        return d === 0 ? 6 : d - 1 
                    }
                    Item { 
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24 
                    } 
                }
                
                Repeater {
                    model: new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate()
                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        color: (index + 1 === new Date().getDate()) ? popupCfg.accentColor : "transparent"
                        border.color: (index + 1 === new Date().getDate()) ? "transparent" : popupCfg.inactiveColor
                        border.width: 1
                        
                        Text { 
                            anchors.centerIn: parent
                            text: index + 1
                            color: (index + 1 === new Date().getDate()) ? popupCfg.bgColor : popupCfg.textColor
                            font.pixelSize: 13
                            font.family: "monospace" 
                        }
                    }
                }
            }
            
            Item { 
                Layout.fillHeight: true 
            } 
        }
    }

    Timer { 
        interval: 1000
        running: visible
        repeat: true
        onTriggered: { 
            popupTime.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
            popupDate.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd") 
        } 
    }
    
    onVisibleChanged: {
        if (visible) {
            calRect.visible = true
            calRect.forceActiveFocus()
            popupTime.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
            popupDate.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd") 
        } 
    }
}
