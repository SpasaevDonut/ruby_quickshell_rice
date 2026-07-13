//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland

ShellRoot {
    Config { id: cfg }
    SysData { id: sysData }
    LeftBar { sysData: sysData; cfg: cfg }
    DesktopWidgets { sysData: sysData; cfg: cfg }
}
