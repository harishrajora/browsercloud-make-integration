// CLICK_SCRIPT(ref) — runs in the cloud browser via WebDriver POST /execute/sync.
// Finds the element tagged in the last snapshot, scrolls it into view, and clicks it.
// Throws (surfaced to the agent) if the ref no longer exists.
//
// arguments[0] = ref number (from the latest snapshot)
// A fresh snapshot is produced by the SECOND request in the module, not here.

var r = arguments[0];
var el = document.querySelector('[data-ref="' + r + '"]');
if (!el) throw new Error('No element with ref ' + r + '; run Snapshot to refresh.');
el.scrollIntoView({ block: 'center' });
el.click();
return { ref: r };
