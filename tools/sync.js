// Снимок рейтинга Forsaken Dungeons+ для модуля TrialGearFinder_Forsaken
// (бывший аддон ForsakenIO, слит 3 октября). Только публичные GET сайта:
//   /api/season/current             - сезон и его состояние
//   /api/leaderboard-detailed?mode=season - таблица: рейтинг, тиры, спеки
//   /api/character/{id}              - только character.raids (закрыт ли рейд)
// Экипировку не сохраняем. Формат базы - как у ForsakenIO (sync-db.ps1),
// плюс classFile и specID: по ним игра покажет имя класса и спека на языке
// клиента, а не русским с сайта.
//   node tools/sync.js            (у себя: ядро берётся из папки AddOns)
//   TGF_CORE=<папка ядра> node tools/sync.js   (GitHub: ядро выкачано рядом)
// Названия подземелий - из переводов ядра (Locales/enUS.lua, zhCN.lua):
// в снимок кладутся на трёх языках, модуль от ядра не зависит.
const fs = require("fs");
const path = require("path");
const BASE = "https://forsaken-dungeons.online";
const OUT = path.join(__dirname, "..", "db", "Database.lua");
const CORE = process.env.TGF_CORE || "G:/World of Warcraft/_retail_/Interface/AddOns/TrialGearFinder";
const CLASS = { "Воин": "WARRIOR", "Паладин": "PALADIN", "Охотник": "HUNTER", "Разбойник": "ROGUE", "Жрец": "PRIEST",
    "Рыцарь смерти": "DEATHKNIGHT", "Шаман": "SHAMAN", "Маг": "MAGE", "Чернокнижник": "WARLOCK", "Монах": "MONK",
    "Друид": "DRUID", "Охотник на демонов": "DEMONHUNTER", "Эвокер": "EVOKER", "Пробудитель": "EVOKER" };
// Сайт пишет «Лед» без ё.
const SPEC = {
    WARRIOR: { "Оружие": 71, "Неистовство": 72, "Защита": 73 },
    PALADIN: { "Свет": 65, "Защита": 66, "Воздаяние": 70 },
    HUNTER: { "Повелитель зверей": 253, "Стрельба": 254, "Выживание": 255 },
    ROGUE: { "Ликвидация": 259, "Головорез": 260, "Скрытность": 261 },
    PRIEST: { "Послушание": 256, "Свет": 257, "Тьма": 258 },
    DEATHKNIGHT: { "Кровь": 250, "Лед": 251, "Лёд": 251, "Нечестивость": 252 },
    SHAMAN: { "Стихии": 262, "Совершенствование": 263, "Исцеление": 264 },
    MAGE: { "Тайная магия": 62, "Огонь": 63, "Лед": 64, "Лёд": 64 },
    WARLOCK: { "Колдовство": 265, "Демонология": 266, "Разрушение": 267 },
    MONK: { "Хмелевар": 268, "Ткач туманов": 270, "Танцующий с ветром": 269 },
    DRUID: { "Баланс": 102, "Сила зверя": 103, "Страж": 104, "Исцеление": 105 },
    DEMONHUNTER: { "Истребление": 577, "Месть": 581, "Пожиратель": 1480 },
    EVOKER: { "Опустошение": 1467, "Сохранение": 1468, "Насыщение": 1473 },
};
// Цвет места и рейтинга - как на сайте (leaderboardRankColor в его коде,
// снято 3 октября): сила = рейтинг/рейтинг первого × 0,65 + место × 0,35,
// по шкале белый → зелёный → бирюзовый → синий → фиолетовый → красный →
// оранжевый. Считаем здесь и кладём в снимок готовым цветом.
const STOPS = [[0, "f4f4f5"], [0.18, "30d95a"], [0.36, "35c6c8"], [0.55, "1687ff"], [0.72, "b83cff"], [0.88, "ff4f63"], [1, "ff7a22"]];
const mix = (a, b, t) => [0, 2, 4].map(i => { const x = parseInt(a.substr(i, 2), 16), y = parseInt(b.substr(i, 2), 16);
    return Math.round(x + (y - x) * t).toString(16).padStart(2, "0"); }).join("");
const strengthColor = v => { const t = Math.min(1, Math.max(0, v));
    for (let i = 1; i < STOPS.length; i++) if (t <= STOPS[i][0]) return mix(STOPS[i - 1][1], STOPS[i][1], (t - STOPS[i - 1][0]) / (STOPS[i][0] - STOPS[i - 1][0]));
    return STOPS[STOPS.length - 1][1]; };
const rankColor = (index, rows) => {
    const cur = Math.max(0, +rows[index].score || 0);
    const top = Math.max(cur, ...rows.map(r => +r.score || 0), 0);
    const rankRatio = rows.length > 1 ? 1 - index / (rows.length - 1) : 1;
    return strengthColor((top > 0 ? cur / top : 0) * 0.65 + rankRatio * 0.35);
};
// Название подземелья сайта (английское) -> русский ключ наших переводов
// (D["русское"] = "английское" в Locales/enUS.lua): аддон покажет его на
// языке клиента через ns.D.
const EN2RU = new Map();
for (const m of fs.readFileSync(path.join(CORE, "Locales", "enUS.lua"), "utf8").matchAll(/^D\["([^"]+)"\] = "([^"]+)"/gm))
    if (!EN2RU.has(m[2].toLowerCase())) EN2RU.set(m[2].toLowerCase(), m[1]);
const RU2ZH = new Map();
for (const m of fs.readFileSync(path.join(CORE, "Locales", "zhCN.lua"), "utf8").matchAll(/^D\["([^"]+)"\] = "([^"]+)"/gm))
    if (!RU2ZH.has(m[1])) RU2ZH.set(m[1], m[2]);
const key = s => (s || "").toLowerCase().replace(/[\s'\-]+/g, "");
const q = s => JSON.stringify(s == null ? "" : String(s));
const get = async p => { const r = await fetch(BASE + p); if (!r.ok) throw new Error(p + " " + r.status); return r.json(); };
(async () => {
    const cur = await get("/api/season/current");
    const lb = await get("/api/leaderboard-detailed?mode=season");
    const season = lb.season || cur.season || (cur.status && cur.status.rankingSeason) || {};
    const rows = lb.leaderboard || [];
    const unknown = new Set();
    let out = `-- Снимок рейтинга Forsaken Dungeons+: node tools/sync.js
-- Руками не править.
ForsakenIODB = {
  generatedAt = ${q(new Date().toISOString().replace(/\.\d+Z$/, "Z"))},
  season = {
    id = ${q(season.id)},
    name = ${q(season.name)},
    startsOn = ${q(season.startsOn)},
    endsOn = ${q(season.endsOn)},
    phase = ${q(cur.status && cur.status.phase)},
  },
  count = 0,
  raidTotal = 5,
  byKey = {},
}

do
  local byKey = ForsakenIODB.byKey
  local e
`;
    let i = 0;
    for (const r of rows) {
        i++;
        let raids = null, total = 5, best = null;
        try {
            const c = await get(`/api/character/${r.character_id}`);
            // Лучшее прохождение - больше всего очков, при равенстве выше ключ.
            for (const b of c.bestRuns || []) if (!best || b.score > best.score || (b.score === best.score && b.tier > best.tier)) best = b;
            const list = (c.character && c.character.raids) || [];
            if (list.length) {
                total = list.length;
                raids = list.filter(x => (x.difficulties || []).some(d => d.total > 0 && d.completed >= d.total)).length;
            }
        } catch (e) { console.log("рейды не получены:", r.character_name, e.message); }
        if (best && !EN2RU.has(String(best.dungeon).toLowerCase())) unknown.add("подземелье без перевода: " + best.dungeon);
        await new Promise(res => setTimeout(res, 150));
        const cf = CLASS[r.character_class];
        if (!cf) unknown.add("класс " + r.character_class);
        const specID = s => { const id = cf && SPEC[cf] && SPEC[cf][s]; if (s && !id) unknown.add(`${r.character_class}: ${s}`); return id; };
        out += `
  e = {
    name = ${q(r.character_name)},
    realmName = ${q(r.realm_name)},
    realmSlug = ${q(r.realm_slug)},
    class = ${q(r.character_class)},
    classFile = ${q(cf)},
    spec = ${q(r.active_spec)},
    specID = ${specID(r.active_spec) || "nil"},
    score = ${+r.score || 0},
    rank = ${i},
    color = ${q(rankColor(i - 1, rows))},
    runs = ${+r.runs || 0},
    bestTier = ${r.best_tier ? +r.best_tier : "nil"},
    score20 = ${+r.score_20 || 0},
    score30 = ${+r.score_30 || 0},
    score35 = ${+r.score_35 || 0},
    score40 = ${+r.score_40 || 0},
    score45 = ${+r.score_45 || 0},
    runs20 = ${+r.runs_20 || 0},
    runs30 = ${+r.runs_30 || 0},
    runs35 = ${+r.runs_35 || 0},
    runs40 = ${+r.runs_40 || 0},
    runs45 = ${+r.runs_45 || 0},
    raidsCompleted = ${raids == null ? "nil" : raids},
    bestDungeon = ${best ? q(EN2RU.get(String(best.dungeon).toLowerCase()) || best.dungeon) : "nil"},
    bestDungeonEn = ${best ? q(best.dungeon) : "nil"},
    bestDungeonZh = ${best && RU2ZH.get(EN2RU.get(String(best.dungeon).toLowerCase())) ? q(RU2ZH.get(EN2RU.get(String(best.dungeon).toLowerCase()))) : "nil"},
    bestDungeonTier = ${best ? +best.tier : "nil"},
    bestDungeonScore = ${best ? +best.score : "nil"},
    raidsTotal = ${total},
    specs = {
${(r.specs || []).map(s => `      { role = ${q(s.role)}, spec = ${q(s.spec)}, specID = ${specID(s.spec) || "nil"}, score = ${+s.score || 0} },`).join("\n")}
    },
  }
`;
        const keys = new Set([key(r.character_name) + "-" + key(r.realm_slug), key(r.character_name) + "-" + key(r.realm_name)]);
        for (const k of keys) out += `  byKey[${q(k)}] = e\n`;
    }
    out += `\n  ForsakenIODB.count = ${rows.length}\nend\n`;
    fs.mkdirSync(path.dirname(OUT), { recursive: true });
    fs.writeFileSync(OUT, out.replace(/\n/g, "\r\n"));
    console.log(`${season.name} (${cur.status && cur.status.phase}), записей ${rows.length}`);
    if (unknown.size) console.log("без номера спека/класса:", [...unknown].join("; "));
})();
