/**
 * @name FullscreenToggle
 * @author programmer2514
 * @authorId 563652755814875146
 * @description A BetterDiscord plugin to easily make Discord fullscreen
 * @version 2.1.2
 * @donate https://ko-fi.com/benjaminpryor
 * @patreon https://www.patreon.com/BenjaminPryor
 * @website https://github.com/programmer2514/BetterDiscord-FullscreenToggle
 * @source https://github.com/programmer2514/BetterDiscord-FullscreenToggle/raw/refs/heads/main/FullscreenToggle.plugin.js
 */

// Abstract settings calls
const settings = {
  get fullscreenElement() { return this._fullscreenElement ?? (this._fullscreenElement = runtime.api.Data.load('fullscreen-element') ?? 'window'); },
  set fullscreenElement(v) { runtime.api.Data.save('fullscreen-element', this._fullscreenElement = v); },

  get fullscreenElementCustom() { return this._fullscreenElementCustom ?? (this._fullscreenElementCustom = runtime.api.Data.load('fullscreen-element-custom') ?? ''); },
  set fullscreenElementCustom(v) { runtime.api.Data.save('fullscreen-element-custom', this._fullscreenElementCustom = v); },

  get fullscreenElementCustomCSS() { return this._fullscreenElementCustomCSS ?? (this._fullscreenElementCustomCSS = runtime.api.Data.load('fullscreen-element-custom-css') ?? ''); },
  set fullscreenElementCustomCSS(v) { runtime.api.Data.save('fullscreen-element-custom-css', this._fullscreenElementCustomCSS = v); },

  get keyboardShortcutEnabled() { return this._keyboardShortcutEnabled ?? (this._keyboardShortcutEnabled = runtime.api.Data.load('keyboard-shortcut-enabled') ?? true); },
  set keyboardShortcutEnabled(v) { runtime.api.Data.save('keyboard-shortcut-enabled', this._keyboardShortcutEnabled = v); },

  get toggled() { return this._toggled ?? (this._toggled = runtime.api.Data.load('toggled') ?? false); },
  set toggled(v) { runtime.api.Data.save('toggled', this._toggled = v); },

  get toggleShortcut() { return this._toggleShortcut ?? (this._toggleShortcut = new Set(runtime.api.Data.load('toggle-shortcut') ?? ['Control', 'f'])); },
  set toggleShortcut(v) {
    runtime.api.Data.save('toggle-shortcut', v);
    this._toggleShortcut = new Set(v);
  },
};

// Define plugin changelog and settings panel layout
const config = {
  changelog: [
    {
      title: '2.1.2',
      type: 'added',
      items: [
        'Fixed plugin crash on Discord startup',
      ],
    },
  ],
  settings: [
    {
      type: 'dropdown',
      id: 'fullscreenElement',
      name: 'Fullscreen Element',
      note: 'The element to make fullscreen',
      get value() { return settings.fullscreenElement; },
      options: [
        {
          label: 'Window (theme-friendly)',
          value: 'window',
        },
        {
          label: 'Inner Window (theme-friendly)',
          value: 'inner-window',
        },
        {
          label: 'Chat/Forum + Members List',
          value: 'chat-members',
        },
        {
          label: 'Chat',
          value: 'chat',
        },
        {
          label: 'Members List',
          value: 'members',
        },
        {
          label: 'Custom',
          value: 'custom',
        },
      ],
    },
    {
      type: 'text',
      id: 'fullscreenElementCustom',
      name: 'Custom Fullscreen Element',
      note: 'A CSS selector specifying the element to make fullscreen. Fullscreen Element must be set to "Custom"',
      placeholder: 'Ex: div.className > span#ID',
      get value() { return settings.fullscreenElementCustom; },
    },
    {
      type: 'text',
      id: 'fullscreenElementCustomCSS',
      name: 'Custom Fullscreen Element Style (CSS)',
      note: 'Custom CSS to be applied only while fullscreen. Fullscreen Element must be set to "Custom"',
      placeholder: 'Ex: div.className > span#ID { min-width: 100% !important; }',
      get value() { return settings.fullscreenElementCustomCSS; },
    },
    {
      type: 'switch',
      id: 'keyboardShortcutEnabled',
      name: 'Keyboard Shortcut Enabled',
      get value() { return settings.keyboardShortcutEnabled; },
    },
    {
      type: 'keybind',
      id: 'toggleShortcut',
      name: 'Toggle Fullscreen - Keyboard Shortcut',
      get value() { return [...settings.toggleShortcut]; },
    },
  ],
};

// Define locale labels
const locale = {
  en: 'Toggle Fullscreen',
  get current() { return this[document.documentElement.getAttribute('lang')] ?? this.en; },
};

// Define icon paths
const icons = {
  enter: '<path fill="currentColor" d="M4 6c0-1.1.9-2 2-2h3a1 1 0 0 0 0-2H6a4 4 0 0 0-4 4v3a1 1 0 0 0 2 0V6ZM4 18c0 1.1.9 2 2 2h3a1 1 0 1 1 0 2H6a4 4 0 0 1-4-4v-3a1 1 0 1 1 2 0v3ZM18 4a2 2 0 0 1 2 2v3a1 1 0 1 0 2 0V6a4 4 0 0 0-4-4h-3a1 1 0 1 0 0 2h3ZM20 18a2 2 0 0 1-2 2h-3a1 1 0 1 0 0 2h3a4 4 0 0 0 4-4v-3a1 1 0 1 0-2 0v3Z"></path>',
  exit: '<path fill="currentColor" d="M8 6a2 2 0 0 1-2 2H3a1 1 0 0 0 0 2h3a4 4 0 0 0 4-4V3a1 1 0 0 0-2 0v3ZM8 18a2 2 0 0 0-2-2H3a1 1 0 1 1 0-2h3a4 4 0 0 1 4 4v3a1 1 0 1 1-2 0v-3ZM18 8a2 2 0 0 1-2-2V3a1 1 0 1 0-2 0v3a4 4 0 0 0 4 4h3a1 1 0 1 0 0-2h-3ZM16 18c0-1.1.9-2 2-2h3a1 1 0 1 0 0-2h-3a4 4 0 0 0-4 4v3a1 1 0 1 0 2 0v-3Z"></path>',
};

// Abstract webpack modules
const modules = {
  get members() { return this._members ?? (this._members = runtime.api.Webpack.getByKeys('membersWrap', 'hiddenMembers', 'roleIcon')); },
  get icons() { return this._icons ?? (this._icons = runtime.api.Webpack.getByKeys('selected', 'iconWrapper', 'clickable', 'icon')); },
  get guilds() { return this._guilds ?? (this._guilds = runtime.api.Webpack.getByKeys('chatContent', 'noChat', 'parentChannelName', 'linkedLobby')); },
  get app() { return this._app ?? (this._app = runtime.api.Webpack.getByKeys('app', 'layers')); },
  get sidebar() { return this._sidebar ?? (this._sidebar = runtime.api.Webpack.getByKeys('sidebar', 'activityPanel', 'sidebarListRounded')); },
  get social() { return this._social ?? (this._social = runtime.api.Webpack.getByKeys('inviteToolbar', 'peopleColumn', 'addFriend')); },
  get panel() { return this._panel ?? (this._panel = runtime.api.Webpack.getByKeys('outer', 'inner', 'overlay')); },
  get game() { return this._game ?? (this._game = runtime.api.Webpack.getByKeys('openOnHover', 'userSection', 'thumbnail')); },
  get effects() { return this._effects ?? (this._effects = runtime.api.Webpack.getByKeys('profileEffects', 'hovered', 'effect')); },
  get threads() { return this._threads ?? (this._threads = runtime.api.Webpack.getByKeys('uploadArea', 'newMemberBanner', 'mainCard', 'newPostsButton')); },
};

// Declare runtime object structure
const runtime = {
  meta: null,
  api: null,
  keys: new Set(),
  lastKeypress: Date.now(),
  button: null,

  // Controls all event listeners
  get controller() {
    if (this._controller && this._controller.signal.aborted) this._controller = null;
    return this._controller ?? (this._controller = new AbortController());
  },
};

// Export plugin class
module.exports = class FullscreenToggle {
  // Get api and metadata
  constructor(meta) {
    runtime.meta = meta;
    runtime.api = new BdApi(runtime.meta.name);
  }

  // Initialize the plugin when it is enabled
  start = () => {
    // Show changelog modal if version has changed
    const savedVersion = runtime.api.Data.load('version');
    if (savedVersion !== runtime.meta.version) {
      runtime.api.UI.showChangelogModal(
        {
          title: runtime.meta.name,
          subtitle: runtime.meta.version,
          blurb: runtime.meta.description,
          changes: config.changelog,
        },
      );
      runtime.api.Data.save('version', runtime.meta.version);
    }

    // Subscribe listeners
    this.addListeners();

    // Add/update fullscreen styling
    this.updateFullscreenStyling();

    // Add root styling
    runtime.api.DOM.addStyle(`${runtime.meta.name}-root`, `
      :root {
        --fst-server-list-collapsed: 0;
      }
    `);

    // Initialize the plugin
    settings.toggled = false;
    this.createToolbarButton();
    runtime.api.Logger.info('Enabled');
  };

  // Restore the default UI when the plugin is disabled
  stop = () => {
    // Unsubscribe listeners
    runtime.controller.abort();

    // Exit fullscreen
    document.exitFullscreen();

    // Update/remove fullscreen styling
    this.updateFullscreenStyling();

    // Remove root styling
    runtime.api.DOM.removeStyle(`${runtime.meta.name}-root`);

    // Terminate the plugin
    runtime.button.remove();
    runtime.api.Logger.info('Disabled');
  };

  // Re-inject the toolbar button when the page changes
  onSwitch = () => { this.createToolbarButton(); };

  // Build settings panel
  getSettingsPanel = () => {
    return runtime.api.UI.buildSettingsPanel(
      {
        settings: config.settings,
        onChange: (_, id, value) => {
          settings[id] = value;

          this.stop();
          this.start();
        },
      },
    );
  };

  // Create a functional toolbar button
  createToolbarButton = () => {
    // If toolbar doesn't exist, wait
    if (!document.querySelector(`.${modules.icons?.toolbar}`)) {
      setTimeout(() => this.createToolbarButton(), 250);
      return;
    }

    // Get button text
    let text = locale.current + ' (' + [...settings.toggleShortcut].map(e => (e.length === 1 ? e.toUpperCase() : e)).join('+') + ')';

    // Create button and add it to the toolbar
    let button = BdApi.DOM.parseHTML(`
      <div id="fst-button" class="${modules.icons?.iconWrapper} ${modules.icons?.clickable}" role="button" aria-label="${text}" tabindex="0">
        <svg x="0" y="0" class="${modules.icons?.icon}" aria-hidden="false" role="img" xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24">
          ${(settings.toggled) ? icons.exit : icons.enter}
        </svg>
      </div>
    `, true);
    document.querySelector(`.${modules.icons?.toolbar}`)?.appendChild(button);

    // Remove old button and get new one
    runtime.button?.remove();
    runtime.button = document.querySelector(`#fst-button`);

    // Add tooltip and click handler
    if (runtime.button) {
      runtime.api.UI.createTooltip(runtime.button, text, { side: 'left' });
      runtime.button.addEventListener('click', () => this.toggleFullscreen());
    }
  };

  // Add event listeners to handle resize/expand on hover
  addListeners = () => {
    document.body.addEventListener('keydown', (e) => {
      // Handle keyboard shortcuts
      if (settings.keyboardShortcutEnabled) {
        // Clear old logged keypresses if necessary
        if (Date.now() - runtime.lastKeypress > 1000)
          runtime.keys.clear();
        runtime.lastKeypress = Date.now();

        // Log keypress
        runtime.keys.add(e.key);
        if (runtime.keys.symmetricDifference(settings.toggleShortcut).size === 0)
          this.toggleFullscreen();
      }
    }, { passive: true, signal: runtime.controller.signal });

    document.body.addEventListener('keyup', (e) => {
      // Delete logged keypress
      if (settings.keyboardShortcutEnabled)
        runtime.keys.delete(e.key);
    }, { passive: true, signal: runtime.controller.signal });

    this.getFullscreenElement()?.addEventListener('fullscreenchange', () => {
      if ((document.fullscreenElement && !settings.toggled) || (!document.fullscreenElement && settings.toggled)) {
        settings.toggled = !settings.toggled;
        if (runtime.button) runtime.button.querySelector(`svg`).innerHTML = (settings.toggled) ? icons.exit : icons.enter;
        this.updateFullscreenStyling();
      }
    }, { passive: true, signal: runtime.controller.signal });
  };

  // Toggles the fullscreen button
  toggleFullscreen = () => {
    if (this.getFullscreenElement()) {
      if (!settings.toggled) {
        this.getFullscreenElement()?.requestFullscreen()?.then(this.updateFullscreenStyling);
      }
      else if (document.fullscreenElement) {
        document.exitFullscreen()?.then(this.updateFullscreenStyling);
      }
    }
  };

  // Get the element to make fullscreen
  getFullscreenElement = () => {
    switch (settings.fullscreenElement) {
      case 'chat-members':
        return document.querySelector(`.${modules.guilds?.chat}`) ?? document.querySelector(`.${modules.social?.container}`);
      case 'chat':
        return document.querySelector(`.${modules.guilds?.chatContent}`) ?? document.querySelector(`.${modules.threads?.container}`) ?? document.querySelector(`.${modules.social?.peopleColumn}`);
      case 'members':
        return document.querySelector(`.${modules.members?.membersWrap}`) ?? document.querySelector(`.${modules.panel?.outer}`) ?? document.querySelector(`.${modules.social?.nowPlayingColumn}`);
      case 'custom':
        if (settings.fullscreenElementCustom) return document.querySelector(`${settings.fullscreenElementCustom}`);
        else return null;
      default:
        return document.body;
    }
  };

  // Update the necessary styling to make fullscreen elements look good
  updateFullscreenStyling = () => {
    if (document.fullscreenElement) {
      switch (settings.fullscreenElement) {
        case 'window':
          runtime.api.DOM.addStyle(runtime.meta.name, `
            .${modules.sidebar?.base} {
              --custom-app-top-bar-height: 0;
            }

            ${(runtime.api.Themes.isEnabled('Translucence'))
              ? `
                .${modules.app?.layers} {
                  margin-top: var(--app-margin) !important;
                }
              `
              : ''}
          `);
          return;
        case 'inner-window':
          runtime.api.DOM.addStyle(runtime.meta.name, `
            .${modules.sidebar?.base} {
              --custom-app-top-bar-height: 0;
            }

            .${modules.sidebar?.panels} {
              --fst-server-list-collapsed: 1;
            }

            .${modules.sidebar?.guilds} {
              display: none !important;
            }

            .${modules.sidebar?.sidebarList} {
              border-radius: 0 !important;
            }

            ${(runtime.api.Themes.isEnabled('Translucence'))
              ? `
                .${modules.app?.layers} {
                  margin-top: var(--app-margin) !important;
                }
              `
              : ''}
          `);
          return;
        case 'chat':
          runtime.api.DOM.addStyle(runtime.meta.name, `
            .${modules.social?.peopleColumn} {
              background-color: var(--bg-overlay-chat, var(--background-base-lower));
            }
          `);
          return;
        case 'members':
          if (document.querySelector(`.${modules.panel?.outer} header > svg`)) document.querySelector(`.${modules.panel?.outer} header > svg`).style.maxHeight = document.querySelector(`.${modules.panel?.outer} header > svg`).style.minHeight;
          document.querySelector(`.${modules.panel?.outer} header > svg > mask > rect`)?.setAttribute('width', '500%');
          document.querySelector(`.${modules.panel?.outer} header > svg`)?.removeAttribute('viewBox');
          runtime.api.DOM.addStyle(runtime.meta.name, `
            .${modules.members?.membersWrap},
            .${modules.members?.membersWrap} > *,
            .${modules.guilds?.content} .${modules.panel?.outer} > * {
              width: 100% !important;
            }

            .${modules.members?.member},
            .${modules.game?.container} {
              max-width: 100% !important;
            }

            .${modules.guilds?.content} .${modules.panel?.outer} header > svg {
              min-width: 100% !important;
            }

            .${modules.guilds?.content} .${modules.panel?.outer} header > svg > mask > rect {
              width: 500% !important;
            }

            .${modules.guilds?.content} .${modules.panel?.outer} .${modules.effects?.effect} {
              min-height: 100% !important;
            }

            .${modules.social?.nowPlayingColumn} {
              display: initial !important;
            }
          `);
          return;
        case 'custom':
          runtime.api.DOM.addStyle(runtime.meta.name, settings.fullscreenElementCustomCSS);
          return;
        default:
          return;
      }
    }
    else {
      runtime.api.DOM.removeStyle(runtime.meta.name);
      document.querySelector(`.${modules.guilds?.content} .${modules.panel?.outer} header > svg`)?.style.removeProperty('max-height');
      document.querySelector(`.${modules.guilds?.content} .${modules.panel?.outer} header > svg > mask > rect`)?.setAttribute('width', '100%');
      document.querySelector(`.${modules.guilds?.content} .${modules.panel?.outer} header > svg`)?.setAttribute('viewBox', `0 0 ${parseInt(document.querySelector(`.${modules.panel?.outer} header > svg`)?.style.minWidth)} ${parseInt(document.querySelector(`.${modules.panel?.outer} header > svg`)?.style.minHeight)}`);
    }
  };
};
