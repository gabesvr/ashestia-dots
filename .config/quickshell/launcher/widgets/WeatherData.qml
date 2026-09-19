import QtQuick
import Quickshell.Io

QtObject {
    id: wd

    property string location: "Porto"
    property double configLatitude: 41.1496
    property double configLongitude: -8.6110
    property int temperatureUnit: 0 // 0 = Celsius, 1 = Fahrenheit

    property bool isLoading: true
    property string errorMessage: ""
    property string cityName: "Porto"

    property string currentTemp: "--"
    property string highTemp: "--"
    property string lowTemp: "--"
    property int weatherCode: 0
    property string condition: "Loading..."
    property string windSpeed: "--"
    property string windDirection: ""
    property string windUnit: "km/h"

    property var todaySunrise: null
    property var todaySunset: null
    property bool isNight: false

    property var hourlySlots: []
    property var dailyForecast: []
    property real overallLow: 0
    property real overallHigh: 100

    property double _latitude: 0
    property double _longitude: 0

    // Auto refresh every 30 minutes
    property var _refreshTimer: Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: wd._fetchWeather()
    }

    property int _failCount: 0
    readonly property var _backoffSchedule: [5000, 10000, 20000, 40000, 80000]

    property var _retryTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: {
            if (wd._latitude === 0 && wd._longitude === 0)
                wd._geocodeAndFetch()
            else
                wd._fetchWeather()
        }
    }

    function _scheduleRetry() {
        _failCount = Math.min(_failCount + 1, _backoffSchedule.length - 1)
        _retryTimer.interval = _backoffSchedule[_failCount]
        _retryTimer.restart()
    }

    function _clearRetry() {
        _failCount = 0
        _retryTimer.stop()
    }

    function forceRefresh() {
        _retryTimer.stop()
        _failCount = 0
        if (_latitude === 0 && _longitude === 0)
            _geocodeAndFetch()
        else
            _fetchWeather()
    }

    readonly property var presetCoords: ({
        "Porto": { lat: 41.1496, lon: -8.6110, name: "Porto" },
        "Lausanne": { lat: 46.5160, lon: 6.6328, name: "Lausanne" }
    })

    function setLocation(loc) {
        if (!loc || loc === location) return
        location = loc
        _applyLocation()
    }

    onLocationChanged: {
        _applyLocation()
    }

    function _applyLocation() {
        if (presetCoords[location]) {
            _latitude = presetCoords[location].lat
            _longitude = presetCoords[location].lon
            cityName = presetCoords[location].name
            _fetchWeather()
        } else {
            cityName = location
            _latitude = 0
            _longitude = 0
            _geocodeAndFetch()
        }
    }

    Component.onCompleted: {
        _applyLocation()
    }

    function iconNameForCode(code, night) {
        if (code === 0) return night ? "clearnight" : "sunny"
        if (code === 1 || code === 2) return night ? "partlycloudynight" : "partlysunny"
        if (code === 3) return "cloudy"
        if (code === 45 || code === 48) return "fog"
        if (code === 51 || code === 53 || code === 55) return night ? "nightdrizzle" : "drizzle"
        if (code === 56 || code === 57) return "sleet"
        if (code === 61 || code === 63) return "rain"
        if (code === 65) return "heavyrain"
        if (code === 66 || code === 67) return "sleet"
        if (code === 71 || code === 73 || code === 75) return "snow"
        if (code === 77) return "scatteredsnow"
        if (code === 80 || code === 81) return "rain"
        if (code === 82) return "heavyrain"
        if (code === 85 || code === 86) return "scatteredsnow"
        if (code === 95 || code === 96 || code === 99) return "thunderbolt"
        return night ? "clearnight" : "sunny"
    }

    function conditionForCode(code) {
        if (code === 0) return "Clear"
        if (code === 1) return "Mainly Clear"
        if (code === 2) return "Partly Cloudy"
        if (code === 3) return "Overcast"
        if (code === 45) return "Fog"
        if (code === 48) return "Rime Fog"
        if (code === 51) return "Light Drizzle"
        if (code === 53) return "Drizzle"
        if (code === 55) return "Dense Drizzle"
        if (code === 56) return "Freezing Drizzle"
        if (code === 57) return "Heavy Freezing Drizzle"
        if (code === 61) return "Slight Rain"
        if (code === 63) return "Rain"
        if (code === 65) return "Heavy Rain"
        if (code === 66) return "Freezing Rain"
        if (code === 67) return "Heavy Freezing Rain"
        if (code === 71) return "Slight Snow"
        if (code === 73) return "Snow"
        if (code === 75) return "Heavy Snow"
        if (code === 77) return "Snow Grains"
        if (code === 80) return "Light Showers"
        if (code === 81) return "Showers"
        if (code === 82) return "Heavy Showers"
        if (code === 85) return "Light Snow Showers"
        if (code === 86) return "Heavy Snow Showers"
        if (code === 95) return "Thunderstorm"
        if (code === 96) return "Thunderstorm with Hail"
        if (code === 99) return "Heavy Thunderstorm"
        return "Clear"
    }

    function _formatHour(date) {
        var h = date.getHours()
        return (h < 10 ? "0" : "") + h + ":00"
    }

    function _isNightTime(now, sunrise, sunset) {
        if (sunrise && sunset) return now < sunrise || now >= sunset
        var h = now.getHours()
        return h < 7 || h >= 19
    }

    function _geocodeAndFetch() {
        isLoading = true
        errorMessage = ""

        var xhr = new XMLHttpRequest()
        var url = "https://geocoding-api.open-meteo.com/v1/search?name=" +
                  encodeURIComponent(location) + "&count=1&language=en&format=json"

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    if (resp.results && resp.results.length > 0) {
                        _latitude = resp.results[0].latitude
                        _longitude = resp.results[0].longitude
                        cityName = resp.results[0].name || location
                        _fetchWeather()
                    } else {
                        errorMessage = "Location not found"
                        isLoading = false
                        condition = "Location not found"
                        _clearRetry()
                    }
                } catch (e) {
                    errorMessage = "Error parsing location"
                    isLoading = false
                    _scheduleRetry()
                }
            } else {
                errorMessage = "Network error"
                isLoading = false
                _scheduleRetry()
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _fetchWeather() {
        if (_latitude === 0 && _longitude === 0) {
            _geocodeAndFetch()
            return
        }

        var apiUnit = temperatureUnit === 0 ? "celsius" : "fahrenheit"
        var xhr = new XMLHttpRequest()
        var url = "https://api.open-meteo.com/v1/forecast?" +
                  "latitude=" + _latitude +
                  "&longitude=" + _longitude +
                  "&current=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m" +
                  "&hourly=temperature_2m,weather_code" +
                  "&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset" +
                  "&temperature_unit=" + apiUnit +
                  "&wind_speed_unit=kmh" +
                  "&timezone=auto" +
                  "&forecast_days=7"

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    _processResponse(resp)
                    isLoading = false
                    errorMessage = ""
                    _clearRetry()
                } catch (e) {
                    errorMessage = "Error parsing weather"
                    isLoading = false
                    _scheduleRetry()
                }
            } else {
                errorMessage = "Failed to fetch weather"
                isLoading = false
                _scheduleRetry()
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _processResponse(resp) {
        var now = new Date()

        if (resp.daily && resp.daily.sunrise && resp.daily.sunset) {
            todaySunrise = new Date(resp.daily.sunrise[0])
            todaySunset = new Date(resp.daily.sunset[0])
        }

        isNight = _isNightTime(now, todaySunrise, todaySunset)

        if (resp.current) {
            currentTemp = Math.round(resp.current.temperature_2m).toString()
            weatherCode = resp.current.weather_code || 0
            condition = conditionForCode(weatherCode)
            windSpeed = Math.round(resp.current.wind_speed_10m).toString()
        }

        if (resp.daily) {
            highTemp = Math.round(resp.daily.temperature_2m_max[0]).toString()
            lowTemp = Math.round(resp.daily.temperature_2m_min[0]).toString()
            _processDailyForecast(resp.daily)
        }

        if (resp.hourly) {
            _processHourlyForecast(resp.hourly, resp.daily)
        }
    }

    function _processDailyForecast(daily) {
        var days = []
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var minL = Infinity
        var maxH = -Infinity

        for (var i = 1; i <= 5; i++) {
            if (i >= daily.temperature_2m_max.length) break
            var d = new Date()
            d.setDate(d.getDate() + i)
            var hi = Math.round(daily.temperature_2m_max[i])
            var lo = Math.round(daily.temperature_2m_min[i])
            if (lo < minL) minL = lo
            if (hi > maxH) maxH = hi

            days.push({
                day: dayNames[d.getDay()],
                weatherCode: daily.weather_code[i],
                high: hi.toString(),
                low: lo.toString()
            })
        }

        var todayHi = Math.round(daily.temperature_2m_max[0])
        var todayLo = Math.round(daily.temperature_2m_min[0])
        if (todayLo < minL) minL = todayLo
        if (todayHi > maxH) maxH = todayHi

        overallLow = minL
        overallHigh = maxH
        dailyForecast = days
    }

    function _processHourlyForecast(hourly, daily) {
        var now = new Date()
        var sunrise = daily && daily.sunrise ? new Date(daily.sunrise[0]) : null
        var sunset = daily && daily.sunset ? new Date(daily.sunset[0]) : null

        var rawSlots = []
        for (var i = 0; i < hourly.time.length && rawSlots.length < 8; i++) {
            var t = new Date(hourly.time[i])
            if (t.getTime() <= now.getTime()) continue

            var slotNight = _isNightTime(t, sunrise, sunset)
            rawSlots.push({
                time: t,
                displayTime: _formatHour(t),
                temp: Math.round(hourly.temperature_2m[i]).toString(),
                iconName: iconNameForCode(hourly.weather_code[i], slotNight),
                isSunEvent: false,
                sunEventType: ""
            })
        }

        hourlySlots = rawSlots.slice(0, 6)
    }
}
