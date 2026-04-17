//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls 
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray 
import Quickshell.Wayland 

ShellRoot {
    
    Config { 
        id: cfg 
    }

    // =========================================================
    // ГЛОБАЛЬНЫЙ МЕНЕДЖЕР ДАННЫХ (Опрашивает систему 1 раз)
    // =========================================================
    Item {
        id: sysData

        function formatSpeed(bytes) {
            if (bytes === 0) return "0B"
            if (bytes < 1024) return bytes.toFixed(0) + "B"
            if (bytes < 1048576) return (bytes / 1024).toFixed(0) + "K"
            return (bytes / 1048576).toFixed(1) + "M"
        }

        // --- СЕТЬ ---
        property real lastRx: 0
        property real lastTx: 0
        property real rawDownload: 0
        property real rawUpload: 0
        property real dlRatio: 0.0
        property real ulRatio: 0.0
        property string downloadStr: "0B"
        property string uploadStr: "0B"
        property string netIcon: "󰖪"
        property bool isConnected: false

        Process {
            id: netProcess
            command: ["sh", "-c", `awk '/${cfg.netInterface}/ {print $2 " " $10}' /proc/net/dev; cat /sys/class/net/${cfg.netInterface}/operstate 2>/dev/null`]
            stdout: SplitParser {
                onRead: data => {
                    if (data.includes(" ")) { 
                        let parts = data.split(" ")
                        let rx = parseFloat(parts[0])
                        let tx = parseFloat(parts[1])
                        if (sysData.lastRx > 0) {
                            sysData.rawDownload = (rx - sysData.lastRx) / 2
                            sysData.rawUpload = (tx - sysData.lastTx) / 2
                            sysData.dlRatio = Math.min((sysData.rawDownload * cfg.dlSensitivity) / cfg.netMaxSpeed, 1.0)
                            sysData.ulRatio = Math.min((sysData.rawUpload * cfg.ulSensitivity) / cfg.netMaxSpeed, 1.0)
                            sysData.downloadStr = sysData.formatSpeed(sysData.rawDownload)
                            sysData.uploadStr = sysData.formatSpeed(sysData.rawUpload)
                        }
                        sysData.lastRx = rx
                        sysData.lastTx = tx
                    } else if (data.includes("up")) { 
                        sysData.netIcon = "󰖩"
                        sysData.isConnected = true 
                    } else if (data.includes("down")) { 
                        sysData.netIcon = "󰖪"
                        sysData.isConnected = false 
                    }
                }
            }
        }
        Timer { 
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                netProcess.running = false
                netProcess.running = true 
            } 
        }

        // --- ДИСК I/O (Скорость чтения/записи NVME) ---
        property real lastDiskRead: 0
        property real lastDiskWrite: 0
        property real rawDiskRead: 0
        property real rawDiskWrite: 0
        property real diskReadRatio: 0.0
        property real diskWriteRatio: 0.0
        property string diskReadStr: "0.0 B"
        property string diskWriteStr: "0.0 B"

        Process {
            id: diskIoProc
            command: ["sh", "-c", `awk '$3 == "${cfg.diskInterface}" {print $6 " " $10}' /proc/diskstats 2>/dev/null`]
            stdout: SplitParser {
                onRead: data => {
                    if (data.includes(" ")) {
                        let parts = data.trim().split(/\s+/)
                        if (parts.length >= 2) {
                            let rSectors = parseFloat(parts[0])
                            let wSectors = parseFloat(parts[1])
                            
                            let rBytes = rSectors * 512
                            let wBytes = wSectors * 512

                            if (sysData.lastDiskRead > 0) {
                                sysData.rawDiskRead = (rBytes - sysData.lastDiskRead) / 2
                                sysData.rawDiskWrite = (wBytes - sysData.lastDiskWrite) / 2
                                
                                sysData.diskReadRatio = Math.min((sysData.rawDiskRead * 5) / cfg.diskMaxSpeed, 1.0)
                                sysData.diskWriteRatio = Math.min((sysData.rawDiskWrite * 5) / cfg.diskMaxSpeed, 1.0)
                                
                                sysData.diskReadStr = sysData.formatSpeed(sysData.rawDiskRead)
                                sysData.diskWriteStr = sysData.formatSpeed(sysData.rawDiskWrite)
                            }
                            sysData.lastDiskRead = rBytes
                            sysData.lastDiskWrite = wBytes
                        }
                    }
                }
            }
        }
        Timer { 
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                diskIoProc.running = false
                diskIoProc.running = true 
            } 
        }

        // --- ПРОЦЕССОР (CPU %) ---
        property int cpuPercent: 0
        Process {
            id: cpuProc
            command: ["sh", "-c", "top -bn1 | awk '/^%Cpu/ {print $2+$4}'"]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseFloat(data.replace(',', '.'))
                    if (!isNaN(val)) {
                        sysData.cpuPercent = Math.round(val)
                    }
                }
            }
        }
        Timer { 
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                cpuProc.running = false
                cpuProc.running = true 
            } 
        }

        // --- ОПЕРАТИВНАЯ ПАМЯТЬ (RAM) ---
        property int ramBlocks: 0
        Process {
            id: ramProc
            command: ["sh", "-c", "free | awk '/Mem:/ {print $3/$2}'"]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseFloat(data.replace(',', '.'))
                    if (!isNaN(val)) {
                        sysData.ramBlocks = Math.round(val * 24)
                    }
                }
            }
        }
        Timer { 
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                ramProc.running = false
                ramProc.running = true 
            } 
        }

        // --- МЕСТО НА ДИСКЕ (Storage %) ---
        property int storagePercent: 0
        Process {
            id: diskSpaceProc
            command: ["sh", "-c", "df / | awk 'NR==2 {print $5}' | tr -d '%'"]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseInt(data)
                    if (!isNaN(val)) {
                        sysData.storagePercent = val
                    }
                }
            }
        }
        Timer { 
            interval: 60000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                diskSpaceProc.running = false
                diskSpaceProc.running = true 
            } 
        }

        // --- ТЕМПЕРАТУРА (CPU и GPU) ---
        property int temp1: 0
        property int temp2: 0
        Process {
            id: tempProc
            property int lineCount: 0
            command: ["sh", "-c", "sensors | grep -E 'Tctl|edge' | awk '{print $2}' | tr -d '+°C'"]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseFloat(data)
                    if (!isNaN(val)) {
                        if (tempProc.lineCount === 0) {
                            sysData.temp1 = Math.round(val) 
                        } else if (tempProc.lineCount === 1) {
                            sysData.temp2 = Math.round(val) 
                        }
                        tempProc.lineCount++
                    }
                }
            }
            onExited: { 
                lineCount = 0 
            }
        }
        Timer { 
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                tempProc.running = false
                tempProc.running = true 
            } 
        }

        // --- ВЕНТИЛЯТОРЫ (FAN 1 и FAN 2) ---
        property real fan1Ratio: 0.0
        property real fan2Ratio: 0.0
        Process {
            id: fan1Proc
            command: ["sh", "-c", `sensors | grep -i '${cfg.fan1Name}' | awk '{print $2}'`]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseFloat(data)
                    if (!isNaN(val)) {
                        sysData.fan1Ratio = Math.min(val / cfg.fan1MaxRpm, 1.0)
                    } else {
                        sysData.fan1Ratio = 0.0
                    }
                }
            }
        }
        Timer { 
            interval: 3000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                fan1Proc.running = false
                fan1Proc.running = true 
            } 
        }

        Process {
            id: fan2Proc
            command: ["sh", "-c", `sensors | grep -i '${cfg.fan2Name}' | awk '{print $2}'`]
            stdout: SplitParser {
                onRead: data => {
                    let val = parseFloat(data)
                    if (!isNaN(val)) {
                        sysData.fan2Ratio = Math.min(val / cfg.fan2MaxRpm, 1.0)
                    } else {
                        sysData.fan2Ratio = 0.0
                    }
                }
            }
        }
        Timer { 
            interval: 3000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { 
                fan2Proc.running = false
                fan2Proc.running = true 
            } 
        }
    }


    // =========================================================
    // ОКНО 1: ЛЕВЫЙ БАР
    // =========================================================
    PanelWindow {
        id: leftBar
        
        anchors { 
            top: true
            bottom: true
            left: true 
        }
        
        implicitWidth: cfg.barWidth + 15
        color: "transparent" 
        exclusiveZone: cfg.barWidth 

        Rectangle {
            id: mainBar
            width: cfg.barWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            color: cfg.bgColor

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 10

                Text {
                    text: "󰣇"
                    font.pixelSize: 26
                    Layout.alignment: Qt.AlignHCenter
                    color: cfg.existingColor
                }

                // --- СЕПАРАТОР 1 ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 0
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 2
                        color: cfg.sepColor 
                    }
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 1
                        color: cfg.sepLightColor 
                    }
                }

                // --- ВОРКСПЕЙСЫ ---
                ColumnLayout {
                    id: workspacesLayout
                    spacing: 8
                    Layout.alignment: Qt.AlignHCenter
                    property var workspaces: []

                    function updateWorkspaces(wArray) {
                        wArray.sort((a, b) => {
                            let labelA = a.name ? a.name : a.id.toString()
                            let labelB = b.name ? b.name : b.id.toString()
                            let numA = parseInt(labelA)
                            let numB = parseInt(labelB)
                            if (!isNaN(numA) && !isNaN(numB)) return numA - numB
                            return labelA > labelB ? 1 : -1
                        })
                        
                        let arr = []
                        for (let i = 0; i < 10; i++) {
                            if (i < wArray.length) {
                                let w = wArray[i]
                                w.exists = true 
                                arr.push(w)
                            } else {
                                arr.push({ name: (i + 1).toString(), is_focused: false, exists: false, id: -1 })
                            }
                        }
                        workspaces = arr
                    }

                    Process {
                        command: ["niri", "msg", "-j", "workspaces"]
                        running: true
                        stdout: SplitParser { 
                            onRead: data => { 
                                try { 
                                    let w = JSON.parse(data)
                                    if (Array.isArray(w)) {
                                        workspacesLayout.updateWorkspaces(w) 
                                    }
                                } catch(e) {} 
                            } 
                        }
                    }

                    Process {
                        command: ["niri", "msg", "-j", "event-stream"]
                        running: true
                        stdout: SplitParser {
                            onRead: data => {
                                try {
                                    let event = JSON.parse(data)
                                    if (event.WorkspacesChanged) {
                                        workspacesLayout.updateWorkspaces(event.WorkspacesChanged.workspaces)
                                    } else if (event.WorkspaceActivated) {
                                        let w = workspacesLayout.workspaces
                                        for (let i = 0; i < w.length; i++) {
                                            if (w[i].id !== -1) {
                                                w[i].is_focused = (w[i].id === event.WorkspaceActivated.id)
                                            }
                                        }
                                        workspacesLayout.workspaces = Array.from(w)
                                    }
                                } catch(e) {}
                            }
                        }
                    }

                    GridLayout {
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 6
                        Layout.alignment: Qt.AlignHCenter

                        Repeater {
                            model: workspacesLayout.workspaces
                            Item {
                                width: 14
                                height: 36 
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: 2 
                                    border.color: modelData.is_focused ? cfg.accentColor : cfg.inactiveColor
                                    
                                    Behavior on border.color { 
                                        ColorAnimation { 
                                            duration: 150 
                                        } 
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 5 
                                        color: modelData.exists ? cfg.existingColor : cfg.inactiveColor
                                        
                                        Behavior on color { 
                                            ColorAnimation { 
                                                duration: 150 
                                            } 
                                        }
                                    }
                                }
                                
                                MouseArea { 
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { 
                                        clickProc.command = ["niri", "msg", "action", "focus-workspace", modelData.name ? modelData.name : modelData.id.toString()]
                                        clickProc.running = true 
                                    } 
                                }
                            }
                        }
                    }
                }

                Item { 
                    Layout.fillHeight: true 
                }

                // --- СЕПАРАТОР 2 ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 0
                    
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 2
                        color: cfg.sepColor 
                    }
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 1
                        color: cfg.sepLightColor 
                    }
                }

                // --- СЕТЬ ---
                Item {
                    id: netWidgetContainer 
                    Layout.preferredWidth: cfg.barWidth
                    Layout.preferredHeight: 100
                    Layout.alignment: Qt.AlignHCenter

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text { 
                            text: sysData.netIcon
                            color: sysData.isConnected ? cfg.accentColor : cfg.inactiveColor
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 0
                            Layout.rightMargin: 5
                        }

                        RowLayout {
                            spacing: 6
                            Layout.alignment: Qt.AlignHCenter
                            
                            Column {
                                spacing: 2
                                Repeater {
                                    model: 8
                                    Rectangle {
                                        width: 10
                                        height: 3
                                        color: index >= 12 - Math.round(sysData.dlRatio * 12) ? cfg.accentColor : cfg.inactiveColor
                                    }
                                }
                            }
                            Column {
                                spacing: 2
                                Repeater {
                                    model: 8
                                    Rectangle {
                                        width: 10
                                        height: 3
                                        color: index >= 12 - Math.round(sysData.ulRatio * 12) ? cfg.textColor : cfg.inactiveColor
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.alignment: Qt.AlignHCenter
                            
                            Text { 
                                text: sysData.downloadStr
                                color: cfg.accentColor
                                font.pixelSize: 12
                                font.family: "AurulentSansMNerdFontPropo"
                                horizontalAlignment: Text.AlignHCenter
                                Layout.alignment: Qt.AlignHCenter 
                            }
                            
                            Text { 
                                text: sysData.uploadStr
                                color: cfg.textColor
                                font.pixelSize: 12
                                font.family: "AurulentSansMNerdFontPropo"
                                horizontalAlignment: Text.AlignHCenter
                                Layout.alignment: Qt.AlignHCenter 
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Date.now() - wifiPopup.lastCloseTime < 150) return
                            wifiPopup.visible = !wifiPopup.visible
                        }
                    }
                }

                // --- СЕПАРАТОР 3 ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: -2
                    spacing: 0
                    
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 2
                        color: cfg.sepColor 
                    }
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 1
                        color: cfg.sepLightColor 
                    }
                }

                // --- ГРОМКОСТЬ ---
                ColumnLayout {
                    id: volWidget
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    property real volume: 0.0
                    property bool isMuted: false

                    Text {
                        text: volWidget.isMuted ? "󰝟" : (volWidget.volume > 0.5 ? "󰕾" : (volWidget.volume > 0 ? "󰖀" : "󰕿"))
                        color: volWidget.isMuted ? cfg.inactiveColor : cfg.accentColor
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 0
                        Layout.leftMargin: 2
                    }

                    Item {
                        width: 14
                        height: 38 
                        Layout.alignment: Qt.AlignHCenter
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: 8
                                Rectangle {
                                    width: 14
                                    height: 3
                                    color: {
                                        if (volWidget.isMuted) return cfg.inactiveColor
                                        return index >= 10 - Math.round(volWidget.volume * 10) ? cfg.accentColor : cfg.inactiveColor
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -10
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton 

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    volActionProc.command = [cfg.mixerCmd]
                                    volActionProc.running = true
                                } else {
                                    volActionProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                                    volActionProc.running = true
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    volActionProc.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"]
                                } else {
                                    volActionProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
                                }
                                volActionProc.running = true
                                volProcess.running = false
                                volProcess.running = true
                            }
                        }
                    }

                    Text { 
                        text: Math.round(volWidget.volume * 100) + "%"
                        color: volWidget.isMuted ? cfg.inactiveColor : cfg.textColor
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "AurulentSansMNerdFontPropo"
                        Layout.alignment: Qt.AlignHCenter 
                    }

                    Process {
                        id: volProcess
                        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                        stdout: SplitParser { 
                            onRead: data => { 
                                if (data.includes("Volume:")) { 
                                    let parts = data.split(" ")
                                    if (parts.length >= 2) { 
                                        volWidget.volume = parseFloat(parts[1])
                                        volWidget.isMuted = data.includes("[MUTED]") 
                                    } 
                                } 
                            } 
                        }
                    }
                    
                    Process { 
                        id: volActionProc
                        running: false 
                    }
                    
                    Timer { 
                        interval: 500
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: { 
                            volProcess.running = false
                            volProcess.running = true 
                        } 
                    }
                }

                // --- СЕПАРАТОР 4 ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 0
                    
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 2
                        color: cfg.sepColor 
                    }
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 1
                        color: cfg.sepLightColor 
                    }
                }

                // --- БАТАРЕЯ (Телепортирована наверх и сделана баром) ---
                ColumnLayout {
                    id: batteryWidget
                    spacing: 6
                    Layout.alignment: Qt.AlignHCenter
                    
                    property int capacity: 0
                    property string status: "Unknown"
                    property int readStep: 0

                    Text { 
                        text: batteryWidget.status === "Charging" ? "⚡" : "󰁹"
                        color: cfg.accentColor 
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignHCenter 
                        Layout.bottomMargin: 0
                        Layout.leftMargin: -1
                    }
                    
                    Item {
                        width: 14
                        height: 38 
                        Layout.alignment: Qt.AlignHCenter
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: 8
                                Rectangle {
                                    width: 14
                                    height: 3
                                    
                                    color: {
                                        let activeBlocks = Math.round((batteryWidget.capacity / 100.0) * 8)
                                        if (index >= 8 - activeBlocks) {
                                            if (batteryWidget.status === "Charging") {
                                                return cfg.accentColor
                                            }
                                            if (batteryWidget.capacity <= 20) {
                                                return cfg.accentColor
                                            }
                                            return cfg.accentColor
                                        }
                                        return cfg.inactiveColor
                                    }
                                }
                            }
                        }
                    }

                    Text { 
                        text: batteryWidget.capacity + "%"
                        color: batteryWidget.status === "Charging" ? cfg.textColor : (batteryWidget.capacity <= 20 ? cfg.accentColor : cfg.textColor)
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "AurulentSansMNerdFontPropo"
                        Layout.alignment: Qt.AlignHCenter 
                    }
                    
                    Process {
                        id: batProcess
                        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1"]
                        stdout: SplitParser { 
                            onRead: data => { 
                                if (batteryWidget.readStep === 0) { 
                                    let val = parseInt(data)
                                    if (!isNaN(val)) {
                                        batteryWidget.capacity = val
                                    }
                                    batteryWidget.readStep = 1 
                                } else {
                                    batteryWidget.status = data 
                                }
                            } 
                        }
                        onExited: { 
                            batteryWidget.readStep = 0 
                        }
                    }
                    
                    Timer { 
                        interval: 10000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: { 
                            batProcess.running = false
                            batProcess.running = true 
                        } 
                    }
                }

                // --- СЕПАРАТОР 5 (Перед треем - скрывается, если трей пуст) ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 0
                    visible: trayLayout.visible 
                    
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 2
                        color: cfg.sepColor 
                    }
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 1
                        color: cfg.sepLightColor 
                    }
                }

                // --- СИСТЕМНЫЙ ТРЕЙ (Телепортирован вниз) ---
                ColumnLayout {
                    id: trayLayout
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    
                    visible: trayRepeater.count > 0

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items
                        delegate: Item {
                            width: 24
                            height: 24

                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                antialiasing: true
                            }

                            QsMenuAnchor {
                                id: menuAnchor
                                menu: modelData.menu
                                anchor {
                                    item: trayMouse
                                    edges: Edges.Right | Edges.Bottom
                                    gravity: Edges.Right | Edges.Top
                                }
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (typeof modelData.activate === "function") {
                                            modelData.activate()
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        if (typeof modelData.secondaryActivate === "function") {
                                            modelData.secondaryActivate()
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        menuAnchor.open()
                                    }
                                }
                                
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y !== 0 && typeof modelData.scroll === "function") {
                                        modelData.scroll(wheel.angleDelta.y, "vertical")
                                    }
                                }
                            }
                        }
                    }
                }

                // --- СЕПАРАТОР 6 (Перед часами) ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 0
                    
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 2
                        color: cfg.sepColor 
                    }
                    Rectangle { 
                        width: cfg.barWidth - 12
                        height: 1
                        color: cfg.sepLightColor 
                    }
                }

                // --- ЧАСЫ ---
                Item {
                    id: clockContainer 
                    Layout.preferredWidth: cfg.barWidth
                    Layout.preferredHeight: 40 
                    Layout.alignment: Qt.AlignHCenter

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        color: cfg.existingColor
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "AurulentSansMNerdFontPropo"
                        horizontalAlignment: Text.AlignHCenter
                        
                        Component.onCompleted: { 
                            clockText.text = Qt.formatDateTime(new Date(), "hh\nmm") 
                        }
                        
                        Timer { 
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: { 
                                clockText.text = Qt.formatDateTime(new Date(), "hh\nmm") 
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Date.now() - calPopup.lastCloseTime < 150) return
                            calPopup.visible = !calPopup.visible
                        }
                    }
                }
            }
        }

        // Тень
        Rectangle {
            width: 15
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: mainBar.right

            gradient: Gradient {
                orientation: Gradient.Horizontal
                
                GradientStop { 
                    position: 0.0
                    color: "#A6000000" 
                } 
                
                GradientStop { 
                    position: 1.0
                    color: "transparent" 
                } 
            }
        }

        Process { 
            id: clickProc
            running: false 
        }

        // --- ВСПЛЫВАЮЩЕЕ ОКНО: WI-FI МЕНЮ ---
        PopupWindow {
            id: wifiPopup
            visible: false
            color: "transparent"
            implicitWidth: 320
            implicitHeight: 450
            
            property double lastCloseTime: 0
            
            anchor { 
                item: netWidgetContainer
                edges: Edges.Right | Edges.Bottom
                gravity: Edges.Right | Edges.Top 
            }

            MouseArea { 
                anchors.fill: parent
                onClicked: { 
                    wifiPopup.lastCloseTime = Date.now()
                    wifiPopup.visible = false 
                } 
            }

            Rectangle {
                id: wifiRect
                focus: true
                
                onActiveFocusChanged: { 
                    if (!activeFocus && wifiPopup.visible) { 
                        wifiPopup.lastCloseTime = Date.now()
                        wifiPopup.visible = false 
                    } 
                }

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 0
                anchors.leftMargin: 10    

                width: 300
                height: 400
                color: cfg.popupBgColor
                border.color: cfg.inactiveColor
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
                            color: cfg.accentColor
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "AurulentSansMNerdFontPropo"
                            Layout.fillWidth: true 
                        }
                        
                        Rectangle {
                            width: 24
                            height: 24
                            color: cfg.inactiveColor
                            
                            Text { 
                                text: "󰑐"
                                color: cfg.textColor
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
                        color: cfg.accentColor 
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        
                        ListView {
                            model: wifiModel
                            spacing: 4
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 36
                                color: wMouseArea.containsMouse ? cfg.inactiveColor : "transparent"
                                border.color: model.inUse ? cfg.accentColor : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    
                                    Text { 
                                        text: model.inUse ? "󰖩" : (model.signal > 70 ? "󰤨" : (model.signal > 40 ? "󰤥" : "󰤢"))
                                        color: model.inUse ? cfg.accentColor : cfg.textColor
                                        font.pixelSize: 16 
                                    }
                                    
                                    Text { 
                                        text: model.ssid
                                        color: model.inUse ? cfg.accentColor : cfg.textColor
                                        font.pixelSize: 13
                                        font.family: "monospace"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight 
                                    }
                                    
                                    Text { 
                                        text: model.secured ? "" : ""
                                        color: cfg.accentColor
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
                                            wifiConnectProc.command = [ 
                                                "sh", "-c", 
                                                "pass=$(zenity --password --title=\"Auth: $1\") && [ -n \"$pass\" ] && nmcli dev wifi connect \"$1\" password \"$pass\"", 
                                                "--", model.ssid 
                                            ]
                                            wifiConnectProc.running = true
                                            wifiPopup.visible = false 
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

            ListModel { 
                id: wifiModel 
            }

            Process {
                id: wifiScanProc
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
                id: wifiConnectProc
                onExited: { 
                    wifiModel.clear()
                    wifiScanProc.running = true 
                } 
            }
            
            onVisibleChanged: { 
                if (visible) { 
                    wifiRect.forceActiveFocus()
                    wifiModel.clear()
                    wifiScanProc.running = true 
                } 
            }
        }

        // --- ВСПЛЫВАЮЩЕЕ ОКНО: КАЛЕНДАРЬ ---
        PopupWindow {
            id: calPopup
            visible: false
            color: "transparent" 
            implicitWidth: 320
            implicitHeight: 450 
            
            property double lastCloseTime: 0

            anchor { 
                item: clockContainer
                edges: Edges.Right | Edges.Bottom
                gravity: Edges.Right | Edges.Top 
            }

            MouseArea { 
                anchors.fill: parent
                onClicked: { 
                    calPopup.lastCloseTime = Date.now()
                    calPopup.visible = false 
                } 
            }

            Rectangle {
                id: calRect
                focus: true
                onActiveFocusChanged: { 
                    if (!activeFocus && calPopup.visible) { 
                        calPopup.lastCloseTime = Date.now()
                        calPopup.visible = false 
                    } 
                }

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 0
                anchors.leftMargin: 10    

                width: 270
                height: 400
                color: cfg.popupBgColor
                border.color: cfg.inactiveColor
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
                        color: cfg.accentColor
                        font.pixelSize: 36
                        font.bold: true
                        font.family: "monospace"
                        Layout.alignment: Qt.AlignHCenter 
                    }
                    
                    Text { 
                        id: popupDate
                        color: cfg.textColor
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
                            color: cfg.inactiveColor
                            font.family: "monospace" 
                        }
                        
                        Text {
                            id: popupRegion
                            color: cfg.accentColor
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
                        color: cfg.accentColor
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
                                color: (index > 4) ? cfg.accentColor : cfg.inactiveColor
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
                                color: (index + 1 === new Date().getDate()) ? cfg.accentColor : "transparent"
                                border.color: (index + 1 === new Date().getDate()) ? "transparent" : cfg.inactiveColor
                                border.width: 1
                                
                                Text { 
                                    anchors.centerIn: parent
                                    text: index + 1
                                    color: (index + 1 === new Date().getDate()) ? cfg.bgColor : cfg.textColor
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
                running: calPopup.visible
                repeat: true
                onTriggered: { 
                    popupTime.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                    popupDate.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd") 
                } 
            }
            
            onVisibleChanged: { 
                if (visible) { 
                    calRect.forceActiveFocus()
                    popupTime.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                    popupDate.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd") 
                } 
            }
        }
    }


    // =========================================================
    // ОКНО 2: КИБЕР-ВИДЖЕТЫ НА РАБОЧИЙ СТОЛ
    // =========================================================
    PanelWindow {
        id: desktopWidgets
        
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

            GridLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: cfg.barWidth + 40
                columns: 2
                columnSpacing: 60
                rowSpacing: 40

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
                    }
                    
                    ColumnLayout {
                        spacing: 8
                        Row {
                            spacing: 6
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
                                text: sysData.diskWriteStr
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
