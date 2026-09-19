import Quickshell
import Quickshell.Wayland
import QtQuick

import "./widgets"

// Daemon QuickShell — Control Center + Mini Dynamic Island (iPhone 17 / Mac Notch) via FIFO
ShellRoot {
    id: shellRoot

    ControlCenter {
        id: controlCenter
        isIslandActive: dynamicIsland.shown && !dynamicIsland.isClosing
        onRequestIslandGlide: dynamicIsland.glideToControlCenter()
        onMorphToIslandRequested: dynamicIsland.morphFromControlCenter()
        onToggleMiniIslandRequested: dynamicIsland.toggleIsland()
        onMiniIslandDismissRequested: dynamicIsland.hideIsland()
        onWallpaperChanged: (path) => {
            desktopClock.setWallpaper(path)
            dynamicIsland.setWallpaper(path)
        }
        onOpenLaunchpadRequested: {
            console.log("[SHELL.QML] onOpenLaunchpadRequested received!")
            launchpad.toggleLaunchpad()
        }
    }

    DynamicIsland {
        id: dynamicIsland
        glassBgColor: controlCenter.glassBgColor
        glassHoverColor: controlCenter.glassHoverColor
        accentColor: controlCenter.accentColor
        mediaStat: controlCenter.mediaStat
        mediaTitle: controlCenter.mediaTitle
        mediaArtist: controlCenter.mediaArtist
        onMorphToControlCenterRequested: {
            controlCenter.morphFromIsland()
        }
        onExpandRequested: {
            dynamicIsland.glideToControlCenter()
        }
    }

    ClockWidget {
        id: desktopClock
    }

    Launchpad {
        id: launchpad
    }
}
