import Foundation

enum AppLanguage {
    static let isRussian = true
    static let locale = Locale(identifier: "ru_RU")

    private static let sportRules: [([String], String)] = [
        (["run", "бег"], "Бег"),
        (["ride", "cycl", "вело"], "Велосипед"),
        (["walk", "ход"], "Ходьба"),
        (["hike", "поход"], "Поход"),
        (["swim", "плав"], "Плавание"),
        (["row", "греб"], "Гребля"),
        (["ski", "лыж"], "Лыжи"),
        (["strength", "силов"], "Силовая тренировка"),
        (["elliptical"], "Эллиптический тренажёр"),
        (["stair"], "Лестница"),
        (["soccer"], "Футбол"),
        (["skate"], "Коньки"),
        (["snowboard"], "Сноуборд"),
        (["surf"], "Сёрфинг"),
        (["paddl", "canoe", "kayak"], "Гребной спорт"),
        (["climb"], "Скалолазание"),
        (["golf"], "Гольф"),
        (["yoga", "йог"], "Йога"),
        (["pilates"], "Пилатес")
    ]

    static func sportName(_ sportType: String) -> String {
        let normalized = sportType.lowercased()
        return sportRules.first { rule in
            rule.0.contains { normalized.contains($0) }
        }?.1 ?? "Тренировка"
    }
}
