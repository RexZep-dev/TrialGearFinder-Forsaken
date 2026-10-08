-- Модуль «Forsaken Dungeons+»: рейтинг сайта forsaken-dungeons.online в
-- подсказке игрока и в списке гильдии. Бывший отдельный аддон ForsakenIO,
-- слит в Trial Gear Finder 3 октября 2026 по просьбе пользователя - как
-- модуль, который включается и выключается в списке аддонов, как «Журнал».
--
-- Глобальные имена ForsakenIO / ForsakenIODB / ForsakenIOSettings оставлены
-- прежними: на них опирается плашка «20» ядра (PlayerMarks.lua), и
-- настройки игроков, ставивших ForsakenIO отдельно, переезжают сами.
--
-- Данные - снимок db/Database.lua, его собирает
-- D:/cloude/TrialGearFinder/forsaken_sync.js (только публичные GET сайта).

-- Стоит и отдельный ForsakenIO: он грузится раньше (F < T) и уже повесил
-- подсказку и /fdio. Второй экземпляр задвоил бы строки - уступаем.
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ForsakenIO") then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function() print(TrialGearFinderForsakenL"FIO_STANDALONE") end)
  return
end

ForsakenIO = ForsakenIO or {}
local addon = ForsakenIO
local L = TrialGearFinderForsakenL

local function IsSecret(value)
  return issecretvalue and issecretvalue(value)
end

-- Настройки -----------------------------------------------------------------

function addon:IsTooltipEnabled()
  return not ForsakenIOSettings or ForsakenIOSettings.tooltipEnabled ~= false
end

function addon:SetTooltipEnabled(enabled)
  ForsakenIOSettings = ForsakenIOSettings or {}
  ForsakenIOSettings.tooltipEnabled = not not enabled
end

function addon:Print(message)
  print("|cffd8b86aForsaken Dungeons+|r: " .. tostring(message))
end

-- Цвета рейтинга - как на сайте ---------------------------------------------

local SCORE_COLORS = {
  { min = 2000, r = 1.00, g = 0.50, b = 0.00 },
  { min = 1000, r = 0.64, g = 0.21, b = 0.93 },
  { min = 500,  r = 0.00, g = 0.44, b = 0.87 },
  { min = 1,    r = 0.12, g = 1.00, b = 0.00 },
  { min = 0,    r = 0.62, g = 0.62, b = 0.62 },
}

function addon.ScoreColor(score)
  score = tonumber(score) or 0
  for i = 1, #SCORE_COLORS do
    local band = SCORE_COLORS[i]
    if score >= band.min then return band.r, band.g, band.b end
  end
  return 0.62, 0.62, 0.62
end

-- Цвет игрока как на сайте: место и рейтинг там красятся плавной шкалой по
-- силе игрока относительно первого места (пользователь 3 октября: «на сайте
-- цвет меняется, а у нас серый»). Считает forsaken_sync.js, в снимке - готовый
-- hex. Нет его (старый снимок) - пороги ScoreColor.
function addon.ProfileColor(profile)
  local hex = profile and profile.color
  if type(hex) == "string" and #hex == 6 then
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
  end
  return addon.ScoreColor(profile and profile.score)
end

local function ClassColor(profile)
  local c = profile.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[profile.classFile]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local ROLE_KEY = { dps = "FIO_ROLE_DPS", healer = "FIO_ROLE_HEALER", tank = "FIO_ROLE_TANK" }

-- Имя спека на языке клиента: сайт пишет по-русски, номер спека - из снимка.
local function SpecName(specID, fallback)
  if specID and GetSpecializationInfoByID then
    local _, name = GetSpecializationInfoByID(specID)
    if name and name ~= "" then return name end
  end
  return fallback
end

-- Поиск игрока в снимке ------------------------------------------------------

-- Нижний регистр для ASCII, кириллицы и Latin-1: string.lower их не трогает.
-- Совпадает с forsaken_sync.js (toLowerCase) на наших именах и мирах.
local function Utf8Lower(s)
  s = string.lower(s or "")
  local out, i, n = {}, 1, #s
  while i <= n do
    local c = s:byte(i)
    if c < 128 then
      out[#out + 1] = s:sub(i, i); i = i + 1
    elseif c == 0xC3 and i < n then
      local b = s:byte(i + 1)
      if (b >= 0x80 and b <= 0x96) or (b >= 0x98 and b <= 0x9E) then
        out[#out + 1] = string.char(0xC3, b + 0x20)
      else
        out[#out + 1] = s:sub(i, i + 1)
      end
      i = i + 2
    elseif c == 0xD0 and i < n then
      local b = s:byte(i + 1)
      if b >= 0x80 and b <= 0x8F then
        out[#out + 1] = string.char(0xD1, b + 0x10)
      elseif b >= 0x90 and b <= 0x9F then
        out[#out + 1] = string.char(0xD0, b + 0x20)
      elseif b >= 0xA0 and b <= 0xAF then
        out[#out + 1] = string.char(0xD1, b - 0x20)
      else
        out[#out + 1] = s:sub(i, i + 1)
      end
      i = i + 2
    elseif c >= 0xC2 and c <= 0xDF then
      out[#out + 1] = s:sub(i, i + 1); i = i + 2
    elseif c >= 0xE0 and c <= 0xEF then
      out[#out + 1] = s:sub(i, i + 2); i = i + 3
    elseif c >= 0xF0 and c <= 0xF4 then
      out[#out + 1] = s:sub(i, i + 3); i = i + 4
    else
      out[#out + 1] = s:sub(i, i); i = i + 1
    end
  end
  return table.concat(out)
end

local function Normalize(value)
  if not value or IsSecret(value) then return "" end
  return (Utf8Lower(value):gsub("[%s%'%-]+", ""))
end

local function MakeKey(name, realm)
  local n, r = Normalize(name), Normalize(realm)
  if n == "" or r == "" then return nil end
  return n .. "-" .. r
end

function addon.GetProfile(name, realm)
  if type(ForsakenIODB) ~= "table" or type(ForsakenIODB.byKey) ~= "table" then return nil end
  local key = MakeKey(name, realm)
  return key and ForsakenIODB.byKey[key] or nil
end

local function UnitNameRealm(unit)
  local name, realm = UnitFullName(unit)
  if IsSecret(name) or IsSecret(realm) then return nil end
  if not realm or realm == "" then
    realm = GetNormalizedRealmName()
    if IsSecret(realm) then return nil end
  end
  return name, realm
end

function addon.GetProfileForUnit(unit)
  -- Спрятанный указатель (моб, игрок в подземелье) игре не передаём: UnitExists
  -- на нём - ошибка «Secret values are only allowed during untainted execution»
  -- (тестер 6 октября, тысячи раз на мобах и в бою).
  if not unit or IsSecret(unit) then return nil end
  if not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
  local name, realm = UnitNameRealm(unit)
  if not name then return nil end
  return addon.GetProfile(name, realm)
end

local function StripColors(text)
  if not text or IsSecret(text) then return nil end
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

function addon.GetProfileFromFullName(fullName)
  fullName = StripColors(fullName)
  if not fullName or fullName == "" then return nil end
  fullName = strtrim(fullName)
  local name, realm = fullName:match("^(.-)%-(.+)$")
  if not name then
    name, realm = fullName, GetNormalizedRealmName()
  end
  if IsSecret(name) or IsSecret(realm) then return nil end
  return addon.GetProfile(strtrim(name), strtrim(realm))
end

-- Подсказка ------------------------------------------------------------------

local GOLD = { 0.85, 0.72, 0.42 }
local MUTED = { 0.65, 0.65, 0.70 }

-- Возраст снимка в днях по generatedAt («2026-10-03T09:12:00Z»). Время UTC
-- читается как местное - ошибка в часы, для счёта дней не важно.
-- Снимок обновляется каждый день, поэтому 3 дня - уже повод обновить аддон.
local STALE_DAYS = 3
function addon.SnapshotAgeDays()
  local at = type(ForsakenIODB) == "table" and ForsakenIODB.generatedAt
  if type(at) ~= "string" or not time then return nil end
  local y, mo, d, h, mi = at:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if not mi then return nil end
  local made = time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = 0 })
  return made and math.max(0, math.floor((time() - made) / 86400)) or nil
end

local function SeasonTitle()
  local season = ForsakenIODB and ForsakenIODB.season
  local name = season and season.name or "Season"
  -- Межсезонье: в снимке итоговая таблица прошедшего сезона.
  if season and season.phase == "interseason" then name = name .. " - " .. L"FIO_FINAL" end
  return name
end

-- Рейтинг по ключам - таблицей: сверху +20 … +45, под каждым его рейтинг
-- (пользователь 3 октября: строка «+20 399 +30 321 …» читалась плохо).
-- Строками текста ровных столбцов не выйдет - цифры разной ширины, поэтому
-- своя рамка через GameTooltip_InsertFrame; при очистке подсказки игра
-- прячет её сама (SharedTooltip_ClearInsertedFrames в OnTooltipCleared,
-- сверено по исходникам интерфейса 12.1.0).
local TIERS = { 20, 30, 35, 40, 45 }
-- Ширина столбца - по самой длинной надписи в нём, высота строки - по
-- шрифту: у пользователя крупный шрифт подсказок, и жёсткие 42 точки
-- обрезали рейтинг в «6…» (3 октября). Между столбцами - зазор.
local COL_GAP = 10
-- Цвет уровня ключа от лёгкого к тяжёлому (пользователь 3 октября): зелёный,
-- синий, фиолетовый, оранжевый, красный - как качество вещей в игре. Синий
-- светлее игрового 0070dd: тот на тёмной подсказке сливается.
local TIER_COLOR = {
  [20] = { 0.12, 1.00, 0.00 },
  [30] = { 0.20, 0.60, 1.00 },
  [35] = { 0.64, 0.21, 0.93 },
  [40] = { 1.00, 0.50, 0.00 },
  [45] = { 1.00, 0.20, 0.20 },
}

function addon:IsTiersEnabled()
  return not ForsakenIOSettings or ForsakenIOSettings.tiersEnabled ~= false
end

local function TierGrid(tooltip)
  local grid = tooltip.ForsakenIOTiers
  if grid then return grid end
  grid = CreateFrame("Frame", nil, tooltip)
  grid.head, grid.value = {}, {}
  for i = 1, #TIERS do
    local h = grid:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    h:SetJustifyH("CENTER")
    local v = grid:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    v:SetJustifyH("CENTER")
    grid.head[i], grid.value[i] = h, v
  end
  tooltip.ForsakenIOTiers = grid
  return grid
end

-- Замер надписи. Если в подсказке есть спрятанные данные (Midnight), игра
-- прячет и размеры её строк: замер вернёт «секретное число», и любая
-- арифметика на нём - ошибка (тестер 6 октября). Тогда считаем по шрифту:
-- размер шрифта × число видимых букв.
local function FontSize()
  if not GameTooltipText then return 12 end
  local _, size = GameTooltipText:GetFont()
  if IsSecret(size) or type(size) ~= "number" then return 12 end
  return size
end

local function Measure(fs, method, estimate)
  local ok, v = pcall(fs[method], fs)
  if ok and not IsSecret(v) and type(v) == "number" and v > 0 then return v end
  return estimate
end

local function TextWidth(fs, text)
  local letters = #(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\128-\191]", ""))
  return Measure(fs, fs.GetUnboundedStringWidth and "GetUnboundedStringWidth" or "GetStringWidth", letters * FontSize() * 0.62)
end

local function AddTiers(tooltip, profile)
  if not GameTooltip_InsertFrame then return end
  local grid = TierGrid(tooltip)
  -- Сверху «+20 (8)»: уровень ключа его цветом, в скобках - сколько
  -- подземелий этого уровня зачтено (пользователь 3 октября: вместо общего
  -- числа зачётов в «Лучший уровень»). Снизу - рейтинг за этот уровень.
  local mr, mg, mb = MUTED[1] * 255, MUTED[2] * 255, MUTED[3] * 255
  local headText, valueText = {}, {}
  for i, tier in ipairs(TIERS) do
    local c = TIER_COLOR[tier]
    local runs = tonumber(profile["runs" .. tier]) or 0
    headText[i] = string.format("|cff%02x%02x%02x+%d|r |cff%02x%02x%02x(%d)|r",
      c[1] * 255, c[2] * 255, c[3] * 255, tier, mr, mg, mb, runs)
    grid.head[i]:SetText(headText[i])
    local score = tonumber(profile["score" .. tier]) or 0
    valueText[i] = score > 0 and tostring(score) or "-"
    grid.value[i]:SetText(valueText[i])
    if score > 0 then grid.value[i]:SetTextColor(1, 1, 1) else grid.value[i]:SetTextColor(MUTED[1], MUTED[2], MUTED[3]) end
  end
  local rowH = math.max(Measure(grid.head[1], "GetStringHeight", FontSize()), 12) + 2
  local x = 0
  for i = 1, #TIERS do
    local w = math.max(TextWidth(grid.head[i], headText[i]), TextWidth(grid.value[i], valueText[i])) + COL_GAP
    for _, fs in ipairs({ grid.head[i], grid.value[i] }) do fs:SetWidth(w) end
    grid.head[i]:ClearAllPoints()
    grid.head[i]:SetPoint("TOPLEFT", x, 0)
    grid.value[i]:ClearAllPoints()
    grid.value[i]:SetPoint("TOPLEFT", x, -rowH)
    x = x + w
  end
  grid:SetSize(x, rowH * 2)
  GameTooltip_InsertFrame(tooltip, grid)
  -- InsertFrame ставит минимум ширины подсказки = ширине таблицы, но в него
  -- входят и поля подсказки: у узкой подсказки последний столбец обрезался
  -- в «3…» (3 октября). Запас на поля; при очистке подсказки снимаем -
  -- игра сама его не сбрасывает.
  tooltip:SetMinimumWidth(x + 24)
  tooltip.ForsakenIOMinWidth = true
end

-- Название лучшего подземелья на языке модуля: снимок хранит его на трёх
-- языках (forsaken_sync.js), чтобы не зависеть от переводов ядра.
local function DungeonName(profile)
  local lang = TrialGearFinderForsakenLang()
  return (lang == "ruRU" and profile.bestDungeon) or (lang == "zhCN" and profile.bestDungeonZh)
    or profile.bestDungeonEn or profile.bestDungeon
end

-- Сокращение названия подземелья первыми буквами слов: «Чаща Темного
-- Сердца» -> «ЧТС», «Darkheart Thicket» -> «DT». Английские The / of
-- пропускаем («Forge of Souls» -> «FS», как зовут игроки). В названии без
-- пробелов (китайский) сокращать нечего - отдаём как есть.
local SKIP_WORD = { the = true, of = true }
-- Строчная кириллица в UTF-8 -> прописная: string.upper её не трогает.
local function UpperFirst(ch)
  local a, b = ch:byte(1, 2)
  if a == 0xD0 and b and b >= 0xB0 and b <= 0xBF then return string.char(0xD0, b - 0x20) end
  if a == 0xD1 and b and b >= 0x80 and b <= 0x8F then return string.char(0xD0, b + 0x20) end
  if a == 0xD1 and b == 0x91 then return string.char(0xD0, 0x81) end -- ё
  return ch:upper()
end

local function Abbrev(name)
  if not name or not name:find(" ", 1, true) then return name end
  local out = {}
  for word in name:gmatch("[^%s%-:]+") do
    if not SKIP_WORD[word:lower()] then
      out[#out + 1] = UpperFirst(word:match("^[%z\1-\127\194-\244][\128-\191]*"))
      -- Заглавная после апострофа - вторая часть имени: «Драк'Тарон» -> «ДТ»,
      -- иначе Крепость Драк'Тарон и Кузня Душ обе давали «КД».
      for cap in word:gmatch("'([A-Z\208][\128-\175]?)") do
        -- Латиница A-Z - один байт; прописная кириллица - D0 90..AF (строчная
        -- D0 B0.. под шаблон не попадает, остаётся одинокий D0 - отбрасываем).
        local b1, b2 = cap:byte(1, 2)
        if b1 ~= 0xD0 or b2 then out[#out + 1] = cap end
      end
    end
  end
  return table.concat(out)
end

function addon.AppendProfile(tooltip, profile)
  if not tooltip or not profile or tooltip.ForsakenIOAdded then return false end
  tooltip.ForsakenIOAdded = true

  local r, g, b = addon.ProfileColor(profile)
  local cr, cg, cb = ClassColor(profile)
  local main = type(profile.specs) == "table" and profile.specs[1]
    or { spec = profile.spec, specID = profile.specID }
  local spec = SpecName(main.specID, main.spec)
  local role = main.role and ROLE_KEY[main.role] and L(ROLE_KEY[main.role])

  tooltip:AddLine(" ")
  tooltip:AddLine("Forsaken Dungeons+", GOLD[1], GOLD[2], GOLD[3])
  tooltip:AddDoubleLine(SeasonTitle(), profile.rank and ("#" .. profile.rank) or "", 1, 1, 1, r, g, b)
  tooltip:AddDoubleLine(L"FIO_RATING", tostring(profile.score or 0), 1, 1, 1, r, g, b)
  local raidDone = tonumber(profile.raidsCompleted)
  if raidDone then
    local total = tonumber(profile.raidsTotal) or tonumber(ForsakenIODB and ForsakenIODB.raidTotal) or 5
    tooltip:AddDoubleLine(L"FIO_RAIDS", string.format("%d/%d", raidDone, total), 1, 1, 1, cr, cg, cb)
  end
  -- Одной строкой «+45 | ЧТС | 345»: название - первыми буквами (пользователь
  -- 3 октября: «сокращай по первым буквам, Чертоги Доблести - ЧД», между
  -- частями черта). Отдельной строки «Лучший уровень» больше нет - уровень
  -- лучшего прохождения здесь. Черта в тексте игры - «||»: одна «|» это
  -- начало цвета.
  if profile.bestDungeon then
    local SEP = " || "
    local c = TIER_COLOR[profile.bestDungeonTier]
    local tierText = profile.bestDungeonTier and (c and string.format("|cff%02x%02x%02x+%d|r", c[1] * 255, c[2] * 255, c[3] * 255,
      profile.bestDungeonTier) or ("+" .. profile.bestDungeonTier)) .. SEP or ""
    local scoreText = profile.bestDungeonScore and SEP .. string.format("|cff%02x%02x%02x%d|r", r * 255, g * 255, b * 255,
      profile.bestDungeonScore) or ""
    tooltip:AddDoubleLine(L"FIO_BEST_DUNGEON", tierText .. Abbrev(DungeonName(profile)) .. scoreText, 1, 1, 1, 1, 1, 1)
  end
  if spec and spec ~= "" then
    tooltip:AddLine(role and string.format("%s (%s)", spec, role) or spec, cr, cg, cb)
  end
  if addon:IsTiersEnabled() then AddTiers(tooltip, profile) end
  -- Старый снимок - предупреждаем, как Raider.IO (пользователь 3 октября).
  local age = addon.SnapshotAgeDays()
  if age and age >= STALE_DAYS then
    tooltip:AddLine(L("FIO_STALE"):format(age), 1, 0.45, 0.2, true)
  end
  return true
end

local function UnitFromTooltip(tooltip, data)
  local _, unit = tooltip:GetUnit()
  if unit then return unit end
  if data and data.guid and UnitTokenFromGUID then return UnitTokenFromGUID(data.guid) end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if not addon:IsTooltipEnabled() then return end
    local profile = addon.GetProfileForUnit(UnitFromTooltip(tooltip, data))
    if profile then addon.AppendProfile(tooltip, profile) end
  end)
end

local function ClearMarker(tooltip)
  tooltip.ForsakenIOAdded = nil
  if tooltip.ForsakenIOMinWidth then
    tooltip.ForsakenIOMinWidth = nil
    tooltip:SetMinimumWidth(0)
  end
end
if GameTooltip then GameTooltip:HookScript("OnTooltipCleared", ClearMarker) end
if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipCleared", ClearMarker) end

-- Список гильдии и сообществ -------------------------------------------------

local function AppendFromFullName(tooltip, fullName)
  if not addon:IsTooltipEnabled() or not tooltip or not fullName or IsSecret(fullName) then return end
  local profile = addon.GetProfileFromFullName(fullName)
  if profile and addon.AppendProfile(tooltip, profile) then tooltip:Show() end
end

local function OnMemberEnter(self)
  local info = type(self.GetMemberInfo) == "function" and self:GetMemberInfo()
  if not info or not info.name or IsSecret(info.name) then return end
  local clubType = info.clubType
  if clubType and Enum and Enum.ClubType then
    if IsSecret(clubType) then return end
    if clubType ~= Enum.ClubType.Guild and clubType ~= Enum.ClubType.Character then return end
  end
  AppendFromFullName(GameTooltip, info.name)
end

local function OnGuildRosterEnter(self)
  local index = self.index or self.guildIndex
  if index and GetGuildRosterInfo then AppendFromFullName(GameTooltip, (GetGuildRosterInfo(index))) end
end

local hooked = {}
local function HookButton(button, handler)
  if not button or hooked[button] then return end
  hooked[button] = true
  button:HookScript("OnEnter", handler)
end

local function HookScrollBox(scrollBox, handler)
  if not scrollBox then return end
  if scrollBox.ForEachFrame then scrollBox:ForEachFrame(function(frame) HookButton(frame, handler) end) end
  if scrollBox._forsakenIOHooked then return end
  scrollBox._forsakenIOHooked = true
  if scrollBox.RegisterCallback then
    pcall(function()
      scrollBox:RegisterCallback("OnAcquiredFrame", function(_, frame) HookButton(frame, handler) end)
    end)
  end
end

local function HookAll()
  if CommunitiesMemberListEntryMixin and not addon._guildMixinHooked then
    addon._guildMixinHooked = true
    hooksecurefunc(CommunitiesMemberListEntryMixin, "OnEnter", OnMemberEnter)
  end
  if CommunitiesFrame and CommunitiesFrame.MemberList then
    HookScrollBox(CommunitiesFrame.MemberList.ScrollBox, OnMemberEnter)
  end
  if GuildRosterContainer then HookScrollBox(GuildRosterContainer, OnGuildRosterEnter) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" or name == "Blizzard_Communities" or name == "Blizzard_GuildFrame" then HookAll() end
end)

-- /fdio ----------------------------------------------------------------------

local function PrintProfile(profile, title)
  if not profile then
    addon:Print(L("FIO_NOT_IN_SNAPSHOT"):format(title))
    return
  end
  local best = profile.bestTier and ("+" .. profile.bestTier) or "-"
  local raids = ""
  if profile.raidsCompleted ~= nil then
    raids = L("FIO_PROFILE_RAIDS"):format(profile.raidsCompleted, profile.raidsTotal or 5)
  end
  addon:Print(L("FIO_PROFILE"):format(title, SeasonTitle(), profile.score or 0, profile.rank or "-",
    best, profile.runs or 0, raids))
end

SLASH_FORSAKENIO1 = "/fdio"
SLASH_FORSAKENIO2 = "/forsaken"
SlashCmdList.FORSAKENIO = function(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "tooltip" or msg == "тултип" then
    local enabled = not addon:IsTooltipEnabled()
    addon:SetTooltipEnabled(enabled)
    addon:Print(L(enabled and "FIO_TOOLTIP_ON" or "FIO_TOOLTIP_OFF"))
    return
  end
  local db = type(ForsakenIODB) == "table" and ForsakenIODB or {}
  addon:Print(L("FIO_SUMMARY"):format(SeasonTitle(), db.count or 0, db.generatedAt or L"FIO_UNKNOWN"))
  PrintProfile(addon.GetProfileForUnit("player"), L"FIO_YOU")
  if UnitExists("target") and UnitIsPlayer("target") then
    PrintProfile(addon.GetProfileForUnit("target"), UnitName("target") or L"FIO_TARGET")
  end
  addon:Print(L"FIO_COMMANDS")
end
