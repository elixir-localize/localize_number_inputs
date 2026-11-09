# Status

**Status:** active, 2026-11-09

**Next release:** 0.2.2
**Blocked on:** localize ~> 1.7

`localize_number_inputs` is a published library under active development. With AutoNumeric loaded, 37 locales that write `٫` and `٬` (`ar-EG`, `fa`, `ur-IN`, `ps`, `sd` and others) submit Latin digits with those separators, which localize 1.6.1 refuses to parse; the parser fix is filed under localize 1.7.0. Raise the `localize` requirement to the release that carries it before publishing 0.2.2.
