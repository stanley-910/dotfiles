// ==UserScript==
// @name         Media Grab
// @namespace    stanley.media-grab
// @version      0.1
// @description  Alt+M: list media on the page — download direct files, copy a yt-dlp command for blob/HLS streams
// @match        *://*/*
// @grant        GM_setClipboard
// @connect      *
// @run-at       document-idle
// ==/UserScript==

// Tiers this handles (see chat 2026-08-09):
//   direct src  -> Download button (opens the URL so the CDN's own
//                  Content-Disposition drives the save; see startDownload)
//   blob:/MSE   -> no file exists; sniff .m3u8/.mpd manifests the page fetched
//                  and copy a ready yt-dlp command instead
//   DRM         -> out of scope, nothing here will (or should) help
// Runs in iframes too — if the player lives in an embed, click inside it
// first so the frame has focus, then press the hotkey.

(function () {
  'use strict';

  const HOTKEY = (e) => e.altKey && !e.ctrlKey && !e.metaKey && e.code === 'KeyM';
  const MANIFEST_RE = /\.(m3u8|mpd)(\?|#|$)/i;
  const MEDIA_FILE_RE = /\.(mp4|webm|mov|m4v|mp3|m4a|ogg|opus|wav)(\?|#|$)/i;

  // manifests can load before or after the panel opens — watch continuously
  const seenResources = new Set();
  const harvest = (entries) => entries.forEach((en) => {
    if (MANIFEST_RE.test(en.name) || MEDIA_FILE_RE.test(en.name)) seenResources.add(en.name);
  });
  harvest(performance.getEntriesByType('resource'));
  new PerformanceObserver((list) => harvest(list.getEntries()))
    .observe({ type: 'resource', buffered: true });

  function filenameFor(url) {
    try {
      const last = new URL(url).pathname.split('/').filter(Boolean).pop();
      if (last && /\.\w{2,5}$/.test(last)) return decodeURIComponent(last);
    } catch (_) { /* data:/blob: etc. */ }
    return (document.title || 'media').replace(/[^\w.-]+/g, '_').slice(0, 60) + '.mp4';
  }

  function ytDlpCmd(url) {
    // referer matters: many CDNs 403 without it
    return `yt-dlp --referer '${location.href}' '${url}'`;
  }

  function collect() {
    const rows = [];
    for (const el of document.querySelectorAll('video, audio')) {
      const src = el.currentSrc || el.src ||
        el.querySelector('source')?.src || '';
      const dims = el.videoWidth ? `${el.videoWidth}x${el.videoHeight}` : el.tagName.toLowerCase();
      if (!src) continue;
      rows.push({ kind: dims, src, blob: src.startsWith('blob:') });
    }
    const manifests = [...seenResources].filter((u) => MANIFEST_RE.test(u));
    const files = [...seenResources].filter((u) => MEDIA_FILE_RE.test(u));
    return { rows, manifests, files };
  }

  function button(label, fn) {
    const b = document.createElement('button');
    b.textContent = label;
    b.style.cssText = 'margin-left:8px;padding:2px 8px;cursor:pointer;border:1px solid #666;' +
      'border-radius:4px;background:#333;color:#eee;font:12px monospace';
    b.onclick = fn;
    return b;
  }

  function flash(b, text) {
    const old = b.textContent;
    b.textContent = text;
    setTimeout(() => { b.textContent = old; }, 1200);
  }

  // GM_download silently no-ops under Tampermonkey MV3 on Chromium and dies on
  // cross-origin CDN responses. Navigating to the URL instead lets the CDN's
  // own Content-Disposition header drive the save — the same thing that works
  // when you paste the link into a new tab. download= names it when same-origin
  // (cross-origin browsers ignore the name and honor the CDN header).
  function startDownload(url, name) {
    const a = document.createElement('a');
    a.href = url;
    a.download = name || '';
    a.target = '_blank';
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  function row(panel, label, buttons) {
    const div = document.createElement('div');
    div.style.cssText = 'display:flex;align-items:center;gap:4px;padding:4px 0;' +
      'border-bottom:1px solid #444;overflow:hidden';
    const span = document.createElement('span');
    span.textContent = label;
    span.style.cssText = 'flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis';
    div.append(span, ...buttons);
    panel.appendChild(div);
  }

  let panel = null;
  function togglePanel() {
    if (panel) { panel.remove(); panel = null; return; }
    const { rows, manifests, files } = collect();

    panel = document.createElement('div');
    panel.style.cssText = 'position:fixed;top:16px;right:16px;z-index:2147483647;' +
      'max-width:520px;max-height:70vh;overflow:auto;padding:12px;border-radius:8px;' +
      'background:#1c1c1e;color:#eee;font:12px monospace;box-shadow:0 4px 24px rgba(0,0,0,.6)';

    const title = document.createElement('div');
    title.textContent = `media grab — ${rows.length} element(s), ` +
      `${manifests.length} manifest(s), ${files.length} sniffed file(s)   [Alt+M to close]`;
    title.style.cssText = 'font-weight:bold;margin-bottom:6px';
    panel.appendChild(title);

    for (const r of rows) {
      if (r.blob) {
        // MSE stream: the blob is unreachable; point at the page via yt-dlp
        row(panel, `${r.kind}  blob: (streamed)`, [
          button('copy yt-dlp (page)', function () {
            GM_setClipboard(ytDlpCmd(location.href).replace(` '${location.href}'`, '') +
              ` '${location.href}'`);
            flash(this, 'copied!');
          }),
        ]);
      } else {
        row(panel, `${r.kind}  ${r.src}`, [
          button('download', function () {
            startDownload(r.src, filenameFor(r.src));
            flash(this, 'started…');
          }),
          button('copy url', function () { GM_setClipboard(r.src); flash(this, 'copied!'); }),
        ]);
      }
    }
    for (const m of manifests) {
      row(panel, `manifest  ${m}`, [
        button('copy yt-dlp', function () { GM_setClipboard(ytDlpCmd(m)); flash(this, 'copied!'); }),
        button('copy url', function () { GM_setClipboard(m); flash(this, 'copied!'); }),
      ]);
    }
    for (const f of files) {
      row(panel, `sniffed  ${f}`, [
        button('download', function () {
          startDownload(f, filenameFor(f));
          flash(this, 'started…');
        }),
        button('copy url', function () { GM_setClipboard(f); flash(this, 'copied!'); }),
      ]);
    }
    if (!rows.length && !manifests.length && !files.length) {
      const none = document.createElement('div');
      none.textContent = 'nothing found yet — press play first, then reopen (Alt+M twice)';
      panel.appendChild(none);
    }
    document.body.appendChild(panel);
  }

  window.addEventListener('keydown', (e) => {
    if (HOTKEY(e)) { e.preventDefault(); togglePanel(); }
  }, true);
})();
