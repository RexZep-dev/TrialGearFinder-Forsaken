// Список изменений выпуска: кто сколько рейтинга получил с прошлого выпуска
// (пользователь 8 октября: «кто получил сколько рейтинга и где - класс,
// имя и всё такое»). Сравнивает два снимка db/Database.lua и печатает
// Markdown - его CurseForge показывает описанием версии.
//   node tools/changes.js <снимок прошлого выпуска> <новый снимок> [прошлая версия]
const fs = require("fs");
const TIERS = [20, 30, 35, 40, 45];

// Записи снимка: блоки «e = { ... }» с полями «имя = значение».
function load(file) {
    const map = new Map();
    if (!file || !fs.existsSync(file)) return map;
    const text = fs.readFileSync(file, "utf8").replace(/^﻿/, "");
    for (const block of text.split(/\n\s*e = \{/).slice(1)) {
        const e = {};
        for (const m of block.matchAll(/^ {4}(\w+) = ("(?:[^"\\]|\\.)*"|-?[\d.]+)/gm))
            e[m[1]] = m[2][0] === '"' ? JSON.parse(m[2]) : +m[2];
        if (e.name) map.set(e.name + "-" + e.realmSlug, e);
    }
    return map;
}

const [oldFile, newFile, lastVersion] = process.argv.slice(2);
const before = load(oldFile), after = load(newFile);
const who = e => `**${e.name}** (${e.realmName}) - ${e.class}, ${e.spec}`;
const best = e => e.bestDungeon ? `лучший ключ +${e.bestDungeonTier} ${e.bestDungeon} (${e.bestDungeonScore})` : "";
const sign = n => (n > 0 ? "+" : "") + n;

const rows = [];
for (const [k, e] of after) {
    const o = before.get(k);
    if (!o) { rows.push({ gain: e.score, line: `- ${who(e)}: новый в таблице, **${e.score}**, место ${e.rank}${best(e) ? "; " + best(e) : ""}` }); continue; }
    const gain = e.score - o.score;
    if (!gain) continue;
    // Где получил: по уровням ключей и новый лучший ключ.
    const where = TIERS.map(t => [t, (e["score" + t] || 0) - (o["score" + t] || 0)]).filter(([, d]) => d)
        .map(([t, d]) => `+${t}: ${sign(d)}`).join(", ");
    const newBest = e.bestDungeon && (e.bestDungeon !== o.bestDungeon || e.bestDungeonTier !== o.bestDungeonTier || e.bestDungeonScore !== o.bestDungeonScore) ? "новый " + best(e) : "";
    const place = e.rank !== o.rank ? `, место ${o.rank} → ${e.rank}` : `, место ${e.rank}`;
    rows.push({ gain, line: `- ${who(e)}: ${o.score} → **${e.score}** (${sign(gain)})${place}` + [where, newBest].filter(Boolean).map(s => "; " + s).join("") });
}
rows.sort((a, b) => b.gain - a.gain);

let out = `## Рейтинг Forsaken Dungeons+${lastVersion ? ` - изменения с выпуска ${lastVersion}` : ""}\n\n`;
out += rows.length ? rows.map(r => r.line).join("\n") + "\n" : "Рейтинг не изменился - обновлён сам модуль.\n";
const gone = [...before.keys()].filter(k => !after.has(k)).map(k => before.get(k));
if (gone.length) out += `\nВыбыли из таблицы: ${gone.map(e => `${e.name} (${e.realmName})`).join(", ")}\n`;
process.stdout.write(out);
