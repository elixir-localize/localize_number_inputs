// Localize.Inputs Phoenix LiveView hooks.
//
// Exports one hook today:
//
//   NumberInput — locale-aware live formatting for plain numbers
//
// AutoNumeric (https://autonumeric.org/) is a *peer* dependency.
// Install it in the host app:
//
//   npm install autonumeric
//
// And expose it on window before importing these hooks, or call
// `configure({ AutoNumeric })` before constructing your
// LiveSocket. Without AutoNumeric the hook degrades to the Path A
// baseline: the input still works, the server-side parser still
// accepts whatever the user typed, but live formatting and cursor
// preservation are off.

let AutoNumericCtor =
  (typeof window !== "undefined" && window.AutoNumeric) || null;

/** Inject a specific AutoNumeric constructor (for bundlers that
 *  don't put it on window). Call this before `new LiveSocket`. */
export function configure({ AutoNumeric }) {
  AutoNumericCtor = AutoNumeric || AutoNumericCtor;
}

function readData(el) {
  const d = el.dataset;
  const num = (v) => (v == null || v === "" ? null : Number(v));
  return {
    locale: d.locale || "en",
    decimal: d.decimal || ".",
    group: d.group || ",",
    minus: d.minus || "-",
    digitSystem: d.digitSystem || "latn",
    integer: d.integer === "true",
    decimals: num(d.decimals),
    min: d.min || null,
    max: d.max || null,
  };
}

function buildAutoNumericOptions(data) {
  const decimals = data.decimals ?? (data.integer ? 0 : 6);

  return {
    decimalCharacter: data.decimal,
    digitGroupSeparator: data.group,
    decimalCharacterAlternative: data.decimal === "." ? "," : ".",
    negativeSignCharacter: data.minus,
    decimalPlaces: decimals,
    decimalPlacesShownOnFocus: decimals,
    decimalPlacesShownOnBlur: decimals,
    allowDecimalPadding: false,
    currencySymbol: "",
    selectOnFocus: false,
    modifyValueOnWheel: false,
    minimumValue: data.min ?? "-10000000000000",
    maximumValue: data.max ?? "10000000000000",
    onInvalidPaste: "clamp",
    digitalGroupSpacing: data.locale && data.locale.startsWith("en-IN") ? "2s" : "3",
  };
}

function cssEscape(value) {
  if (typeof window !== "undefined" && window.CSS && CSS.escape) return CSS.escape(value);
  return value.replace(/[^a-zA-Z0-9_-]/g, "\\$&");
}

function paste_sanitize(event) {
  const text = (event.clipboardData || window.clipboardData).getData("text");
  if (!text) return;
  event.preventDefault();
  const cleaned = text
    .replace(/[   ]/g, " ")
    .replace(/[−–—]/g, "-")
    .replace(/^\((.*)\)$/, "-$1")
    .trim();
  const input = event.target;
  const start = input.selectionStart || 0;
  const end = input.selectionEnd || 0;
  input.value = input.value.slice(0, start) + cleaned + input.value.slice(end);
  const cursor = start + cleaned.length;
  input.setSelectionRange(cursor, cursor);
}

export const NumberInput = {
  mounted() {
    this.input = this.el.querySelector("input.number-input-field");
    if (!this.input) return;

    const data = readData(this.el);

    if (!AutoNumericCtor) {
      this.input.addEventListener("paste", paste_sanitize);
      return;
    }

    // No submit-time canonicalisation: the form value is the
    // user's locale-formatted string. The server parses it with
    // the locale. Wire format is identical with or without
    // AutoNumeric loaded — no canonical-vs-locale ambiguity for
    // the server to puzzle out.
    this.an = new AutoNumericCtor(this.input, buildAutoNumericOptions(data));
  },

  destroyed() {
    if (this.an) this.an.remove();
  },
};

// Sheet-variant breakpoint (matches the CSS rule's expectation).
const UNIT_PICKER_SHEET_BREAKPOINT_PX = 600;

function unitCssEscape(value) {
  if (typeof window !== "undefined" && window.CSS && CSS.escape) return CSS.escape(value);
  return value.replace(/[^a-zA-Z0-9_-]/g, "\\$&");
}

export const UnitPicker = {
  mounted() {
    this.trigger = this.el.querySelector("[data-unit-picker-trigger]");
    this.overlay = this.el.querySelector("[data-unit-picker-overlay]");
    this.search = this.el.querySelector("[data-unit-picker-search]");
    this.list = this.el.querySelector("[data-unit-picker-list]");
    this.closeBtn = this.el.querySelector("[data-unit-picker-close]");
    this.valueInput = this.el.querySelector("[data-unit-picker-value]");
    this.empty = this.el.querySelector("[data-unit-picker-empty]");

    this.variant = this.el.dataset.variant || "auto";

    this.onTriggerClick = (e) => {
      e.preventDefault();
      this.open();
    };
    this.onCloseClick = () => this.close();
    this.onSearchInput = () => this.filter();
    this.onListClick = (e) => {
      const row = e.target.closest("[data-unit-picker-row]");
      if (!row) return;
      // Mirror the CurrencyPicker contract: stop the document-level
      // outside-click handler from firing close()+refocus right after
      // we hand focus to the paired amount input.
      e.stopPropagation();
      e.preventDefault();
      this.selectCode(row.dataset.code, row.dataset.name);
    };
    this.onKeydown = (e) => this.handleKeydown(e);
    this.onDocClick = (e) => {
      if (!this.el.contains(e.target)) this.close();
    };

    this.trigger.addEventListener("click", this.onTriggerClick);
    this.closeBtn.addEventListener("click", this.onCloseClick);
    this.search.addEventListener("input", this.onSearchInput);
    this.list.addEventListener("click", this.onListClick);
    this.el.addEventListener("keydown", this.onKeydown);

    this.applySheetVariant();
  },

  destroyed() {
    this.trigger.removeEventListener("click", this.onTriggerClick);
    this.closeBtn.removeEventListener("click", this.onCloseClick);
    this.search.removeEventListener("input", this.onSearchInput);
    this.list.removeEventListener("click", this.onListClick);
    this.el.removeEventListener("keydown", this.onKeydown);
    document.removeEventListener("click", this.onDocClick);
  },

  applySheetVariant() {
    const useSheet =
      this.variant === "sheet" ||
      (this.variant === "auto" &&
        window.matchMedia(`(max-width: ${UNIT_PICKER_SHEET_BREAKPOINT_PX}px)`).matches);
    this.el.classList.toggle("is-sheet", useSheet);
  },

  open() {
    this.overlay.hidden = false;
    this.trigger.setAttribute("aria-expanded", "true");
    this.applySheetVariant();

    // The picker is rendered inside .unit-input-wrapper, which has
    // overflow:hidden for its rounded corners. Float the overlay
    // with position:fixed so it escapes the clip region. The sheet
    // variant already uses position:fixed via CSS.
    if (!this.el.classList.contains("is-sheet")) {
      this.positionOverlay();
      this.repositionHandler = () => this.positionOverlay();
      window.addEventListener("resize", this.repositionHandler);
      window.addEventListener("scroll", this.repositionHandler, true);
    }

    setTimeout(() => {
      this.search.value = "";
      this.filter();
      this.search.focus();
      document.addEventListener("click", this.onDocClick);
    }, 0);
  },

  close({ refocus = true } = {}) {
    this.overlay.hidden = true;
    this.trigger.setAttribute("aria-expanded", "false");
    document.removeEventListener("click", this.onDocClick);
    if (this.repositionHandler) {
      window.removeEventListener("resize", this.repositionHandler);
      window.removeEventListener("scroll", this.repositionHandler, true);
      this.repositionHandler = null;
    }
    this.overlay.style.position = "";
    this.overlay.style.top = "";
    this.overlay.style.left = "";
    this.overlay.style.width = "";
    if (refocus) this.trigger.focus();
  },

  positionOverlay() {
    const rect = this.trigger.getBoundingClientRect();
    const overlayWidth = Math.max(rect.width, 320);
    const maxLeft = Math.max(8, window.innerWidth - overlayWidth - 8);
    this.overlay.style.position = "fixed";
    this.overlay.style.top = `${rect.bottom + 4}px`;
    // Right-align under the trigger when possible — better fit for
    // narrow viewports where the trigger sits on the right of an
    // input-and-picker pair.
    const preferred = rect.right - overlayWidth;
    this.overlay.style.left = `${Math.max(8, Math.min(preferred, maxLeft))}px`;
    this.overlay.style.width = `${overlayWidth}px`;
  },

  filter() {
    const term = this.search.value.trim().toLowerCase();
    const rows = this.list.querySelectorAll("[data-unit-picker-row]");
    let visible = 0;
    rows.forEach((row) => {
      const hay = `${row.dataset.code} ${row.dataset.name}`.toLowerCase();
      const match = !term || hay.includes(term);
      row.hidden = !match;
      if (match) visible++;
    });
    if (this.empty) this.empty.hidden = visible > 0;
  },

  selectCode(code, displayName) {
    if (!code) return;
    this.el.dataset.current = code;
    const labelNode = this.trigger.querySelector(".unit-picker-current");
    if (labelNode && displayName) labelNode.textContent = displayName;
    if (this.valueInput) {
      this.valueInput.value = code;
      this.valueInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    // Notify the enclosing unit-input wrapper (if any) so other
    // listeners can react to the unit changing (e.g. swap input
    // precision based on unit). The hidden input's change event
    // is also fired above for plain form-binding listeners.
    const wrapper = this.el.closest("[data-unit-input]");
    if (wrapper) {
      wrapper.dispatchEvent(
        new CustomEvent("localize-inputs:unit-change", {
          detail: { unit: code, displayName },
          bubbles: true,
        }),
      );
    }

    // Hand focus back to the paired amount input — picking a unit
    // is almost always followed by typing/adjusting the amount.
    const pairedInput = wrapper && wrapper.querySelector("input.unit-input-field");
    if (pairedInput) {
      this.close({ refocus: false });
      pairedInput.focus();
      const length = pairedInput.value.length;
      try {
        pairedInput.setSelectionRange(length, length);
      } catch (_) {
        // Not all input types support setSelectionRange; ignore.
      }
    } else {
      this.close();
    }
  },

  handleKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      this.close();
      return;
    }
    if (this.overlay.hidden) return;
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const rows = Array.from(
        this.list.querySelectorAll("[data-unit-picker-row]"),
      ).filter((row) => !row.hidden);
      if (rows.length === 0) return;
      const focused = document.activeElement;
      let idx = rows.indexOf(focused);
      idx = (idx + (e.key === "ArrowDown" ? 1 : -1) + rows.length) % rows.length;
      rows[idx].focus();
    } else if (e.key === "Enter") {
      const focused = document.activeElement;
      if (focused && focused.dataset && focused.dataset.code) {
        e.preventDefault();
        this.selectCode(focused.dataset.code, focused.dataset.name);
      }
    }
  },
};

// ── DatePicker hook ─────────────────────────────────────────
//
// Renders a Gregorian month grid in an overlay anchored to a
// trigger button. Day clicks set both the visible text input
// (formatted via Intl.DateTimeFormat) and a hidden ISO input
// (the wire format).
//
// Data attributes read from the wrapper:
//   data-locale          BCP-47 locale (e.g. "en-GB")
//   data-display-format  Intl.DateTimeFormat option key,
//                        one of: short | medium | long | full
//                        (default: medium)
//   data-first-day       1..7 with 1=Monday, 7=Sunday
//                        (default derived from locale).
//   data-min             ISO date — earliest selectable day
//   data-max             ISO date — latest selectable day
//   data-variant         "auto" | "dropdown" | "sheet"
//
// Wire format on the hidden input is always ISO YYYY-MM-DD.

const DATE_PICKER_SHEET_BREAKPOINT_PX = 600;


function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export default { NumberInput, UnitPicker, configure };
