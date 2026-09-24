import QtQuick
import "."

// Vidro líquido para as variantes: posiciona a amostra do backdrop a partir do host (+ deslocamento local).
LiquidGlass {
    id: g
    property Item host
    property real offsetX: 0
    property real offsetY: 0
    sharedBackdrop: host ? host.sharedBackdrop : null
    widgetX: (host ? host.x : 0) + offsetX
    widgetY: (host ? host.y : 0) + offsetY
    screenWidth: host ? host.screenW : 1920
    screenHeight: host ? host.screenH : 1200
    roundness: 4.6
}
