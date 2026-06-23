// GETTEXT_SCRIPT(ref, maxLen) — runs in the cloud browser via WebDriver POST /execute/sync.
// Reads visible text from a specific ref, or the whole page body when ref is 0/empty.
// Collapses whitespace, trims, and truncates to maxLen.
//
// arguments[0] = ref number (0/empty = whole page), arguments[1] = max length
// Returns { text, length, truncated } — length is the FULL length before truncation.

var r = parseInt(arguments[0], 10) || 0;
var m = parseInt(arguments[1], 10) || 4000;
var el = (r > 0) ? document.querySelector('[data-ref="' + r + '"]') : document.body;
var s = ((el && el.innerText) || '').replace(/\s+/g, ' ').trim();
return { text: s.slice(0, m), length: s.length, truncated: s.length > m };
