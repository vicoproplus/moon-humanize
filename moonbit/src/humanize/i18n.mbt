// Internationalization support for moon-humanize.
//
// This module provides locale activation (mirroring python-humanize's
// `humanize.activate`/`deactivate`), message translation helpers, plural
// selection, and thousands/decimal separator lookup. The actual translated
// strings live in `i18n_data.mbt`, which is auto-generated from the project's
// `src/humanize/locale/*.po` files by `scripts/po2mbt`.

/// A supported humanize locale.
///
/// The variant name is the raw locale directory name under
/// `src/humanize/locale/` (e.g. `zh_CN`, `pt_BR`, `fr_FR`). This mirrors
/// python-humanize, where activation is performed by locale directory name.
pub(all) enum Locale {
  Ar
  BnBD
  CaES
  DaDK
  DeDE
  ElGR
  Eo
  EsES
  Eu
  FaIR
  FiFI
  FrFR
  HeIL
  HuHU
  IdID
  ItIT
  JaJP
  KoKR
  Lv
  Nb
  NlNL
  PlPL
  PtBR
  PtPT
  RuRU
  SiLK
  SkSK
  SlSI
  SvSE
  Tlh
  TrTR
  UkUA
  Uz
  ViVN
  ZhCN
  ZhHK
  En
  Zh
}

/// Parse a raw locale identifier (e.g. `"zh_CN"`, `"en_GB"`, `"fr_FR"`) into a
/// `Locale`. Returns `None` if the locale is unknown or an English variant
/// (English locales use no translation, matching python-humanize behaviour).
pub fn Locale::from_string(locale : String) -> Option[Locale] {
  // English and unknown locales fall through to no translation. The bare `en`
  // locale is activated explicitly (it carries its own English catalog).
  if locale.has_prefix("en_") {
    return None
  }
  match locale {
    "ar" => Some(Ar)
    "bn_BD" => Some(BnBD)
    "ca_ES" => Some(CaES)
    "da_DK" => Some(DaDK)
    "de_DE" => Some(DeDE)
    "el_GR" => Some(ElGR)
    "eo" => Some(Eo)
    "es_ES" => Some(EsES)
    "eu" => Some(Eu)
    "fa_IR" => Some(FaIR)
    "fi_FI" => Some(FiFI)
    "fr_FR" => Some(FrFR)
    "he_IL" => Some(HeIL)
    "hu_HU" => Some(HuHU)
    "id_ID" => Some(IdID)
    "it_IT" => Some(ItIT)
    "ja_JP" => Some(JaJP)
    "ko_KR" => Some(KoKR)
    "lv" => Some(Lv)
    "nb" => Some(Nb)
    "nl_NL" => Some(NlNL)
    "pl_PL" => Some(PlPL)
    "pt_BR" => Some(PtBR)
    "pt_PT" => Some(PtPT)
    "ru_RU" => Some(RuRU)
    "si_LK" => Some(SiLK)
    "sk_SK" => Some(SkSK)
    "sl_SI" => Some(SlSI)
    "sv_SE" => Some(SvSE)
    "tlh" => Some(Tlh)
    "tr_TR" => Some(TrTR)
    "uk_UA" => Some(UkUA)
    "uz" => Some(Uz)
    "vi_VN" => Some(ViVN)
    "zh_CN" => Some(ZhCN)
    "zh_HK" => Some(ZhHK)
    "en" => Some(En)
    "zh" => Some(Zh)
    _ => None
  }
}

/// The locale directory name for this `Locale` (used to look up the right
/// translation table in `i18n_data.mbt`).
pub fn Locale::to_dir(self : Locale) -> String {
  match self {
    Ar => "ar"
    BnBD => "bn_BD"
    CaES => "ca_ES"
    DaDK => "da_DK"
    DeDE => "de_DE"
    ElGR => "el_GR"
    Eo => "eo"
    EsES => "es_ES"
    Eu => "eu"
    FaIR => "fa_IR"
    FiFI => "fi_FI"
    FrFR => "fr_FR"
    HeIL => "he_IL"
    HuHU => "hu_HU"
    IdID => "id_ID"
    ItIT => "it_IT"
    JaJP => "ja_JP"
    KoKR => "ko_KR"
    Lv => "lv"
    Nb => "nb"
    NlNL => "nl_NL"
    PlPL => "pl_PL"
    PtBR => "pt_BR"
    PtPT => "pt_PT"
    RuRU => "ru_RU"
    SiLK => "si_LK"
    SkSK => "sk_SK"
    SlSI => "sl_SI"
    SvSE => "sv_SE"
    Tlh => "tlh"
    TrTR => "tr_TR"
    UkUA => "uk_UA"
    Uz => "uz"
    ViVN => "vi_VN"
    ZhCN => "zh_CN"
    ZhHK => "zh_HK"
    En => "en"
    Zh => "zh"
  }
}

// ---------------------------------------------------------------------------
// Current locale state
// ---------------------------------------------------------------------------

/// The active locale translation, or `None` for no translation (English).
///
/// Mirrors python-humanize's module-level `_CURRENT.locale` / `deactivate()`.
// TODO(T7): wire this to the shared humanizer state when the humanizer is
// connected. For now it defaults to no translation (English output).
priv struct LocaleState {
  mut active : Option[Locale]
}

let locale_state : LocaleState = { active: None }

/// Activate a locale by raw identifier.
///
/// `None` or any `en*` locale disables translation (equivalent to
/// `deactivate()`), matching python-humanize's `activate(None)`. Returns the
/// resulting active locale (`None` means no translation).
pub fn activate(locale : String) -> Option[Locale] {
  let loc = Locale::from_string(locale)
  locale_state.active = loc
  loc
}

/// Deactivate internationalisation (revert to English / no translation).
pub fn deactivate() -> Unit {
  locale_state.active = None
}

/// Return the currently active locale, or `None` for no translation.
pub fn current_locale() -> Option[Locale] {
  locale_state.active
}

/// Return the current translation handle (the active `Locale`), or `None`
/// for no translation (English). Mirrors python-humanize's
/// `humanize.i18n.get_translation()` which returns the active locale's
/// `NullTranslations` object (or a fresh `NullTranslations()` when none is set).
pub fn get_translation() -> Option[Locale] {
  current_locale()
}

// ---------------------------------------------------------------------------
// Translation helpers
// ---------------------------------------------------------------------------

/// Translate `message` for the active locale. Falls back to the original
/// English `message` when no translation is active or none is found.
pub fn gettext(message : String) -> String {
  match current_locale() {
    None => message
    Some(loc) => lookup_message(loc, message, message)
  }
}

/// Translate `message` with a context (`msgctxt`), allowing duplicate source
/// strings to map to different translations. Mirrors python-humanize's
/// `pgettext`.
pub fn pgettext(msgctxt : String, message : String) -> String {
  match current_locale() {
    None => message
    Some(loc) => lookup_context(loc, msgctxt, message, message)
  }
}

/// Select the correct plural form for `num` given the active locale's plural
/// rules, returning the translated plural string. Falls back to `plural` for
/// English / no translation.
pub fn ngettext(singular : String, plural : String, num : Int) -> String {
  match current_locale() {
    None => if num == 1 { singular } else { plural }
    Some(loc) => {
      let form = plural_index(loc, num)
      lookup_plural(loc, singular, plural, form, plural)
    }
  }
}

// ---------------------------------------------------------------------------
// Separator lookup (mirrors python-humanize's thousands/decimal maps)
// ---------------------------------------------------------------------------

/// Thousands separator for the active locale (defaults to `","`).
pub fn thousands_separator() -> String {
  match current_locale() {
    None => ","
    Some(loc) => thousands_sep_for(loc)
  }
}

/// Decimal separator for the active locale (defaults to `"."`).
pub fn decimal_separator() -> String {
  match current_locale() {
    None => "."
    Some(loc) => decimal_sep_for(loc)
  }
}

// ---------------------------------------------------------------------------
// Message identifiers (Feature 2: i18n-aware scientific notation)
// ---------------------------------------------------------------------------

/// Logical identifiers for humanize messages that participate in localized
/// formatting. `msg_str` resolves one (given a `Locale`) to a `MsgId` whose
/// `format` method substitutes positional `%s` placeholders.
///
/// Not every locale ships every key (only `en`/`ru_RU`/`zh`/`zh_CN` currently
/// carry the scientific-notation keys). `msg_str` falls back to the English
/// catalog, then to the raw key string, so formatting is always total.
pub(all) enum MsgKey {
  ERR
  SEC
  MIN
  HR
  DAY
  WK
  NOW
  RECENT
  FUTURE
  PAST
  SCItmpl
  EXPword1
  EXPword2
  EXPword3
  EXPword4
  EXPword5
  EXPword6
}

/// A message id already resolved to its translated template string for a
/// locale. `format` substitutes positional `%s` placeholders.
pub struct MsgId {
  template : String
}

/// The `.po` msgid string for a given `MsgKey`.
fn msgid_of(self : MsgKey) -> String {
  match self {
    ERR => "an error occurred"
    SEC => "second"
    MIN => "minute"
    HR => "hour"
    DAY => "day"
    WK => "week"
    NOW => "just now"
    RECENT => "recently"
    FUTURE => "from now"
    PAST => "ago"
    SCItmpl => "scientific_tmpl"
    EXPword1 => "EXPword1"
    EXPword2 => "EXPword2"
    EXPword3 => "EXPword3"
    EXPword4 => "EXPword4"
    EXPword5 => "EXPword5"
    EXPword6 => "EXPword6"
  }
}

/// Resolve a message key to its translated template string in `locale`, falling
/// back to the English catalog and finally to the msgid itself.
pub fn msg_str(locale : Locale, id : MsgKey) -> MsgId {
  let key = id.msgid_of()
  let en = lookup_message(En, key, key)
  let resolved = lookup_message(locale, key, en)
  { template: resolved }
}

/// Substitute positional `%s` placeholders in the template with `args`.
pub fn format(self : MsgId, args : Array[String]) -> String {
  let mut out = ""
  let mut arg_i = 0
  let chars = self.template.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if chars[i] == '%' && i + 1 < len && chars[i + 1] == 's' {
      if arg_i < args.length() {
        out = out + args[arg_i]
        arg_i = arg_i + 1
      }
      i = i + 2
    } else {
      out = out + chars[i].to_string()
      i = i + 1
    }
  }
  out
}

/// The raw resolved template (no substitution).
pub fn to_string(self : MsgId) -> String {
  self.template
}
