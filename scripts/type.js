// TYPE_SCRIPT(ref, text, submit) — runs in the cloud browser via WebDriver POST /execute/sync.
// Focuses the element, sets its value (or textContent for contenteditable), fires
// input/change so frameworks (React/Vue) pick it up, and optionally submits with Enter.
//
// arguments[0] = ref number, arguments[1] = text, arguments[2] = submit (boolean/"true")
// A fresh snapshot is produced by the SECOND request in the module, not here.

var r = arguments[0], t = arguments[1], sub = arguments[2];
var el = document.querySelector('[data-ref="' + r + '"]');
if (!el) throw new Error('No element with ref ' + r + '; run Snapshot to refresh.');
el.focus();
var tag = el.tagName.toLowerCase();
if (tag === 'input' || tag === 'textarea') { el.value = t; } else { el.textContent = t; }
el.dispatchEvent(new Event('input', { bubbles: true }));
el.dispatchEvent(new Event('change', { bubbles: true }));
if (sub === true || sub === 'true') {
  el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
  if (el.form && el.form.requestSubmit) { el.form.requestSubmit(); }
}
return { ref: r, text: t, submit: sub };
