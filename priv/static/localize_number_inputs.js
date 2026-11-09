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

// Start AutoNumeric from the plain amount the server renders in
// `data-amount` ("1234.56"), not from the formatted text.
// AutoNumeric reads a grouped integer such as "1.234" (de, nl,
// pt) as 1.234, and cannot read direction marks. Passing the
// amount to the constructor does not help either: it is parsed
// with the locale's separators, so "1234.56" becomes 123456 in
// de. Start AutoNumeric on an empty field and hand it the amount
// with `set()`, which reads a plain decimal.
function startAutoNumeric(hook) {
  const input = hook.input;
  const amount = input.dataset.amount;
  const serverValue = input.value;

  // Text without `data-amount` is text the server could not read
  // as a number. AutoNumeric would erase it, so leave it for the
  // user to correct, and start once the server sends an amount.
  if (amount === undefined && serverValue.trim() !== "") {
    usePlainInput(hook);
    return;
  }

  const valueAttribute = input.getAttribute("value");
  const options = buildAutoNumericOptions(hook.data);
  stopPlainInput(hook);
  input.value = "";

  try {
    hook.an = new AutoNumericCtor(input, options);
    if (amount !== undefined) hook.an.set(amount);
    hook.options = options;
  } catch (error) {
    // AutoNumeric throws on options it cannot use, and on an
    // amount outside `data-min` / `data-max`. Keep the server's
    // text rather than leave the field blank.
    stopAutoNumeric(hook);
    input.value = serverValue;
    disableAutoNumeric(hook, error);
  }

  if (hook.an) watchFormReset(hook);

  // AutoNumeric copies the emptied value into the `value`
  // attribute when it starts, even if `set()` then throws. Put
  // the server's text back: a form reset restores from it, and
  // LiveView sends the reset value to the server.
  if (valueAttribute === null) {
    input.removeAttribute("value");
  } else {
    input.setAttribute("value", valueAttribute);
  }
}

// LiveView rewrites the value of an unfocused input on every
// patch without telling AutoNumeric, which keeps its own copy of
// the number and rewrites the field from it on mouseleave, focus
// and blur. A stale copy blanks the field, brings back an old
// value, or restores one the server cleared. Re-read the data
// attributes and the server's amount after each patch and hand
// them to AutoNumeric.
function syncAutoNumeric(hook) {
  if (!hook.input || !AutoNumericCtor || hook.failed) return;

  hook.data = readData(hook.el);

  // LiveView leaves a focused input's value alone, so the user's
  // typing stays authoritative until they leave the field.
  const focused = document.activeElement === hook.input;

  if (!hook.an) {
    if (!focused) startAutoNumeric(hook);
    return;
  }

  const options = buildAutoNumericOptions(hook.data);
  if (JSON.stringify(options) !== JSON.stringify(hook.options)) {
    try {
      hook.an.update(options);
      hook.options = options;
    } catch (error) {
      failAutoNumeric(hook, error);
      return;
    }
  }

  if (focused) return;

  const amount = hook.input.dataset.amount;
  const value = hook.input.value;

  // Text the server could not read as a number: AutoNumeric
  // would erase it, so step aside until the server sends an
  // amount.
  if (amount === undefined && value.trim() !== "") {
    stopAutoNumeric(hook);
    hook.input.value = value;
    usePlainInput(hook);
    return;
  }

  const target = amount === undefined ? "" : amount;
  const inSync =
    hook.an.getNumericString() === target && value === hook.an.getFormatted();
  if (inSync) return;

  try {
    hook.an.set(target);
  } catch (error) {
    failAutoNumeric(hook, error);
  }
}

// A form reset puts the server's text back from the `value`
// attribute, and AutoNumeric then re-reads that text on a timer,
// which turns "1.234" (de, nl, pt) into 1.234. AutoNumeric adds
// its reset listener when it starts, before this one, so this
// timer runs after its own and hands it the plain amount.
function watchFormReset(hook) {
  const form = hook.input.form;
  if (!form) return;

  hook.form = form;
  hook.onReset = () => {
    setTimeout(() => {
      if (!hook.an) return;
      const amount = hook.input.dataset.amount;
      try {
        hook.an.set(amount === undefined ? "" : amount);
      } catch (error) {
        failAutoNumeric(hook, error);
      }
    }, 0);
  };
  form.addEventListener("reset", hook.onReset);
}

function stopAutoNumeric(hook) {
  if (hook.an) hook.an.remove();
  hook.an = null;

  if (hook.onReset) {
    hook.form.removeEventListener("reset", hook.onReset);
    hook.onReset = null;
  }
}

// Remove AutoNumeric after it threw, keeping LiveView's value.
function failAutoNumeric(hook, error) {
  const value = hook.input.value;
  stopAutoNumeric(hook);
  hook.input.value = value;
  disableAutoNumeric(hook, error);
}

function disableAutoNumeric(hook, error) {
  hook.an = null;
  hook.failed = true;
  console.warn(
    "NumberInput: AutoNumeric rejected the options or value for locale " +
      `${hook.data.locale}; live formatting is off for this field.`,
    error,
  );
  usePlainInput(hook);
}

// Without AutoNumeric the form still submits and the server-side
// parser still accepts the locale-typed string. Only the live
// formatting and cursor preservation are lost.
function usePlainInput(hook) {
  if (hook.onPaste) return;
  hook.onPaste = paste_sanitize;
  hook.input.addEventListener("paste", hook.onPaste);
}

function stopPlainInput(hook) {
  if (!hook.onPaste) return;
  hook.input.removeEventListener("paste", hook.onPaste);
  hook.onPaste = null;
}

export const NumberInput = {
  mounted() {
    this.input = this.el.querySelector("input.number-input-field");
    if (!this.input) return;

    this.data = readData(this.el);

    // No submit-time canonicalisation: the form value is the
    // user's locale-formatted string. The server parses it with
    // the locale. Wire format is identical with or without
    // AutoNumeric loaded — no canonical-vs-locale ambiguity for
    // the server to puzzle out.
    if (AutoNumericCtor) {
      startAutoNumeric(this);
    } else {
      usePlainInput(this);
    }
  },

  updated() {
    syncAutoNumeric(this);
  },

  destroyed() {
    stopAutoNumeric(this);
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
