/* PVJ site behaviour. No dependencies, no tracking, no cookies. */
(function () {
  'use strict';

  // ---- mobile navigation ----
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.getElementById('site-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  // ---- click-to-load YouTube player ----
  // Nothing is requested from YouTube's player until the visitor presses play.
  document.querySelectorAll('.player[data-yt]').forEach(function (box) {
    var btn = box.querySelector('button');
    if (!btn) return;
    btn.addEventListener('click', function () {
      var frame = document.createElement('iframe');
      frame.src = 'https://www.youtube-nocookie.com/embed/' + encodeURIComponent(box.getAttribute('data-yt')) + '?autoplay=1&rel=0&modestbranding=1';
      frame.title = box.getAttribute('data-title') || 'Video player';
      frame.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
      frame.allowFullscreen = true;
      frame.referrerPolicy = 'strict-origin-when-cross-origin';
      box.innerHTML = '';
      box.appendChild(frame);
    });
  });

  // ---- copy link ----
  document.querySelectorAll('[data-copy]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var url = btn.getAttribute('data-copy') || window.location.href;
      var done = function () {
        var old = btn.textContent;
        btn.textContent = 'Link copied';
        setTimeout(function () { btn.textContent = old; }, 1800);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(url).then(done, function () { window.prompt('Copy this link', url); });
      } else {
        window.prompt('Copy this link', url);
      }
    });
  });

  // ---- library filters (videos page, speakers page) ----
  var list = document.querySelector('[data-filter-list]');
  if (list) {
    var items = Array.prototype.slice.call(list.querySelectorAll('[data-search]'));
    var q = document.getElementById('f-q');
    var conf = document.getElementById('f-conference');
    var topic = document.getElementById('f-topic');
    var status = document.getElementById('f-status');
    var empty = document.getElementById('f-empty');
    var noun = list.getAttribute('data-noun') || 'item';
    var groups = Array.prototype.slice.call(document.querySelectorAll('[data-filter-group]'));

    var params = new URLSearchParams(window.location.search);
    if (q && params.get('q')) q.value = params.get('q');
    if (conf && params.get('conference')) conf.value = params.get('conference');
    if (topic && params.get('topic')) topic.value = params.get('topic');

    var apply = function () {
      var terms = (q && q.value ? q.value : '').toLowerCase().split(/\s+/).filter(Boolean);
      var c = conf ? conf.value : '';
      var t = topic ? topic.value : '';
      var shown = 0;
      items.forEach(function (el) {
        var hay = el.getAttribute('data-search') || '';
        var ok = terms.every(function (term) { return hay.indexOf(term) !== -1; });
        if (ok && c) ok = el.getAttribute('data-conference') === c;
        if (ok && t) ok = (' ' + (el.getAttribute('data-topics') || '') + ' ').indexOf(' ' + t + ' ') !== -1;
        el.hidden = !ok;
        if (ok) shown++;
      });
      groups.forEach(function (g) {
        g.hidden = !g.querySelector('[data-search]:not([hidden])');
      });
      var active = terms.length > 0 || !!c || !!t;
      if (status) {
        status.firstChild.textContent = shown + ' ' + noun + (shown === 1 ? '' : 's') + (active ? ' match your filters' : '');
        var reset = status.querySelector('button');
        if (reset) reset.hidden = !active;
      }
      if (empty) empty.style.display = shown === 0 ? 'block' : 'none';

      var next = new URLSearchParams();
      if (q && q.value.trim()) next.set('q', q.value.trim());
      if (c) next.set('conference', c);
      if (t) next.set('topic', t);
      var qs = next.toString();
      window.history.replaceState(null, '', window.location.pathname + (qs ? '?' + qs : ''));
    };

    [q, conf, topic].forEach(function (el) {
      if (!el) return;
      el.addEventListener('input', apply);
      el.addEventListener('change', apply);
    });
    if (status) {
      var resetBtn = status.querySelector('button');
      if (resetBtn) {
        resetBtn.addEventListener('click', function () {
          if (q) q.value = '';
          if (conf) conf.value = '';
          if (topic) topic.value = '';
          apply();
        });
      }
    }
    apply();
  }
})();
