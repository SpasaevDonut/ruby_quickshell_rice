//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    
    // =========================================================
    // ГЛОБАЛЬНЫЙ МЕНЕДЖЕР ДАННЫХ (Опрашивает систему 1 раз)
    // =========================================================
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
                    if (lastRx > 0) {
                        rawDownload = (rx - lastRx) / 2
                        rawUpload = (tx - lastTx) / 2
                        dlRatio = Math.min((rawDownload * cfg.dlSensitivity) / cfg.netMaxSpeed, 1.0)
                        ulRatio = Math.min((rawUpload * cfg.ulSensitivity) / cfg.netMaxSpeed, 1.0)
                        downloadStr = formatSpeed(rawDownload)
                        uploadStr = formatSpeed(rawUpload)
                    }
                    lastRx = rx
                    lastTx = tx
                } else if (data.includes("up")) { 
                    netIcon = "󰖩"
                    isConnected = true 
                } else if (data.includes("down")) { 
                    netIcon = "󰖪"
                    isConnected = false 
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

                        if (lastDiskRead > 0) {
                            rawDiskRead = (rBytes - lastDiskRead) / 2
                            rawDiskWrite = (wBytes - lastDiskWrite) / 2
                            
                            diskReadRatio = Math.min((rawDiskRead * 5) / cfg.diskMaxSpeed, 1.0)
                            diskWriteRatio = Math.min((rawDiskWrite * 5) / cfg.diskMaxSpeed, 1.0)
                            
                            diskReadStr = formatSpeed(rawDiskRead)
                            diskWriteStr = formatSpeed(rawDiskWrite)
                        }
                        lastDiskRead = rBytes
                        lastDiskWrite = wBytes
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
                    cpuPercent = Math.round(val)
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
                    ramBlocks = Math.round(val * 24)
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
                    storagePercent = val
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
                        temp1 = Math.round(val) 
                    } else if (tempProc.lineCount === 1) {
                        temp2 = Math.round(val) 
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
                    fan1Ratio = Math.min(val / cfg.fan1MaxRpm, 1.0)
                } else {
                    fan1Ratio = 0.0
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
                    fan2Ratio = Math.min(val / cfg.fan2MaxRpm, 1.0)
                } else {
                    fan2Ratio = 0.0
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
