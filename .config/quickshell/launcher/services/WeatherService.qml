pragma Singleton
import QtQuick
import Quickshell
import "../widgets"

// Clima compartilhado: uma instância de WeatherData para todas as variantes.
Singleton {
    id: svc
    property var cityList: ["Porto", "Lausanne"]
    property int cityIndex: 0
    property WeatherData data: WeatherData { location: svc.cityList[svc.cityIndex] }
    function cycleCity() {
        cityIndex = (cityIndex + 1) % cityList.length;
        data.setLocation(cityList[cityIndex]);
    }
}
