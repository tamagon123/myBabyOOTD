import Foundation

struct WeatherResult {
    var tempMax: Double
    var tempMin: Double
    var weatherType: String
}

// 都道府県コード → 代表座標マッピング（JIS X 0401 順）
private let prefectureCoordinates: [String: (lat: Double, lon: Double)] = [
    "01": (43.064, 141.347), "02": (40.824, 140.740), "03": (39.703, 141.153),
    "04": (38.269, 140.872), "05": (39.718, 140.103), "06": (38.240, 140.363),
    "07": (37.750, 140.468), "08": (36.341, 140.447), "09": (36.566, 139.883),
    "10": (36.391, 139.060), "11": (35.857, 139.649), "12": (35.605, 140.123),
    "13": (35.689, 139.692), "14": (35.447, 139.642), "15": (37.902, 139.023),
    "16": (36.695, 137.211), "17": (36.594, 136.626), "18": (36.065, 136.222),
    "19": (35.664, 138.568), "20": (36.651, 138.181), "21": (35.391, 136.722),
    "22": (34.977, 138.383), "23": (35.180, 136.907), "24": (34.730, 136.509),
    "25": (35.004, 135.869), "26": (35.021, 135.756), "27": (34.686, 135.520),
    "28": (34.691, 135.183), "29": (34.685, 135.833), "30": (34.226, 135.168),
    "31": (35.504, 134.238), "32": (35.472, 133.051), "33": (34.661, 133.935),
    "34": (34.396, 132.459), "35": (34.186, 131.470), "36": (34.066, 134.559),
    "37": (34.340, 134.043), "38": (33.842, 132.766), "39": (33.560, 133.531),
    "40": (33.606, 130.418), "41": (33.249, 130.299), "42": (32.745, 129.874),
    "43": (32.790, 130.742), "44": (33.238, 131.613), "45": (31.911, 131.424),
    "46": (31.560, 130.558), "47": (26.212, 127.681)
]

actor WeatherService {
    static let shared = WeatherService()

    func fetch(regionCode: String) async -> WeatherResult? {
        guard let coord = prefectureCoordinates[regionCode] else { return nil }
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.lat)&longitude=\(coord.lon)&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=Asia%2FTokyo&forecast_days=1"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            guard let tempMax = json.daily.temperature_2m_max.first,
                  let tempMin = json.daily.temperature_2m_min.first,
                  let code = json.daily.weathercode.first else { return nil }
            let weatherType = mapWeatherCode(code)
            return WeatherResult(tempMax: tempMax, tempMin: tempMin, weatherType: weatherType)
        } catch {
            return nil
        }
    }

    private func mapWeatherCode(_ code: Int) -> String {
        switch code {
        case 0, 1:       return "sunny"
        case 2, 3:       return "cloudy"
        case 51...67, 80...82: return "rainy"
        case 71...77, 85, 86:  return "snowy"
        default:         return "cloudy"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    let daily: DailyData
    struct DailyData: Decodable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weathercode: [Int]
    }
}
