import QtQuick

QtObject {
    // --- ЦВЕТА И ТЕМА ---
    property string bgColor: "#202020"       
    property string popupBgColor: "#1a1a1a"  
    property string sepColor: "#161616"
    property string sepLightColor: "#404040"
    property string accentColor: "#9b0715"   // Красный (Активный фокус)
    property string inactiveColor: "#505050" // Темно-серый (Пустые слоты / рамки)
    property string existingColor: "#a0a0a0" // Белый (Существующие воркспейсы на фоне)
    property string textColor: "#a0a0a0"     
    
    // --- РАЗМЕРЫ ---
    property int barWidth: 46 

    // --- СЕТЬ ---
    property string netInterface: "wlo1"
    property real netMaxSpeed: 20971520 // 20 MB/s для визуала заполнения полосок
    property real dlSensitivity: 1.5 
    property real ulSensitivity: 2.0 

    // --- ДИСК ---
    property string diskInterface: "nvme0n1"
    property real diskMaxSpeed: 524288000 // 500 MB/s - макс. скорость для визуала I/O

    // --- ВЕНТИЛЯТОРЫ ---
    property string fan1Name: "fan1" 
    property real fan1MaxRpm: 5000   

    property string fan2Name: "fan2"
    property real fan2MaxRpm: 5000

    // --- КОМАНДЫ (Терминал и Микшер) ---
    property string terminalCmd: "kitty" 
    property string mixerCmd: "pwvucontrol" 
}
