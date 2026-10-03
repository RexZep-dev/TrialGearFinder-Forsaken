-- Тексты модуля Forsaken Dungeons+. Свои, а не из ядра: модуль выходит
-- отдельным проектом, и у игрока может стоять ядро старее модуля (3 октября).
-- Язык - как у ядра (его выбор «английский» в Параметрах), без ядра - клиента.
local T = {
ruRU = {
  FIO_ROLE_DPS = "Боец",
  FIO_ROLE_HEALER = "Лекарь",
  FIO_ROLE_TANK = "Танк",
  FIO_RATING = "Рейтинг",
  FIO_RAIDS = "Рейды",
  FIO_STALE = "Данные устарели: %d дн. Обновите аддон.",
  FIO_BEST_DUNGEON = "Лучшее подземелье",
  FIO_FINAL = "итоги",
  FIO_NOT_IN_SNAPSHOT = "%s: нет в снимке рейтинга.",
  FIO_PROFILE = "%s - %s: |cffd8b86a%d|r, место %s, лучший %s (%s зачётов)%s",
  FIO_PROFILE_RAIDS = ", рейды %d/%d",
  FIO_YOU = "Вы",
  FIO_TARGET = "Цель",
  FIO_SUMMARY = "%s, записей %d, снимок %s.",
  FIO_UNKNOWN = "неизвестно",
  FIO_TOOLTIP_ON = "подсказка включена.",
  FIO_TOOLTIP_OFF = "подсказка выключена.",
  FIO_COMMANDS = "Команды: /fdio - сводка, /fdio tooltip - вкл/выкл подсказку.",
  FIO_STANDALONE = "|cFFFFD100[TGF]|r Стоит отдельный аддон ForsakenIO: модуль «Forsaken Dungeons+» его не дублирует. Оставьте включённым один из двух.",
},
enUS = {
  FIO_ROLE_DPS = "DPS",
  FIO_ROLE_HEALER = "Healer",
  FIO_ROLE_TANK = "Tank",
  FIO_RATING = "Rating",
  FIO_RAIDS = "Raids",
  FIO_STALE = "Data is %d days old. Update the addon.",
  FIO_BEST_DUNGEON = "Best dungeon",
  FIO_FINAL = "final",
  FIO_NOT_IN_SNAPSHOT = "%s: not in the rating snapshot.",
  FIO_PROFILE = "%s - %s: |cffd8b86a%d|r, rank %s, best %s (%s runs)%s",
  FIO_PROFILE_RAIDS = ", raids %d/%d",
  FIO_YOU = "You",
  FIO_TARGET = "Target",
  FIO_SUMMARY = "%s, %d entries, snapshot %s.",
  FIO_UNKNOWN = "unknown",
  FIO_TOOLTIP_ON = "tooltip enabled.",
  FIO_TOOLTIP_OFF = "tooltip disabled.",
  FIO_COMMANDS = "Commands: /fdio - summary, /fdio tooltip - toggle the tooltip.",
  FIO_STANDALONE = "|cFFFFD100[TGF]|r The standalone ForsakenIO addon is enabled: the Forsaken Dungeons+ module stays off to avoid duplicates. Keep only one of them enabled.",
},
zhCN = {
  FIO_ROLE_DPS = "输出",
  FIO_ROLE_HEALER = "治疗",
  FIO_ROLE_TANK = "坦克",
  FIO_RATING = "评分",
  FIO_RAIDS = "团队副本",
  FIO_STALE = "数据已过期 %d 天，请更新插件。",
  FIO_BEST_DUNGEON = "最佳地下城",
  FIO_FINAL = "最终结果",
  FIO_NOT_IN_SNAPSHOT = "%s：不在评分快照中。",
  FIO_PROFILE = "%s - %s：|cffd8b86a%d|r，排名 %s，最高 %s（%s 次）%s",
  FIO_PROFILE_RAIDS = "，团队副本 %d/%d",
  FIO_YOU = "你",
  FIO_TARGET = "目标",
  FIO_SUMMARY = "%s，%d 条记录，快照 %s。",
  FIO_UNKNOWN = "未知",
  FIO_TOOLTIP_ON = "鼠标提示已开启。",
  FIO_TOOLTIP_OFF = "鼠标提示已关闭。",
  FIO_COMMANDS = "命令：/fdio - 概要，/fdio tooltip - 开关鼠标提示。",
  FIO_STANDALONE = "|cFFFFD100[TGF]|r 已启用独立的 ForsakenIO 插件：Forsaken Dungeons+ 模块不会重复加载。请只保留其中一个。",
},
}
T.zhTW = T.zhCN

function TrialGearFinderForsakenLang()
  local ns = TrialGearFinderNS
  local lang = ns and ns.AddonLang and ns.AddonLang() or GetLocale()
  if lang == "zhTW" then lang = "zhCN" end
  return T[lang] and lang or "enUS"
end

-- L"KEY" / L("KEY"): язык модуля, нет перевода - английский, нет и его - ключ.
TrialGearFinderForsakenL = setmetatable({}, {
  __call = function(_, key)
    local t = T[TrialGearFinderForsakenLang()]
    return (t and t[key]) or T.enUS[key] or key
  end,
})
