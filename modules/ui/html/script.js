// clp_framework — UI Renderer (Phase 4)
//
// Empfaengt NUI-Messages vom Lua-Client und rendert:
//   - notify        Toast-Stack (top-right)
//   - progress      Bottom-Center-Bar
//   - menu:open/close   rechter Menu-Stack mit Keyboard-Nav
//   - input:open/close  zentriertes Modal
//   - charselect:show/hide  Vollbild-Char-Auswahl
//
// Sendet ueber fetch(`https://${RESOURCE}/<callback>`) Daten zurueck an Lua.

(function () {
  'use strict';

  const RESOURCE = (window.GetParentResourceName && GetParentResourceName()) || 'clp_framework';

  function log(...args) { console.log('[clp_ui]', ...args); }

  function post(name, body) {
    return fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {}),
    }).catch(err => console.warn('[clp_ui] post fail', name, err));
  }

  function $(sel) { return document.querySelector(sel); }
  function $$(sel) { return Array.from(document.querySelectorAll(sel)); }

  function el(tag, opts = {}, children = []) {
    const e = document.createElement(tag);
    if (opts.className) e.className = opts.className;
    if (opts.text) e.textContent = opts.text;
    if (opts.html) e.innerHTML = opts.html;
    if (opts.attrs) for (const [k, v] of Object.entries(opts.attrs)) e.setAttribute(k, v);
    if (opts.dataset) for (const [k, v] of Object.entries(opts.dataset)) e.dataset[k] = v;
    if (opts.on) for (const [k, v] of Object.entries(opts.on)) e.addEventListener(k, v);
    for (const c of (Array.isArray(children) ? children : [children])) {
      if (c == null) continue;
      e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    }
    return e;
  }

  // ============================================================
  //  NOTIFY
  // ============================================================
  const ICONS = { info: 'i', success: '✓', warning: '!', error: '×' };

  function notify({ message, type, duration }) {
    if (!message) return;
    const t = ['info', 'success', 'warning', 'error'].includes(type) ? type : 'info';
    const stack = $('#clp-notify-stack');
    const node = el('div', { className: `clp-notify clp-notify--${t}` }, [
      el('div', { className: 'clp-notify__icon', text: ICONS[t] || 'i' }),
      el('div', { className: 'clp-notify__msg', text: String(message) }),
    ]);
    stack.appendChild(node);
    const d = Math.max(800, Math.min(20000, Number(duration) || 4000));
    setTimeout(() => {
      node.classList.add('is-leaving');
      setTimeout(() => node.remove(), 220);
    }, d);
  }

  // ============================================================
  //  PROGRESS
  // ============================================================
  let progressState = null;

  function progressStart({ key, label, duration, canCancel }) {
    progressCancel({ key: 'all' }); // nur ein progress gleichzeitig
    const stack = $('#clp-progress-stack');
    const fill = el('div', { className: 'clp-progress__fill' });
    const hint = canCancel ? el('div', { className: 'clp-progress__hint', text: 'X zum Abbrechen' }) : null;
    const node = el('div', { className: 'clp-progress', dataset: { key: key || 'default' } }, [
      el('div', { className: 'clp-progress__label', text: String(label || 'Bitte warten') }),
      el('div', { className: 'clp-progress__bar' }, [fill]),
      hint,
    ]);
    stack.appendChild(node);

    const started = performance.now();
    const dur = Math.max(100, Number(duration) || 3000);
    progressState = { node, fill, started, duration: dur, key: key || 'default', cancelled: false };

    function tick() {
      if (!progressState || progressState.node !== node) return;
      const elapsed = performance.now() - progressState.started;
      const pct = Math.min(100, (elapsed / progressState.duration) * 100);
      fill.style.width = pct + '%';
      if (pct >= 100) {
        node.remove();
        post('progress:done', { key: progressState.key, cancelled: false });
        progressState = null;
      } else {
        requestAnimationFrame(tick);
      }
    }
    requestAnimationFrame(tick);
  }

  function progressCancel({ key }) {
    if (!progressState) return;
    if (key && key !== 'all' && progressState.key !== key) return;
    const wasKey = progressState.key;
    progressState.cancelled = true;
    progressState.node.remove();
    progressState = null;
    post('progress:done', { key: wasKey, cancelled: true });
  }

  // ============================================================
  //  MENU
  //  Stack: mehrere Menus moeglich, oben aktiver. Keyboard-Nav.
  // ============================================================
  const menus = []; // [{ id, node, items, active }]

  function getTop() { return menus[menus.length - 1]; }

  function menuOpen({ menu }) {
    if (!menu || !Array.isArray(menu.items)) return;
    const id = menu.id || ('menu_' + Date.now());
    const stack = $('#clp-menu-stack');

    const list = el('div', { className: 'clp-menu__list' });
    const itemNodes = [];
    menu.items.forEach((item, idx) => {
      const node = el('div', {
        className: 'clp-menu__item' + (item.disabled ? ' is-disabled' : ''),
        dataset: { idx: String(idx) },
        on: {
          click: () => { if (!item.disabled) selectItem(id, idx); },
          mouseenter: () => setActive(id, idx),
        },
      }, [
        item.icon ? el('div', { className: 'clp-menu__icon', text: item.icon }) : null,
        el('div', { className: 'clp-menu__label' }, [
          el('div', { text: String(item.label || ('Item ' + idx)) }),
          item.description ? el('div', { className: 'clp-menu__desc', text: String(item.description) }) : null,
        ]),
      ]);
      itemNodes.push(node);
      list.appendChild(node);
    });

    const node = el('div', { className: 'clp-menu', dataset: { id } }, [
      el('div', { className: 'clp-menu__header' }, [
        el('div', { className: 'clp-menu__title', text: String(menu.title || 'Menu') }),
        menu.subtitle ? el('div', { className: 'clp-menu__subtitle', text: String(menu.subtitle) }) : null,
      ]),
      list,
      el('div', { className: 'clp-menu__hint', text: '↑↓ Navigieren | Enter Bestaetigen | Esc Schliessen' }),
    ]);
    stack.appendChild(node);
    menus.push({ id, node, items: menu.items, itemNodes, active: 0 });
    setActive(id, 0);
  }

  function setActive(menuId, idx) {
    const m = menus.find(x => x.id === menuId);
    if (!m) return;
    idx = Math.max(0, Math.min(m.items.length - 1, idx));
    while (m.items[idx] && m.items[idx].disabled) {
      idx = (idx + 1) % m.items.length;
      if (idx === m.active) break;
    }
    m.active = idx;
    m.itemNodes.forEach((n, i) => n.classList.toggle('is-active', i === idx));
    const node = m.itemNodes[idx];
    if (node && node.scrollIntoView) node.scrollIntoView({ block: 'nearest' });
  }

  function selectItem(menuId, idx) {
    const m = menus.find(x => x.id === menuId);
    if (!m) return;
    const item = m.items[idx];
    if (!item || item.disabled) return;
    post('menu:select', { id: menuId, idx, action: item.action, payload: item.payload || null });
  }

  function menuClose({ id }) {
    if (id) {
      const i = menus.findIndex(m => m.id === id);
      if (i >= 0) { menus[i].node.remove(); menus.splice(i, 1); }
    } else if (menus.length) {
      const top = menus.pop();
      top.node.remove();
    }
  }

  function menuCloseAll() {
    while (menus.length) { menus.pop().node.remove(); }
  }

  // Tastatursteuerung fuer das oberste Menu
  document.addEventListener('keydown', (ev) => {
    const top = getTop();
    if (top) {
      switch (ev.key) {
        case 'ArrowDown': ev.preventDefault(); setActive(top.id, top.active + 1); return;
        case 'ArrowUp':   ev.preventDefault(); setActive(top.id, top.active - 1); return;
        case 'Enter':
        case ' ':         ev.preventDefault(); selectItem(top.id, top.active); return;
        case 'Backspace': ev.preventDefault(); post('menu:back', { id: top.id }); return;
        case 'Escape':    ev.preventDefault(); post('menu:close', { id: top.id }); return;
      }
    }
    // Progress-Cancel (X)
    if ((ev.key === 'x' || ev.key === 'X') && progressState && !progressState.cancelled) {
      const node = progressState.node;
      if (node.querySelector('.clp-progress__hint')) {
        progressCancel({ key: progressState.key });
      }
    }
    // Input-Modal Escape
    if (ev.key === 'Escape' && inputOpen) {
      inputCancel();
    }
  });

  // ============================================================
  //  INPUT-MODAL
  // ============================================================
  let inputOpen = false;
  let inputNode = null;

  function openInput({ id, title, fields, submitLabel, cancelLabel }) {
    closeInput();
    inputOpen = true;
    const fieldNodes = (fields || []).map((f, idx) => {
      let inputEl;
      const inputId = `clp-i-${idx}`;
      if (f.type === 'select') {
        inputEl = el('select', { attrs: { id: inputId } },
          (f.options || []).map(o => el('option', { attrs: { value: o.value }, text: o.label || o.value })));
        if (f.value != null) inputEl.value = String(f.value);
      } else if (f.type === 'textarea') {
        inputEl = el('textarea', { attrs: { id: inputId, rows: f.rows || 3, placeholder: f.placeholder || '' } });
        if (f.value != null) inputEl.value = String(f.value);
      } else {
        inputEl = el('input', {
          attrs: {
            id: inputId,
            type: f.type || 'text',
            placeholder: f.placeholder || '',
            maxlength: String(f.maxLength || 256),
          },
        });
        if (f.value != null) inputEl.value = String(f.value);
      }
      inputEl.dataset.name = f.name || ('field_' + idx);
      return el('div', { className: 'clp-input__field' }, [
        el('label', { attrs: { for: inputId }, text: String(f.label || f.name || '') }),
        inputEl,
      ]);
    });

    const submitBtn = el('button', {
      className: 'clp-btn clp-btn--primary',
      text: submitLabel || 'OK',
      on: { click: () => submitInput(id, fieldNodes) },
    });
    const cancelBtn = el('button', {
      className: 'clp-btn clp-btn--ghost',
      text: cancelLabel || 'Abbrechen',
      on: { click: () => inputCancel(id) },
    });

    inputNode = el('div', { className: 'clp-input', dataset: { id: id || '' } }, [
      el('div', { className: 'clp-input__title', text: String(title || 'Eingabe') }),
      ...fieldNodes,
      el('div', { className: 'clp-input__buttons' }, [cancelBtn, submitBtn]),
    ]);
    $('#clp-input-stack').appendChild(inputNode);

    setTimeout(() => {
      const first = inputNode.querySelector('input, textarea, select');
      if (first) first.focus();
    }, 30);
  }

  function submitInput(id, fieldNodes) {
    if (!inputNode) return;
    const values = {};
    fieldNodes.forEach(wrapper => {
      const f = wrapper.querySelector('input, textarea, select');
      if (f) values[f.dataset.name] = f.value;
    });
    post('input:submit', { id, values });
    closeInput();
  }

  function inputCancel(id) {
    post('input:cancel', { id: id || '' });
    closeInput();
  }

  function closeInput() {
    inputOpen = false;
    if (inputNode) { inputNode.remove(); inputNode = null; }
  }

  // ============================================================
  //  CHAR-SELECT
  // ============================================================
  let charSelectOpen = false;
  let cachedMaxChars = 3;

  function charSelectShow({ chars, maxChars }) {
    cachedMaxChars = Number(maxChars) || 3;
    const root = $('#clp-charselect');
    const list = $('#clp-charselect-list');
    list.innerHTML = '';

    const usedSlots = new Set();
    (chars || []).forEach(c => usedSlots.add(Number(c.slot) || 0));

    (chars || []).forEach(c => list.appendChild(buildCharCard(c)));

    // Empty-Slot-Cards
    for (let s = 1; s <= cachedMaxChars; s++) {
      if (usedSlots.has(s)) continue;
      list.appendChild(buildEmptySlot(s));
    }

    root.classList.remove('hidden');
    charSelectOpen = true;
  }

  function charSelectHide() {
    $('#clp-charselect').classList.add('hidden');
    $('#clp-charcreate').classList.add('hidden');
    charSelectOpen = false;
  }

  function buildCharCard(c) {
    const fullName = `${c.firstname || ''} ${c.lastname || ''}`.trim() || '(Unbekannt)';
    const card = el('div', { className: 'clp-charcard', dataset: { cid: String(c.citizenid) } }, [
      el('div', { className: 'clp-charcard__slot', text: 'Slot ' + (c.slot || '?') }),
      el('div', { className: 'clp-charcard__name', text: fullName }),
      el('div', { className: 'clp-charcard__cid', text: c.citizenid || '-' }),
      el('div', { className: 'clp-charcard__row' }, [el('span', { text: 'Bank' }), el('strong', { text: '$' + (c.bank || 0) })]),
      el('div', { className: 'clp-charcard__row' }, [el('span', { text: 'Cash' }), el('strong', { text: '$' + (c.cash || 0) })]),
      el('div', { className: 'clp-charcard__row' }, [el('span', { text: 'Job' }), el('strong', { text: (c.job || '-') + (c.job_grade != null ? (' / ' + c.job_grade) : '') })]),
      el('div', { className: 'clp-charcard__actions' }, [
        el('button', {
          className: 'clp-btn clp-btn--primary',
          text: 'Spielen',
          on: { click: (ev) => { ev.stopPropagation(); post('char:select', { citizenid: c.citizenid }); } },
        }),
        el('button', {
          className: 'clp-btn clp-btn--danger',
          text: 'Loeschen',
          on: { click: (ev) => {
            ev.stopPropagation();
            if (confirm(`Charakter "${fullName}" wirklich loeschen?`)) {
              post('char:delete', { citizenid: c.citizenid });
            }
          } },
        }),
      ]),
    ]);
    card.addEventListener('click', () => post('char:select', { citizenid: c.citizenid }));
    return card;
  }

  function buildEmptySlot(slot) {
    const card = el('div', { className: 'clp-charcard clp-charcard--empty', dataset: { slot: String(slot) } }, [
      el('div', { text: `+ Neuen Charakter in Slot ${slot} erstellen` }),
    ]);
    card.addEventListener('click', () => openCharCreate(slot));
    return card;
  }

  function openCharCreate(slot) {
    const modal = $('#clp-charcreate');
    modal.classList.remove('hidden');
    modal.dataset.slot = String(slot || 1);
    setTimeout(() => $('#clp-cc-firstname').focus(), 30);
  }

  function closeCharCreate() {
    $('#clp-charcreate').classList.add('hidden');
    ['firstname', 'lastname', 'birthdate'].forEach(n => { const el = $('#clp-cc-' + n); if (el) el.value = ''; });
    $('#clp-cc-gender').value = 'm';
  }

  function submitCharCreate() {
    const data = {
      slot:      Number($('#clp-charcreate').dataset.slot) || 1,
      firstname: $('#clp-cc-firstname').value.trim(),
      lastname:  $('#clp-cc-lastname').value.trim(),
      gender:    $('#clp-cc-gender').value,
      birthdate: $('#clp-cc-birthdate').value || null,
    };
    if (!data.firstname || !data.lastname) {
      notify({ message: 'Vor- und Nachname sind Pflicht', type: 'warning', duration: 3500 });
      return;
    }
    post('char:create', data);
    closeCharCreate();
  }

  // Char-Create Buttons
  document.addEventListener('DOMContentLoaded', () => {
    $('#clp-charselect-newbtn').addEventListener('click', () => openCharCreate(1));
    $('#clp-cc-cancel').addEventListener('click', closeCharCreate);
    $('#clp-cc-submit').addEventListener('click', submitCharCreate);
  });

  // ============================================================
  //  NUI-MESSAGE-DISPATCHER
  // ============================================================
  window.addEventListener('message', function (event) {
    const data = event.data || {};
    if (!data.action) return;
    switch (data.action) {
      case 'notify':            notify(data); break;
      case 'progress':          progressStart(data); break;
      case 'progress:start':    progressStart(data); break;
      case 'progress:cancel':   progressCancel(data); break;
      case 'menu:open':         menuOpen(data); break;
      case 'menu:close':        menuClose(data); break;
      case 'menu:closeAll':     menuCloseAll(); break;
      case 'menu:setActive':    setActive(data.id, Number(data.idx) || 0); break;
      case 'input:open':        openInput(data); break;
      case 'input:close':       closeInput(); break;
      case 'charselect:show':   charSelectShow(data); break;
      case 'charselect:hide':   charSelectHide(); break;
      default:                  log('unknown action', data.action, data);
    }
  });

  log('ready');
})();
