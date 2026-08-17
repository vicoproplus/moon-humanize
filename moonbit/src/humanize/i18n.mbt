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
pub enum Locale {
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
}

/// Parse a raw locale identifier (e.g. `"zh_CN"`, `"en_GB"`, `"fr_FR"`) into a
/// `Locale`. Returns `None` if the locale is unknown or an English variant
/// (English locales use no translation, matching python-humanize behaviour).
pub fn Locale::from_string(locale : String) -> Option[Locale] {
  // English and unknown locales fall through to no translation.
  if locale.has_prefix("en") {
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
