import Foundation
import Combine

struct WeatherSnapshot: Equatable {
    var temperature: Int
    var feelsLike: Int
    var description: String
    var symbol: String
    var location: String
    var isDay: Bool
    /// WMO weather code, kept so the description can be re-localized live.
    var code: Int
}

/// Fetches current conditions with no API key and no location permission:
/// IP-based geolocation (ipapi.co) + Open-Meteo. Refreshes every 15 minutes.
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published private(set) var weather: WeatherSnapshot?
    @Published private(set) var isLoading = false

    @Published var useFahrenheit: Bool {
        didSet {
            UserDefaults.standard.set(useFahrenheit, forKey: "wicit.weather.fahrenheit")
            refresh()
        }
    }

    private var timer: Timer?

    private init() {
        useFahrenheit = UserDefaults.standard.bool(forKey: "wicit.weather.fahrenheit")
        refresh()
        let timer = Timer(timeInterval: 900, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        fetchLocation { [weak self] location in
            guard let self, let location else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            self.fetchWeather(location)
        }
    }

    // MARK: - Networking

    private struct IPLocation: Decodable {
        let latitude: Double
        let longitude: Double
        let city: String?
    }

    private func fetchLocation(_ completion: @escaping (IPLocation?) -> Void) {
        guard let url = URL(string: "https://ipapi.co/json/") else { return completion(nil) }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let loc = try? JSONDecoder().decode(IPLocation.self, from: data) else {
                return completion(nil)
            }
            completion(loc)
        }.resume()
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }

    private func fetchWeather(_ location: IPLocation) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(location.latitude)),
            .init(name: "longitude", value: String(location.longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            .init(name: "temperature_unit", value: useFahrenheit ? "fahrenheit" : "celsius")
        ]
        guard let url = components.url else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data,
                  let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return }
            let current = response.current
            let (description, symbol) = Self.describe(code: current.weather_code, isDay: current.is_day == 1)
            let snapshot = WeatherSnapshot(
                temperature: Int(current.temperature_2m.rounded()),
                feelsLike: Int(current.apparent_temperature.rounded()),
                description: description,
                symbol: symbol,
                location: location.city ?? "",
                isDay: current.is_day == 1,
                code: current.weather_code
            )
            DispatchQueue.main.async { self?.weather = snapshot }
        }.resume()
    }

    // MARK: - WMO weather code mapping

    static func describe(code: Int, isDay: Bool) -> (String, String) {
        switch code {
        case 0: return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2: return ("Partly Cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51, 53, 55: return ("Drizzle", "cloud.drizzle.fill")
        case 56, 57: return ("Freezing Drizzle", "cloud.sleet.fill")
        case 61, 63, 65: return ("Rain", "cloud.rain.fill")
        case 66, 67: return ("Freezing Rain", "cloud.sleet.fill")
        case 71, 73, 75, 77: return ("Snow", "cloud.snow.fill")
        case 80, 81, 82: return ("Rain Showers", "cloud.heavyrain.fill")
        case 85, 86: return ("Snow Showers", "cloud.snow.fill")
        case 95: return ("Thunderstorm", "cloud.bolt.fill")
        case 96, 99: return ("Thunderstorm", "cloud.bolt.rain.fill")
        default: return ("—", "cloud.fill")
        }
    }

    static func turkishDescription(code: Int) -> String {
        switch code {
        case 0: return "Açık"
        case 1, 2: return "Parçalı Bulutlu"
        case 3: return "Kapalı"
        case 45, 48: return "Sisli"
        case 51, 53, 55: return "Çisenti"
        case 56, 57: return "Dondurucu Çisenti"
        case 61, 63, 65: return "Yağmurlu"
        case 66, 67: return "Dondurucu Yağmur"
        case 71, 73, 75, 77: return "Karlı"
        case 80, 81, 82: return "Sağanak Yağış"
        case 85, 86: return "Kar Sağanağı"
        case 95, 96, 99: return "Fırtına"
        default: return "—"
        }
    }
}
