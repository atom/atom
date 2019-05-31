const { app, Menu } = require('electron');
const _ = require('underscore-plus');
const MenuHelpers = require('../menu-helpers');

// Used to manage the global application menu.
//
// It's created by {AtomApplication} upon instantiation and used to add, remove
// and maintain the state of all menu items.
module.exports = class ApplicationMenu {
  constructor(version, autoUpdateManager) {
    this.version = version;
    this.autoUpdateManager = autoUpdateManager;
    this.windowTemplates = new WeakMap();
    this.setActiveTemplate(this.getDefaultTemplate());
    this.autoUpdateManager.on('state-changed', state =>
      this.showUpdateMenuItem(state)
    );
  }

  // Public: Updates the entire menu with the given keybindings.
  //
  // window - The BrowserWindow this menu template is associated with.
  // template - The Object which describes the menu to display.
  // keystrokesByCommand - An Object where the keys are commands and the values
  //                       are Arrays containing the keystroke.
  update(window, template, keystrokesByCommand) {
    this.translateTemplate(template, keystrokesByCommand);
    this.substituteVersion(template);
    this.windowTemplates.set(window, template);
    if (window === this.lastFocusedWindow)
      return this.setActiveTemplate(template);
  }

  setActiveTemplate(template) {
    if (!_.isEqual(template, this.activeTemplate)) {
      this.activeTemplate = template;
      this.menu = Menu.buildFromTemplate(_.deepClone(template));
      Menu.setApplicationMenu(this.menu);
    }

    return this.showUpdateMenuItem(this.autoUpdateManager.getState());
  }

  // Register a BrowserWindow with this application menu.
  addWindow(window) {
    if (this.lastFocusedWindow == null) this.lastFocusedWindow = window;

    const focusHandler = () => {
      this.lastFocusedWindow = window;
      const template = this.windowTemplates.get(window);
      if (template) this.setActiveTemplate(template);
    };

    window.on('focus', focusHandler);
    window.once('closed', () => {
      if (window === this.lastFocusedWindow) this.lastFocusedWindow = null;
      this.windowTemplates.delete(window);
      window.removeListener('focus', focusHandler);
    });

    this.enableWindowSpecificItems(true);
  }

  // Flattens the given menu and submenu items into an single Array.
  //
  // menu - A complete menu configuration object for atom-shell's menu API.
  //
  // Returns an Array of native menu items.
  flattenMenuItems(menu) {
    const object = menu.items || {};
    let items = [];
    for (let index in object) {
      const item = object[index];
      items.push(item);
      if (item.submenu)
        items = items.concat(this.flattenMenuItems(item.submenu));
    }
    return items;
  }

  // Flattens the given menu template into an single Array.
  //
  // template - An object describing the menu item.
  //
  // Returns an Array of native menu items.
  flattenMenuTemplate(template) {
    let items = [];
    for (let item of template) {
      items.push(item);
      if (item.submenu)
        items = items.concat(this.flattenMenuTemplate(item.submenu));
    }
    return items;
  }

  // Public: Used to make all window related menu items are active.
  //
  // enable - If true enables all window specific items, if false disables all
  //          window specific items.
  enableWindowSpecificItems(enable) {
    for (let item of this.flattenMenuItems(this.menu)) {
      if (item.metadata && item.metadata.windowSpecific) item.enabled = enable;
    }
  }

  // Replaces VERSION with the current version.
  substituteVersion(template) {
    let item = this.flattenMenuTemplate(template).find(
      ({ label }) => label === 'VERSION'
    );
    if (item) item.label = `Version ${this.version}`;
  }

  // Sets the proper visible state the update menu items
  showUpdateMenuItem(state) {
    const items = this.flattenMenuItems(this.menu);
    const checkForUpdateItem = items.find(
      ({ label }) => label === 'Check for Update'
    );
    const checkingForUpdateItem = items.find(
      ({ label }) => label === 'Checking for Update'
    );
    const downloadingUpdateItem = items.find(
      ({ label }) => label === 'Downloading Update'
    );
    const installUpdateItem = items.find(
      ({ label }) => label === 'Restart and Install Update'
    );

    if (
      !checkForUpdateItem ||
      !checkingForUpdateItem ||
      !downloadingUpdateItem ||
      !installUpdateItem
    )
      return;

    checkForUpdateItem.visible = false;
    checkingForUpdateItem.visible = false;
    downloadingUpdateItem.visible = false;
    installUpdateItem.visible = false;

    switch (state) {
      case 'idle':
      case 'error':
      case 'no-update-available':
        checkForUpdateItem.visible = true;
        break;
      case 'checking':
        checkingForUpdateItem.visible = true;
        break;
      case 'downloading':
        downloadingUpdateItem.visible = true;
        break;
      case 'update-available':
        installUpdateItem.visible = true;
        break;
    }
  }

  // Default list of menu items.
  //
  // Returns an Array of menu item Objects.
  getDefaultTemplate() {
    return [
      {
        label: 'Atom',
        submenu: [
          {
            label: 'Check for Update',
            metadata: { autoUpdate: true }
          },
          {
            label: 'Reload',
            accelerator: 'Command+R',
            click: () => {
              const window = this.focusedWindow();
              if (window) window.reload();
            }
          },
          {
            label: 'Close Window',
            accelerator: 'Command+Shift+W',
            click: () => {
              const window = this.focusedWindow();
              if (window) window.close();
            }
          },
          {
            label: 'Toggle Dev Tools',
            accelerator: 'Command+Alt+I',
            click: () => {
              const window = this.focusedWindow();
              if (window) window.toggleDevTools();
            }
          },
          {
            label: 'Quit',
            accelerator: 'Command+Q',
            click: () => app.quit()
          }
        ]
      }
    ];
  }

  focusedWindow() {
    return global.atomApplication
      .getAllWindows()
      .find(window => window.isFocused());
  }

  // Combines a menu template with the appropriate keystroke.
  //
  // template - An Object conforming to atom-shell's menu api but lacking
  //            accelerator and click properties.
  // keystrokesByCommand - An Object where the keys are commands and the values
  //                       are Arrays containing the keystroke.
  //
  // Returns a complete menu configuration object for atom-shell's menu API.
  translateTemplate(template, keystrokesByCommand) {
    template.forEach(item => {
      if (item.metadata == null) item.metadata = {};
      if (item.command) {
        item.accelerator = this.acceleratorForCommand(
          item.command,
          keystrokesByCommand
        );
        item.click = () =>
          global.atomApplication.sendCommand(item.command, item.commandDetail);
        if (!/^application:/.test(item.command)) {
          item.metadata.windowSpecific = true;
        }
      }
      if (item.submenu)
        this.translateTemplate(item.submenu, keystrokesByCommand);
    });
    return template;
  }

  // Determine the accelerator for a given command.
  //
  // command - The name of the command.
  // keystrokesByCommand - An Object where the keys are commands and the values
  //                       are Arrays containing the keystroke.
  //
  // Returns a String containing the keystroke in a format that can be interpreted
  //   by Electron to provide nice icons where available.
  acceleratorForCommand(command, keystrokesByCommand) {
    const firstKeystroke =
      keystrokesByCommand[command] && keystrokesByCommand[command][0];
    return MenuHelpers.acceleratorForKeystroke(firstKeystroke);
  }
};
