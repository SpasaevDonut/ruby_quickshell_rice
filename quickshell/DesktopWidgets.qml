//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: desktopWidgets
    
    property QtObject sysData: null
    property QtObject cfg: null
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Background 
    
    color: "transparent"

    Item {
        anchors.fill: parent

        Column {
            anchors.left: parent.left
            anchors.leftMargin: cfg.barWidth + 100
            anchors.verticalCenter: parent.verticalCenter
            spacing: 40

            Column {
                id: clockColumn
                spacing: 5
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    id: timeText
                    text: Qt.formatDateTime(new Date(), "hh:mm")
                    color: cfg.textColor
                    font.pixelSize: 64
                    font.bold: true
                    font.family: "AurulentSansMNerdFontPropo"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    id: dateText
                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                    color: cfg.existingColor
                    font.pixelSize: 24
                    font.family: "AurulentSansMNerdFontPropo"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        timeText.text = Qt.formatDateTime(new Date(), "hh:mm")
                        dateText.text = Qt.formatDateTime(new Date(), "dddd, d MMMM")
                    }
                }
            }

            GridLayout {
                columns: 2
                columnSpacing: 60
                rowSpacing: 40
                anchors.horizontalCenter: parent.horizontalCenter

                // 1. CPU WIDGET (Левая колонка)
                RowLayout {
                    spacing: 20
                    
                    Image {
                        source: "cpu.svg"
                        sourceSize.width: 45
                        sourceSize.height: 45
                        width: 45
                        height: 45
                        fillMode: Image.PreserveAspectFit
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    ColumnLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter
                        
                        Row {
                            spacing: 6
                            Layout.alignment: Qt.AlignLeft
                            Repeater {
                                model: 8
                                Column {
                                    spacing: 3
                                    property int active: Math.max(0, Math.min(10, Math.round((sysData.cpuPercent / 10) + (Math.random() * 2 - 1))))
                                    Repeater {
                                        model: 10
                                        Rectangle {
                                            width: 14
                                            height: 3
                                            color: index >= (10 - parent.active) ? cfg.accentColor : cfg.inactiveColor
                                        }
                                    }
                                
                                    Timer { 
                                        interval: 1000 + Math.random() * 500
                                        running: true
                                        repeat: true
                                        onTriggered: { 
                                            parent.active = Math.max(0, Math.min(10, Math.round((sysData.cpuPercent / 10) + (Math.random() * 2 - 1))))
                                        } 
                                    }
                                }
                            }
                        }
                        Column {
                            spacing: 4
                            Layout.alignment: Qt.AlignHCenter
                            Row { 
                                spacing: 4
                                Repeater { 
                                    model: 38
                                    Rectangle { 
                                        width: 6
                                        height: 2
                                        color: index < 3 ? cfg.accentColor : cfg.inactiveColor 
                                    } 
                                } 
                            }
                            Row { 
                                spacing: 4
                                Repeater { 
                                    model: 38
                                    Rectangle { 
                                        width: 6
                                        height: 2
                                        color: index < 2 ? cfg.accentColor : cfg.inactiveColor 
                                    } 
                                } 
                            }
                        }
                    }
                }

                // 2. NETWORK WIDGET (Правая колонка)
                RowLayout {
                    spacing: 15
                    
                    ColumnLayout {
                        spacing: 4
                        Image {
                            source: "up.svg"
                            sourceSize.width: 24
                            sourceSize.height: 24
                            width: 24
                            height: 24
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Column {
                            spacing: 4
                            Layout.alignment: Qt.AlignHCenter
                            Repeater { 
                                model: 4
                                Rectangle { 
                                    width: 12
                                    height: 2
                                    color: index >= 4 - Math.round(sysData.ulRatio * 4) ? cfg.accentColor : cfg.inactiveColor
                                } 
                            }
                        }
                        Image {
                            source: "down.svg"
                            sourceSize.width: 24
                            sourceSize.height: 24
                            width: 24
                            height: 24
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 6
                        Row { 
                            spacing: 3
                            Repeater { 
                                model: 50
                                Rectangle { 
                                    width: 4
                                    height: 2
                                    color: cfg.inactiveColor 
                                } 
                            } 
                        }
                        RowLayout {
                            Rectangle { 
                                width: 2
                                height: 8
                                color: cfg.accentColor 
                            }
                            Text { 
                                text: sysData.uploadStr
                                color: cfg.inactiveColor
                                font.family: "AurulentSansMNerdFontPropo"
                                font.pixelSize: 14 
                            }
                        }
                        Row { 
                            spacing: 3
                            Repeater { 
                                model: 50
                                Rectangle { 
                                    width: 4
                                    height: 2
                                    color: cfg.inactiveColor 
                                } 
                            } 
                        }
                        RowLayout {
                            Rectangle { 
                                width: 2
                                height: 8
                                color: cfg.accentColor 
                            }
                            Text { 
                                text: sysData.downloadStr
                                color: cfg.inactiveColor
                                font.family: "AurulentSansMNerdFontPropo"
                                font.pixelSize: 14 
                            }
                        }
                        Row { 
                            spacing: 3
                            Repeater { 
                                model: 50
                                Rectangle { 
                                    width: 4
                                    height: 2
                                    color: cfg.inactiveColor 
                                } 
                            } 
                        }
                    }
                }

                // 3. RAM WIDGET (Левая колонка)
                RowLayout {
                    spacing: 20
                    
                    Image {
                        source: "transmission.svg"
                        sourceSize.width: 45
                        sourceSize.height: 45
                        width: 45
                        height: 45
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    ColumnLayout {
                        spacing: 8
                        Row {
                            spacing: 4
                            Repeater {
                                model: 24
                                Rectangle {
                                    width: 4
                                    height: 24
                                    color: index < sysData.ramBlocks ? cfg.accentColor : cfg.inactiveColor
                                }
                            }
                        }
                        Column {
                            spacing: 4
                            Row { 
                                spacing: 4
                                Repeater { 
                                    model: 38
                                    Rectangle { 
                                        width: 6
                                        height: 2
                                        color: index < 5 ? cfg.accentColor : cfg.inactiveColor 
                                    } 
                                } 
                            }
                            Row { 
                                spacing: 4
                                Repeater { 
                                    model: 38
                                    Rectangle { 
                                        width: 6
                                        height: 2
                                        color: index < 4 ? cfg.accentColor : cfg.inactiveColor 
                                    } 
                                } 
                            }
                        }
                    }
                }

                // 4. DISK I/O WIDGET (Правая колонка)
                RowLayout {
                    spacing: 15
                    
                    ColumnLayout {
                        spacing: 4
                        Image {
                            source: "up.svg"
                            sourceSize.width: 24
                            sourceSize.height: 24
                            width: 24
                            height: 24
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Column {
                            spacing: 4
                            Layout.alignment: Qt.AlignHCenter
                            Repeater { 
                                model: 4
                                Rectangle { 
                                    width: 12
                                    height: 2
                                    color: index >= 4 - Math.round(sysData.diskReadRatio * 4) ? cfg.accentColor : cfg.inactiveColor
                                } 
                            }
                        }
                        Image {
                            source: "down.svg"
                            sourceSize.width: 24
                            sourceSize.height: 24
                            width: 24
                            height: 24
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 6
                        Row { 
                            spacing: 3
                            Repeater { 
                                model: 50
                                Rectangle { 
                                    width: 4
                                    height: 2
                                    color: index < Math.round(sysData.diskReadRatio * 50) ? cfg.accentColor : cfg.inactiveColor 
                                } 
                            } 
                        }
                        RowLayout {
                            Rectangle { 
                                width: 2
                                height: 8
                                color: cfg.accentColor 
                            }
                            Text { 
                                text: sysData.diskReadStr
                                color: cfg.inactiveColor
                                font.family: "AurulentSansMNerdFontPropo"
                                font.pixelSize: 14 
                            }
                        }
                        Row { 
                            spacing: 3
                            Repeater { 
                                model: 50
                                Rectangle { 
                                    width: 4
                                    height: 2
                                    color: index < Math.round(sysData.diskWriteRatio * 50) ? cfg.accentColor : cfg.inactiveColor 
                                } 
                            } 
                        }
                        RowLayout {
                            Rectangle { 
                                width: 2
                                height: 8
                                color: cfg.accentColor 
                            }
                            Text { 
                                text: sysData.diskWriteStr
                                color: cfg.inactiveColor
                                font.family: "AurulentSansMNerdFontPropo"
                                font.pixelSize: 14 
                            }
                        }
                    }
                }

                // 5. DISK USAGE WIDGET (Левая колонка)
                RowLayout {
                    spacing: 20
                    
                    Image {
                        source: "storage.svg"
                        sourceSize.width: 45
                        sourceSize.height: 45
                        width: 45
                        height: 45
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    ColumnLayout {
                        spacing: 8
                        Column {
                            spacing: 4
                            Repeater {
                                model: 5 
                                Row {
                                    spacing: 4
                                    property int rowIdx: index
                                    Repeater {
                                        model: 38 
                                        Rectangle {
                                            width: 2
                                            height: 6
                                            
                                            property bool isFilled: (parent.rowIdx * 38 + index) < ((sysData.storagePercent / 100.0) * 190)
                                            property bool isActive: false
                                            
                                            color: (isFilled || isActive) ? cfg.accentColor : cfg.inactiveColor
                                            
                                            Timer {
                                                interval: 1000 + Math.random() * 2000
                                                running: true
                                                repeat: true
                                                onTriggered: {
                                                    parent.isActive = !parent.isFilled && (Math.random() > 0.8)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Column {
                            spacing: 4
                            Row { 
                                spacing: 4
                                Repeater { 
                                    model: 38
                                    Rectangle { 
                                        width: 6
                                        height: 2
                                        color: index < 5 ? cfg.accentColor : cfg.inactiveColor 
                                    } 
                                } 
                            }
                            Row { 
                                spacing: 4
                                Repeater { 
                                    model: 38
                                    Rectangle { 
                                        width: 6
                                        height: 2
                                        color: index < 4 ? cfg.accentColor : cfg.inactiveColor 
                                    } 
                                } 
                            }
                        }
                    }
                }

                // 6. TEMP 1 WIDGET (Правая колонка)
                RowLayout {
                    spacing: 20
                    
                    Image {
                        source: "thermometer.svg"
                        sourceSize.width: 45
                        sourceSize.height: 45
                        width: 45
                        height: 45
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        RowLayout {
                            spacing: 10
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 30
                                    Rectangle {
                                        width: 2
                                        height: 8
                                        color: index < Math.round((sysData.temp1 / 100.0) * 30) ? cfg.accentColor : cfg.inactiveColor
                                    }
                                }
                            }
                            Text {
                                text: sysData.temp1 + " °C"
                                color: cfg.inactiveColor
                                font.family: "AurulentSansMNerdFontPropo"
                                font.pixelSize: 12
                                Layout.preferredWidth: 40
                            }
                        }
                        RowLayout {
                            spacing: 10
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 30
                                    Rectangle { width: 2; height: 8; color: index < 18 ? cfg.accentColor : cfg.inactiveColor }
                                }
                            }
                            Text { text: "49 °C"; color: cfg.inactiveColor; font.family: "AurulentSansMNerdFontPropo"; font.pixelSize: 12; Layout.preferredWidth: 40 }
                        }
                        RowLayout {
                            spacing: 10
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 30
                                    Rectangle { width: 2; height: 8; color: cfg.inactiveColor }
                                }
                            }
                            Text { text: "OFF"; color: cfg.inactiveColor; font.family: "AurulentSansMNerdFontPropo"; font.pixelSize: 12; Layout.preferredWidth: 40 }
                        }
                    }
                }

                // 7. TEMP 2 WIDGET (Левая колонка)
                RowLayout {
                    spacing: 20
                    
                    Image {
                        source: "thermometer.svg"
                        sourceSize.width: 45
                        sourceSize.height: 45
                        width: 45
                        height: 45
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        RowLayout {
                            spacing: 10
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 30
                                    Rectangle {
                                        width: 2
                                        height: 8
                                        color: index < Math.round((sysData.temp2 / 100.0) * 30) ? cfg.accentColor : cfg.inactiveColor
                                    }
                                }
                            }
                            Text {
                                text: sysData.temp2 + " °C"
                                color: cfg.inactiveColor
                                font.family: "AurulentSansMNerdFontPropo"
                                font.pixelSize: 12
                                Layout.preferredWidth: 40
                            }
                        }
                        RowLayout {
                            spacing: 10
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 30
                                    Rectangle { width: 2; height: 8; color: index < 12 ? cfg.accentColor : cfg.inactiveColor }
                                }
                            }
                            Text { text: "27 °C"; color: cfg.inactiveColor; font.family: "AurulentSansMNerdFontPropo"; font.pixelSize: 12; Layout.preferredWidth: 40 }
                        }
                        RowLayout {
                            spacing: 10
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 30
                                    Rectangle { width: 2; height: 8; color: index < 16 ? cfg.accentColor : cfg.inactiveColor }
                                }
                            }
                            Text { text: "37 °C"; color: cfg.inactiveColor; font.family: "AurulentSansMNerdFontPropo"; font.pixelSize: 12; Layout.preferredWidth: 40 }
                        }
                    }
                }

                // 8. FAN WIDGET (Правая колонка)
                RowLayout {
                    spacing: 20
                    
                    Image {
                        source: "fan.svg"
                        sourceSize.width: 45
                        sourceSize.height: 45
                        width: 45
                        height: 45
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    ColumnLayout {
                        spacing: 6
                        Repeater {
                            model: 2 
                            Row {
                                spacing: 3
                                Repeater {
                                    model: 40
                                    Rectangle {
                                        width: 2
                                        height: 8
                                        color: index < Math.round(sysData.fan1Ratio * 40) ? cfg.accentColor : cfg.inactiveColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
