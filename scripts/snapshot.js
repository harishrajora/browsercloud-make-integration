// SNAPSHOT_SCRIPT — runs in the cloud browser via WebDriver POST /execute/sync.
// Tags every interactive, visible, in-viewport element with data-ref="N" and returns
//   { elements: [{ref, tag, role, text}], text: "1. <tag> [role] text\n2. ..." }
// Ported from the n8n node's SNAPSHOT_SCRIPT (data-n8n-ref -> data-ref; now also returns
// a pre-formatted `text` so Make needs no IML formatting).
//
// NOTE: the imljson modules embed a single-line, JSON-escaped copy of this script in their
// request body. This file is the readable master — keep the two in sync.

var S = 'a,button,input,textarea,select,[role=button],[role=link],[role=tab],[role=menuitem],[role=checkbox],[role=radio],[tabindex="0"]';
document.querySelectorAll('[data-ref]').forEach(function (e) { e.removeAttribute('data-ref'); });

var out = [], n = 1, els = document.querySelectorAll(S);
for (var i = 0; i < els.length; i++) {
  var el = els[i];
  var tag = el.tagName.toLowerCase();
  var it = (el.getAttribute('type') || '').toLowerCase();
  var dis = ('disabled' in el && el.disabled) || el.getAttribute('aria-disabled') === 'true';
  var hid = el.getAttribute('aria-hidden') === 'true' || el.hidden || (tag === 'input' && it === 'hidden');
  if (dis || hid) continue;

  var r = el.getBoundingClientRect();
  if (r.width <= 0 || r.height <= 0) continue;

  var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
  if (cy >= 0 && cy < window.innerHeight && cx >= 0 && cx < window.innerWidth) {
    var t = document.elementFromPoint(cx, cy);
    if (t && !(t === el || el.contains(t) || t.contains(el))) continue; // occluded
  }

  var ro = 'readOnly' in el && el.readOnly;
  var role = (el.getAttribute('role') || tag) + (ro ? ' (readonly)' : '');
  var text = (el.innerText || el.value || el.placeholder || el.getAttribute('aria-label') || el.getAttribute('title') || '')
    .replace(/\s+/g, ' ').trim().slice(0, 120);

  var ref = n++;
  el.setAttribute('data-ref', String(ref));
  out.push({ ref: ref, tag: tag, role: role, text: text });
}

return {
  elements: out,
  text: out.map(function (o) { return o.ref + '. <' + o.tag + '> [' + o.role + '] ' + o.text; })
            .join(String.fromCharCode(10))
};
