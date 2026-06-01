// =============================================================================
// ファイル名: WeatherService.swift
// 役割: 外部API（Open-Meteo）から天気予報を取得し、アプリ用の形式に変換する
// 説明:
//   このファイルは、無料の天気API「Open-Meteo」を利用して、日本の都道府県ごとの
//   当日の最高気温・最低気温・天気を取得する機能を提供します。
//   各都道府県の代表座標（緯度・経度）をJIS X 0401コードでマッピングしており、
//   ユーザーが設定した地域に対応する天気を自動で取得できます。
//   actorキーワードにより、同時実行時のデータ競合を防いでいます。
// =============================================================================

import Foundation

// WeatherResult: 天気取得結果をまとめる構造体。
// WeatherService.fetch()の戻り値として使用される。
struct WeatherResult {
    var tempMax: Double      // 当日の最高気温（摂氏）
    var tempMin: Double      // 当日の最低気温（摂氏）
    var weatherType: String  // 天気種別文字列（"sunny"/"cloudy"/"rainy"/"snowy"）
}

// actor: Swiftの並行処理安全な型。同時に複数の場所から呼ばれても
// データ競合（同じ変数への同時書き込み）が起きない。
actor WeatherService {
    // シングルトンインスタンス
    static let shared = WeatherService()

    // 都道府県コード → 代表座標マッピング（JIS X 0401 順）
    // キーは2桁の都道府県コード（01=北海道〜47=沖縄）、値は緯度・経度のタプル。
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

    // =============================================================================
    // 【関数サマリー】fetch
    // 目的: 指定された都道府県コードに対応する当日の天気をOpen-Meteo APIから取得する
    // 引数:
    //   - regionCode: String - JIS X 0401の2桁都道府県コード（例: "13"）
    // 戻り値: WeatherResult? - 取得成功時は天気情報、失敗時はnil
    // 処理の流れ:
    //   1. prefectureCoordinatesから緯度・経度を取得
    //   2. Open-Meteo APIのURLを組み立て（最高気温・最低気温・weathercodeを要求）
    //   3. URLSessionでHTTP GETリクエストを送信
    //   4. JSONレスポンスをOpenMeteoResponse構造体にデコード
    //   5. 配列の最初の要素（当日分）を取り出し、mapWeatherCodeで天気文字列に変換
    //   6. WeatherResultを生成して返却
    // 呼び出し元: NewPostView.fetchWeather()（投稿時の天気自動取得ボタン）
    // 備考: API通信に失敗したり、対象地域がマッピングにない場合はnilを返す。
    // =============================================================================
    func fetch(regionCode: String) async -> WeatherResult? {
        guard let coord = prefectureCoordinates[regionCode] else {
            print("[WeatherService] regionCode not found: \(regionCode)")
            return nil
        }
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.lat)&longitude=\(coord.lon)&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FTokyo&forecast_days=1"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let raw = String(data: data, encoding: .utf8) {
                print("[WeatherService] response: \(raw.prefix(300))")
            }
            let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            guard let tempMax = json.daily.temperature_2m_max.first,
                  let tempMin = json.daily.temperature_2m_min.first,
                  let code = json.daily.weather_code.first else {
                print("[WeatherService] missing fields in response")
                return nil
            }
            let weatherType = mapWeatherCode(code)
            return WeatherResult(tempMax: tempMax, tempMin: tempMin, weatherType: weatherType)
        } catch {
            print("[WeatherService] error: \(error)")
            return nil
        }
    }

    // =============================================================================
    // 【関数サマリー】mapWeatherCode
    // 目的: Open-Meteo APIが返すweathercode（数値）をアプリ内の天気文字列に変換する
    // 引数:
    //   - code: Int - Open-MeteoのWMO Weather interpretation codes
    // 戻り値: String - "sunny" / "cloudy" / "rainy" / "snowy"
    // マッピングルール:
    //   0, 1     → "sunny"   （晴れ・快晴）
    //   2, 3     → "cloudy"  （曇り・大部分曇り）
    //   51〜67, 80〜82 → "rainy" （霧雨・雨・にわか雨）
    //   71〜77, 85, 86 → "snowy" （雪・吹雪）
    //   その他   → "cloudy"  （デフォルト）
    // 呼び出し元: WeatherService.fetch() 内部で使用
    // 備考: WMOコードの詳細は https://open-meteo.com/en/docs を参照。
    // =============================================================================
    private func mapWeatherCode(_ code: Int) -> String {
        switch code {
        case 0, 1:       return "sunny"
        case 2, 3:       return "cloudy"
        case 51...67, 80...82: return "rainy"
        case 71...77, 85, 86:  return "snowy"
        default:         return "cloudy"
        }
    }

    // =============================================================================
    // 【関数サマリー】fetchHistorical
    // 目的: 指定した日付（過去）の天気・気温データをOpen-Meteo Historical APIから取得する
    // 引数:
    //   - regionCode: String - JIS X 0401の2桁都道府県コード
    //   - date: Date - 取得対象の日付（当日または過去日付）
    // 戻り値: WeatherResult? - 取得成功時は天気情報、失敗時はnil
    // 備考: 当日の場合はforecast API、過去日付はhistorical APIを使用
    // =============================================================================
    func fetchHistorical(regionCode: String, date: Date) async -> WeatherResult? {
        guard let coord = prefectureCoordinates[regionCode] else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let dateStr = fmt.string(from: date)
        let today = fmt.string(from: Date())
        let urlString: String
        if dateStr == today {
            urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.lat)&longitude=\(coord.lon)&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FTokyo&forecast_days=1"
        } else {
            urlString = "https://archive-api.open-meteo.com/v1/archive?latitude=\(coord.lat)&longitude=\(coord.lon)&start_date=\(dateStr)&end_date=\(dateStr)&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FTokyo"
        }
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            guard let tempMax = json.daily.temperature_2m_max.first,
                  let tempMin = json.daily.temperature_2m_min.first,
                  let code = json.daily.weather_code.first else { return nil }
            return WeatherResult(tempMax: tempMax, tempMin: tempMin, weatherType: mapWeatherCode(code))
        } catch {
            print("[WeatherService] fetchHistorical error: \(error)")
            return nil
        }
    }

    // カレンダー表示用：過去実績と未来予報を組み合わせて取得
    // - 過去（昨日まで）: archive API
    // - 未来（今日以降）: forecast API（最大16日先まで）
    func fetchMonthly(regionCode: String, startDate: Date, endDate: Date) async -> [String: WeatherResult] {
        guard let coord = prefectureCoordinates[regionCode] else {
            print("[WeatherService] regionCode not found: \(regionCode)")
            return [:]
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let calendar = Calendar.current
        
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        
        print("[WeatherService] fetchMonthly debug: today=\(fmt.string(from: today)), startDay=\(fmt.string(from: startDay)), endDay=\(fmt.string(from: endDay))")
        
        // 過去データの範囲（昨日まで）
        let archiveStart = startDay
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let archiveEnd = min(endDay, yesterday)
        
        // 未来予報の範囲（今日から最大15日先 - API制限で16日先は取得不可）
        let forecastStart = max(startDay, today)
        let maxForecastDate = calendar.date(byAdding: .day, value: 15, to: today) ?? today
        let forecastEnd = min(endDay, maxForecastDate)
        
        print("[WeatherService] fetchMonthly ranges: archive=\(fmt.string(from: archiveStart))~\(fmt.string(from: archiveEnd)), forecast=\(fmt.string(from: forecastStart))~\(fmt.string(from: forecastEnd))")
        
        var results: [String: WeatherResult] = [:]
        
        // 1. 過去データを取得（archive API）
        if archiveStart <= archiveEnd {
            let startStr = fmt.string(from: archiveStart)
            let endStr = fmt.string(from: archiveEnd)
            let urlString = "https://archive-api.open-meteo.com/v1/archive?latitude=\(coord.lat)&longitude=\(coord.lon)&start_date=\(startStr)&end_date=\(endStr)&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FTokyo"
            print("[WeatherService] fetchMonthly archive: \(startStr) to \(endStr)")
            
            if let url = URL(string: urlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                    var currentDate = archiveStart
                    for i in 0..<json.daily.temperature_2m_max.count {
                        let dateKey = fmt.string(from: currentDate)
                        results[dateKey] = WeatherResult(
                            tempMax: json.daily.temperature_2m_max[i],
                            tempMin: json.daily.temperature_2m_min[i],
                            weatherType: mapWeatherCode(json.daily.weather_code[i])
                        )
                        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    }
                    print("[WeatherService] fetchMonthly archive: got \(json.daily.temperature_2m_max.count) days")
                } catch {
                    print("[WeatherService] fetchMonthly archive error: \(error)")
                }
            }
        }
        
        // 2. 未来予報を取得（forecast API、最大16日）
        if forecastStart <= forecastEnd {
            let startStr = fmt.string(from: forecastStart)
            let endStr = fmt.string(from: forecastEnd)
            // forecast API: start_dateとend_dateの両方が必要
            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.lat)&longitude=\(coord.lon)&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FTokyo&start_date=\(startStr)&end_date=\(endStr)"
            print("[WeatherService] fetchMonthly forecast: \(startStr) to \(endStr)")
            
            if let url = URL(string: urlString) {
                do {
                    print("[WeatherService] forecast API URL: \(urlString)")
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let raw = String(data: data, encoding: .utf8) {
                        print("[WeatherService] forecast API raw response (first 500): \(raw.prefix(500))")
                    }
                    let json = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                    print("[WeatherService] forecast API decoded: max=\(json.daily.temperature_2m_max), min=\(json.daily.temperature_2m_min), codes=\(json.daily.weather_code)")
                    var currentDate = forecastStart
                    for i in 0..<json.daily.temperature_2m_max.count {
                        let dateKey = fmt.string(from: currentDate)
                        results[dateKey] = WeatherResult(
                            tempMax: json.daily.temperature_2m_max[i],
                            tempMin: json.daily.temperature_2m_min[i],
                            weatherType: mapWeatherCode(json.daily.weather_code[i])
                        )
                        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    }
                    print("[WeatherService] fetchMonthly forecast: got \(json.daily.temperature_2m_max.count) days, results keys: \(results.keys.sorted())")
                } catch {
                    print("[WeatherService] fetchMonthly forecast error: \(error)")
                }
            }
        }
        
        print("[WeatherService] fetchMonthly total: \(results.count) days")
        return results
    }

    // OpenMeteoResponse: Open-Meteo APIから返されるJSONの構造をSwiftの型にマッピングしたもの。
    private struct OpenMeteoResponse: Decodable {
        let daily: DailyData
        struct DailyData: Decodable {
            let temperature_2m_max: [Double]  // 日次の最高気温配列
            let temperature_2m_min: [Double]  // 日次の最低気温配列
            let weather_code: [Int]           // 日次の天気コード配列
        }
    }
}
