// clp_framework — UI Renderer (Phase 0: skeleton)
//
// Hört auf NUI-Messages vom Lua-Client und rendert Notify / Menu / Progress /
// Input in den jeweiligen Stacks. Phase 0 implementiert nur den NUI-Listener
// und ein simples console.log — der echte Rendering-Code kommt in Phase 4.

(function () {
  'use strict';

  function log(...args) { console.log('[clp_ui]', ...args); }

  window.addEventListener('message', function (event) {
    const data = event.data || {};
    if (!data || !data.action) return;

    switch (data.action) {
      case 'notify':
        // TODO Phase 4: render notify in #clp-notify-stack
        log('notify', data);
        break;
      case 'progress':
        log('progress', data);
        break;
      case 'menu:open':
      case 'menu:close':
        log(data.action, data);
        break;
      case 'input:open':
      case 'input:close':
        log(data.action, data);
        break;
      default:
        log('unknown action', data.action, data);
    }
  });

  log('ready');
})();
