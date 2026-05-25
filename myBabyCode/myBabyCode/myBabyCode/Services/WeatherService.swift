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

// 都道府県コード → 代表座標マッピング（JIS X 0401 順）
// キーは2桁の都道府県コード（01=北海道〜47=沖縄）、値は緯度・経度のタプル。
// このマッピングがない都道府県コードが渡されると、天気取得は失敗（nil）する。
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

// actor: Swiftの並行処理安全な型。同時に複数の場所から呼ばれても
// データ競合（同じ変数への同時書き込み）が起きない。
actor WeatherService {
    // シングルトンインスタンス
    static let shared = WeatherService()

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
}

// OpenMeteoResponse: Open-Meteo APIから返されるJSONの構造をSwiftの型にマッピングしたもの。
// privateなのでWeatherService.swift内でのみ使用される。
private struct OpenMeteoResponse: Decodable {
    let daily: DailyData
    struct DailyData: Decodable {
        let temperature_2m_max: [Double]  // 日次の最高気温配列（forecast_days=1なので1要素）
        let temperature_2m_min: [Double]  // 日次の最低気温配列
        let weathercode: [Int]           // 日次の天気コード配列
    }
}
