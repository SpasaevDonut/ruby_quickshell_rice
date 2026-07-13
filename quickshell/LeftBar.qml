//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland

PanelWindow {
    id: leftBar
    
    property QtObject sysData: null
    property QtObject cfg: null
    
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
            spacing: 5

            // --- ЛОГО / КНОПКА ПИТАНИЯ ---
            Item {
                id: archLogoContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: cfg.barWidth
                Layout.preferredHeight: 36
                
                Text {
                    text: "󰣇"
                    font.pixelSize: 26
                    anchors.centerIn: parent
                    color: archMouseArea.containsMouse ? cfg.accentColor : cfg.existingColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: archMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Date.now() - powerPopup.lastCloseTime < 150) return
                        powerPopup.visible = !powerPopup.visible
                    }
                }
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
                property int activeWorkspaceId: -1 // Сохраняем ID активного воркспейса для окон

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
                            if (w.is_focused) activeWorkspaceId = w.id
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
                                // --- РАСКЛАДКА ---
                                if (event.KeyboardLayoutsChanged) {
                                    layoutWidget.layouts = event.KeyboardLayoutsChanged.keyboard_layouts.names
                                    layoutWidget.currentIndex = event.KeyboardLayoutsChanged.keyboard_layouts.current_idx
                                } else if (event.KeyboardLayoutSwitched) {
                                    layoutWidget.currentIndex = event.KeyboardLayoutSwitched.idx
                                }
                                
                                if (event.WorkspacesChanged) {
                                    workspacesLayout.updateWorkspaces(event.WorkspacesChanged.workspaces)
                                } else if (event.WorkspaceActivated) {
                                    workspacesLayout.activeWorkspaceId = event.WorkspaceActivated.id
                                    let w = workspacesLayout.workspaces
                                    for (let i = 0; i < w.length; i++) {
                                        if (w[i].id !== -1) {
                                            w[i].is_focused = (w[i].id === event.WorkspaceActivated.id)
                                        }
                                    }
                                    workspacesLayout.workspaces = Array.from(w)
                                }
                                
                                // --- ОБНОВЛЕНИЕ ОКОН ПРИ ИЗМЕНЕНИЯХ ---
                                if (event.WindowOpened || event.WindowClosed || event.WindowFocusChanged || event.WorkspaceActivated || event.WorkspaceActiveWindowChanged) {
                                    windowsProcess.running = false
                                    windowsProcess.running = true
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

                // --- СЕПАРАТОР 1.5 (Отделяет воркспейсы от списка окон) ---
                Column {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
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

                // --- ОТКРЫТЫЕ ОКНА (Новый виджет в виде скроллящегося ListView) ---
                ListView {
                    id: windowsLayout
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: cfg.barWidth
                    Layout.fillHeight: true // Забирает всё свободное место (работает вместо распорки)
                    spacing: 8
                    clip: true // Важно! Обрезает контент при прокрутке, чтобы не залезал на другие виджеты
                    boundsBehavior: Flickable.StopAtBounds // Убирает "пружинящий" эффект
                    
                    property var allWindows: []
                    
                    // Фильтруем по воркспейсу, сортируем и ГРУППИРУЕМ по названию приложения
                    property var groupedWindowsArray: {
                        let activeWs = workspacesLayout.activeWorkspaceId
                        let filtered = allWindows.filter(w => w.workspace_id === activeWs)
                        filtered.sort((a, b) => a.id - b.id)

                        let groups = []
                        for (let i = 0; i < filtered.length; i++) {
                            let w = filtered[i]
                            
                            let name = w.app_id ? w.app_id : (w.title ? w.title : "APP")
                            let parts = name.split('.')
                            let shortName = parts[parts.length - 1].toUpperCase()

                            // Кастомные замены
                            if (shortName.includes("KITTY") || shortName.includes("ALACRITTY") || shortName.includes("FOOT")) shortName = "TERM"
                            else if (shortName.includes("FIREFOX")) shortName = "FFOX"
                            else if (shortName.includes("CHROME") || shortName.includes("BRAVE")) shortName = "WEB"
                            else if (shortName.includes("TELEGRAM")) shortName = "TG"
                            else if (shortName.includes("DISCORD")) shortName = "DSCD"
                            else if (shortName.includes("DOLPHIN") || shortName.includes("NEMO")) shortName = "FILE"
                            else if (shortName.includes("CODE")) shortName = "CODE"
                            else shortName = shortName.replace(/[-_]/g, '').substring(0, 5)

                            // Ищем, есть ли уже такая группа
                            let existingGroup = groups.find(g => g.appNameRaw === shortName)
                            if (existingGroup) {
                                existingGroup.windows.push(w)
                                if (w.is_focused) {
                                    existingGroup.isFocused = true
                                }
                            } else {
                                // Создаем новую группу
                                groups.push({
                                    appNameRaw: shortName,
                                    appName: shortName.split('').join('\n'), // Вертикальный текст
                                    windows: [w],
                                    isFocused: w.is_focused
                                })
                            }
                        }
                        return groups
                    }

                    model: groupedWindowsArray

                    Process {
                        id: windowsProcess
                        command: ["niri", "msg", "-j", "windows"]
                        running: true
                        stdout: SplitParser {
                            onRead: data => {
                                try {
                                    let wins = JSON.parse(data)
                                    windowsLayout.allWindows = wins
                                } catch(e) {}
                            }
                        }
                    }

                    Process {
                        id: winClickProc
                        running: false
                    }

                    delegate: Item {
                        width: ListView.view.width
                        
                        // Высота зависит от контента (текста или точек, смотря что длиннее)
                        height: contentRow.height + 16

                        property bool isFocused: modelData.isFocused
                        property string appName: modelData.appName
                        property color itemColor: isFocused ? cfg.accentColor : cfg.textColor

                        // Горизонтальный ряд для расположения [Скобка] - [Текст] - [Точки]
                        Row {
                            id: contentRow
                            anchors.centerIn: parent
                            spacing: 6
                            height: Math.max(appNameText.implicitHeight, dotsColumn.implicitHeight)

                            // 1. Выемка/скобка `[` слева от текста
                            Item {
                                width: 4
                                height: appNameText.implicitHeight + 4 // Привязка скобки строго к высоте текста
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle { 
                                    width: parent.width; height: 1; color: itemColor
                                    anchors.left: parent.left; anchors.top: parent.top 
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Rectangle { 
                                    width: 3; height: parent.height; color: itemColor
                                    anchors.left: parent.left; anchors.top: parent.top 
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Rectangle { 
                                    width: parent.width; height: 1; color: itemColor
                                    anchors.left: parent.left; anchors.bottom: parent.bottom 
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            // 2. Текст по центру (вертикально)
                            Text {
                                id: appNameText
                                text: appName
                                color: itemColor
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "monospace"
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 0.9 
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // 3. Точки справа (по одной на каждое окно)
                            Column {
                                id: dotsColumn
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Repeater {
                                    model: modelData.windows
                                    delegate: Rectangle {
                                        width: 4
                                        height: 4
                                        // Если окно в фокусе — красная, иначе тускло-серая
                                        color: modelData.is_focused ? cfg.accentColor : cfg.existingColor
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.RightButton) {
                                                    var pos = parent.mapToItem(null, parent.width, 0)
                                                    winMenu.targetX = pos.x
                                                    winMenu.targetY = pos.y
                                                    winMenu.targetWindowId = modelData.id
                                                    winMenu.workspaces = workspacesLayout.workspaces
                                                    winMenu.menuWidth = 240
                                                    winMenu.menuHeight = 420
                                                    winMenu.visible = true
                                                    return
                                                }
                                                winClickProc.command = ["niri", "msg", "action", "focus-window", "--id", modelData.id.toString()]
                                                winClickProc.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Общий клик по названию/скобке
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    let targetId = modelData.windows[0].id
                                    for (let i = 0; i < modelData.windows.length; i++) {
                                        if (modelData.windows[i].is_focused) {
                                            targetId = modelData.windows[i].id
                                            break
                                        }
                                    }
                                    var pos = parent.mapToItem(null, parent.width, 0)
                                    winMenu.targetX = pos.x
                                    winMenu.targetY = pos.y
                                    winMenu.targetWindowId = targetId
                                    winMenu.workspaces = workspacesLayout.workspaces
                                    winMenu.menuWidth = 240
                                    winMenu.menuHeight = 420
                                    winMenu.visible = true
                                    return
                                }
                                let targetId = modelData.windows[0].id
                                for (let i = 0; i < modelData.windows.length; i++) {
                                    if (modelData.windows[i].is_focused) {
                                        targetId = modelData.windows[i].id
                                        break
                                    }
                                }
                                winClickProc.command = ["niri", "msg", "action", "focus-window", "--id", targetId.toString()]
                                winClickProc.running = true
                            }
                        }
                    }
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
                        spacing: 4

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
                    spacing: 2 
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

                // --- СЕПАРАТОР (Перед раскладкой) ---
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

                // --- ИНДИКАТОР РАСКЛАДКИ ---
                Item {
                    id: layoutWidget
                    Layout.preferredWidth: cfg.barWidth
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignHCenter
                    
                    property var layouts: []
                    property int currentIndex: 0

                    Text {
                        anchors.centerIn: parent
                    text: layoutWidget.layouts.length > 0 ? (layoutWidget.layouts[layoutWidget.currentIndex].includes("Russian") ? "RU" : "EN") : "--"
                    color: cfg.textColor
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        layoutActionProc.running = true
                    }
                }

                Process {
                    id: layoutProcess
                    command: ["niri", "msg", "-j", "keyboard-layouts"]
                    running: true
                    stdout: SplitParser {
                        onRead: data => {
                            try {
                                let obj = JSON.parse(data)
                                layoutWidget.layouts = obj.names
                                layoutWidget.currentIndex = obj.current_idx
                                layoutProcess.running = false // Выключаем процесс после инициализации
                            } catch(e) {}
                        }
                    }
                    }
                    
                    Process {
                        id: layoutActionProc
                        command: ["niri", "msg", "action", "switch-layout"]
                        running: false
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

                             QsMenuAnchor {
                                 id: menuAnchor
                                 menu: modelData.menu
                                 anchor {
                                     item: trayMouse
                                     edges: Edges.Right | Edges.Bottom
                                     gravity: Edges.Right | Edges.Top
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

        // --- ВСПЛЫВАЮЩЕЕ ОКНО: МЕНЮ ПИТАНИЯ ---
        PowerPopup {
            id: powerPopup
            popupSysData: sysData
            popupCfg: cfg
            anchorItem: archLogoContainer
        }

        // --- ВСПЛЫВАЮЩЕЕ ОКНО: WI-FИ МЕНЮ ---
        WifiPopup {
            id: wifiPopup
            popupSysData: sysData
            popupCfg: cfg
            anchorItem: netWidgetContainer
        }

        // --- ВСПЛЫВАЮЩЕЕ ОКНО: КАЛЕНДАРЬ ---
        CalendarPopup {
            id: calPopup
            popupSysData: sysData
            popupCfg: cfg
            anchorItem: clockContainer
        }

        // --- КОНТЕКСТНОЕ МЕНЮ ОКОН ---
        WindowMenu {
            id: winMenu
            popupCfg: cfg
            parentWin: leftBar
        }
    }
}
