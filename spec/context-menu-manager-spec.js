const ContextMenuManager = require('../src/context-menu-manager');

describe('ContextMenuManager', function() {
  let [contextMenu, parent, child, grandchild] = [];

  beforeEach(function() {
    const { resourcePath } = atom.getLoadSettings();
    contextMenu = new ContextMenuManager({ keymapManager: atom.keymaps });
    contextMenu.initialize({ resourcePath });

    parent = document.createElement('div');
    child = document.createElement('div');
    grandchild = document.createElement('div');
    parent.tabIndex = -1;
    child.tabIndex = -1;
    grandchild.tabIndex = -1;
    parent.classList.add('parent');
    child.classList.add('child');
    grandchild.classList.add('grandchild');
    child.appendChild(grandchild);
    parent.appendChild(child);

    document.body.appendChild(parent);
  });

  afterEach(function() {
    document.body.blur();
    document.body.removeChild(parent);
  });

  describe('::add(itemsBySelector)', function() {
    it('can add top-level menu items that can be removed with the returned disposable', function() {
      const disposable = contextMenu.add({
        '.parent': [{ label: 'A', command: 'a' }],
        '.child': [{ label: 'B', command: 'b' }],
        '.grandchild': [{ label: 'C', command: 'c' }]
      });

      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'C', id: 'C', command: 'c' },
        { label: 'B', id: 'B', command: 'b' },
        { label: 'A', id: 'A', command: 'a' }
      ]);

      disposable.dispose();
      expect(contextMenu.templateForElement(grandchild)).toEqual([]);
    });

    it('can add submenu items to existing menus that can be removed with the returned disposable', function() {
      const disposable1 = contextMenu.add({
        '.grandchild': [{ label: 'A', submenu: [{ label: 'B', command: 'b' }] }]
      });
      const disposable2 = contextMenu.add({
        '.grandchild': [{ label: 'A', submenu: [{ label: 'C', command: 'c' }] }]
      });

      expect(contextMenu.templateForElement(grandchild)).toEqual([
        {
          label: 'A',
          id: 'A',
          submenu: [
            { label: 'B', id: 'B', command: 'b' },
            { label: 'C', id: 'C', command: 'c' }
          ]
        }
      ]);

      disposable2.dispose();
      expect(contextMenu.templateForElement(grandchild)).toEqual([
        {
          label: 'A',
          id: 'A',
          submenu: [{ label: 'B', id: 'B', command: 'b' }]
        }
      ]);

      disposable1.dispose();
      expect(contextMenu.templateForElement(grandchild)).toEqual([]);
    });

    it('favors the most specific / recently added item in the case of a duplicate label', function() {
      grandchild.classList.add('foo');

      const disposable1 = contextMenu.add({
        '.grandchild': [{ label: 'A', command: 'a' }]
      });
      const disposable2 = contextMenu.add({
        '.grandchild.foo': [{ label: 'A', command: 'b' }]
      });
      const disposable3 = contextMenu.add({
        '.grandchild': [{ label: 'A', command: 'c' }]
      });

      contextMenu.add({
        '.child': [{ label: 'A', command: 'd' }]
      });

      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'A', id: 'A', command: 'b' }
      ]);

      disposable2.dispose();
      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'A', id: 'A', command: 'c' }
      ]);

      disposable3.dispose();
      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'A', id: 'A', command: 'a' }
      ]);

      disposable1.dispose();
      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'A', id: 'A', command: 'd' }
      ]);
    });

    it('allows multiple separators, but not adjacent to each other', function() {
      contextMenu.add({
        '.grandchild': [
          { label: 'A', command: 'a' },
          { type: 'separator' },
          { type: 'separator' },
          { label: 'B', command: 'b' },
          { type: 'separator' },
          { type: 'separator' },
          { label: 'C', command: 'c' }
        ]
      });

      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'A', id: 'A', command: 'a' },
        { type: 'separator' },
        { label: 'B', id: 'B', command: 'b' },
        { type: 'separator' },
        { label: 'C', id: 'C', command: 'c' }
      ]);
    });

    it('excludes items marked for display in devMode unless in dev mode', function() {
      contextMenu.add({
        '.grandchild': [
          { label: 'A', command: 'a', devMode: true },
          { label: 'B', command: 'b', devMode: false }
        ]
      });

      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'B', id: 'B', command: 'b' }
      ]);

      contextMenu.devMode = true;
      expect(contextMenu.templateForElement(grandchild)).toEqual([
        { label: 'A', id: 'A', command: 'a' },
        { label: 'B', id: 'B', command: 'b' }
      ]);
    });

    it('allows items to be associated with `created` hooks which are invoked on template construction with the item and event', function() {
      let createdEvent = null;

      const item = {
        label: 'A',
        command: 'a',
        created(event) {
          this.command = 'b';
          createdEvent = event;
        }
      };

      contextMenu.add({ '.grandchild': [item] });

      const dispatchedEvent = { target: grandchild };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        { label: 'A', id: 'A', command: 'b' }
      ]);
      expect(item.command).toBe('a'); // doesn't modify original item template
      expect(createdEvent).toBe(dispatchedEvent);
    });

    it('allows items to be associated with `shouldDisplay` hooks which are invoked on construction to determine whether the item should be included', function() {
      let shouldDisplayEvent = null;
      let shouldDisplay = true;

      const item = {
        label: 'A',
        command: 'a',
        shouldDisplay(event) {
          this.foo = 'bar';
          shouldDisplayEvent = event;
          return shouldDisplay;
        }
      };
      contextMenu.add({ '.grandchild': [item] });

      const dispatchedEvent = { target: grandchild };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        { label: 'A', id: 'A', command: 'a' }
      ]);
      expect(item.foo).toBeUndefined(); // doesn't modify original item template
      expect(shouldDisplayEvent).toBe(dispatchedEvent);

      shouldDisplay = false;
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([]);
    });

    it('prunes a trailing separator', function() {
      contextMenu.add({
        '.grandchild': [
          { label: 'A', command: 'a' },
          { type: 'separator' },
          { label: 'B', command: 'b' },
          { type: 'separator' }
        ]
      });

      expect(contextMenu.templateForEvent({ target: grandchild }).length).toBe(
        3
      );
    });

    it('prunes a leading separator', function() {
      contextMenu.add({
        '.grandchild': [
          { type: 'separator' },
          { label: 'A', command: 'a' },
          { type: 'separator' },
          { label: 'B', command: 'b' }
        ]
      });

      expect(contextMenu.templateForEvent({ target: grandchild }).length).toBe(
        3
      );
    });

    it('prunes duplicate separators', function() {
      contextMenu.add({
        '.grandchild': [
          { label: 'A', command: 'a' },
          { type: 'separator' },
          { type: 'separator' },
          { label: 'B', command: 'b' }
        ]
      });

      expect(contextMenu.templateForEvent({ target: grandchild }).length).toBe(
        3
      );
    });

    it('prunes all redundant separators', function() {
      contextMenu.add({
        '.grandchild': [
          { type: 'separator' },
          { type: 'separator' },
          { label: 'A', command: 'a' },
          { type: 'separator' },
          { type: 'separator' },
          { label: 'B', command: 'b' },
          { label: 'C', command: 'c' },
          { type: 'separator' },
          { type: 'separator' }
        ]
      });

      expect(contextMenu.templateForEvent({ target: grandchild }).length).toBe(
        4
      );
    });

    it('throws an error when the selector is invalid', function() {
      let addError = null;
      try {
        contextMenu.add({ '<>': [{ label: 'A', command: 'a' }] });
      } catch (error) {
        addError = error;
      }
      expect(addError.message).toContain('<>');
    });

    it('calls `created` hooks for submenu items', function() {
      const item = {
        label: 'A',
        command: 'B',
        submenu: [
          {
            label: 'C',
            created(event) {
              this.label = 'D';
            }
          }
        ]
      };
      contextMenu.add({ '.grandchild': [item] });

      const dispatchedEvent = { target: grandchild };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'A',
          id: 'A',
          command: 'B',
          submenu: [
            {
              label: 'D',
              id: 'D'
            }
          ]
        }
      ]);
    });
  });

  describe('::templateForEvent(target)', function() {
    let [keymaps, item] = [];

    beforeEach(function() {
      keymaps = atom.keymaps.add('source', {
        '.child': {
          'ctrl-a': 'test:my-command',
          'shift-b': 'test:my-other-command'
        }
      });
      item = {
        label: 'My Command',
        command: 'test:my-command',
        submenu: [
          {
            label: 'My Other Command',
            command: 'test:my-other-command'
          }
        ]
      };
      contextMenu.add({ '.parent': [item] });
    });

    afterEach(() => keymaps.dispose());

    it('adds Electron-style accelerators to items that have keybindings', function() {
      child.focus();
      const dispatchedEvent = { target: child };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'My Command',
          id: 'My Command',
          command: 'test:my-command',
          accelerator: 'Ctrl+A',
          submenu: [
            {
              label: 'My Other Command',
              id: 'My Other Command',
              command: 'test:my-other-command',
              accelerator: 'Shift+B'
            }
          ]
        }
      ]);
    });

    it('adds accelerators when a parent node has key bindings for a given command', function() {
      grandchild.focus();
      const dispatchedEvent = { target: grandchild };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'My Command',
          id: 'My Command',
          command: 'test:my-command',
          accelerator: 'Ctrl+A',
          submenu: [
            {
              label: 'My Other Command',
              id: 'My Other Command',
              command: 'test:my-other-command',
              accelerator: 'Shift+B'
            }
          ]
        }
      ]);
    });

    it('does not add accelerators when a child node has key bindings for a given command', function() {
      parent.focus();
      const dispatchedEvent = { target: parent };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'My Command',
          id: 'My Command',
          command: 'test:my-command',
          submenu: [
            {
              label: 'My Other Command',
              id: 'My Other Command',
              command: 'test:my-other-command'
            }
          ]
        }
      ]);
    });

    it('adds accelerators based on focus, not context menu target', function() {
      grandchild.focus();
      const dispatchedEvent = { target: parent };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'My Command',
          id: 'My Command',
          command: 'test:my-command',
          accelerator: 'Ctrl+A',
          submenu: [
            {
              label: 'My Other Command',
              id: 'My Other Command',
              command: 'test:my-other-command',
              accelerator: 'Shift+B'
            }
          ]
        }
      ]);
    });

    it('does not add accelerators for multi-keystroke key bindings', function() {
      atom.keymaps.add('source', {
        '.child': {
          'ctrl-a ctrl-b': 'test:multi-keystroke-command'
        }
      });
      contextMenu.clear();
      contextMenu.add({
        '.parent': [
          {
            label: 'Multi-keystroke command',
            command: 'test:multi-keystroke-command'
          }
        ]
      });

      child.focus();

      const label = process.platform === 'darwin' ? '⌃A ⌃B' : 'Ctrl+A Ctrl+B';
      expect(contextMenu.templateForEvent({ target: child })).toEqual([
        {
          label: `Multi-keystroke command [${label}]`,
          id: `Multi-keystroke command`,
          command: 'test:multi-keystroke-command'
        }
      ]);
    });
  });

  describe('::templateForEvent(target) (sorting)', function() {
    it('applies simple sorting rules', function() {
      contextMenu.add({
        '.parent': [
          {
            label: 'My Command',
            command: 'test:my-command',
            after: ['test:my-other-command']
          },
          {
            label: 'My Other Command',
            command: 'test:my-other-command'
          }
        ]
      });
      const dispatchedEvent = { target: parent };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'My Other Command',
          id: 'My Other Command',
          command: 'test:my-other-command'
        },
        {
          label: 'My Command',
          id: 'My Command',
          command: 'test:my-command',
          after: ['test:my-other-command']
        }
      ]);
    });

    it('applies sorting rules recursively to submenus', function() {
      contextMenu.add({
        '.parent': [
          {
            label: 'Parent',
            submenu: [
              {
                label: 'My Command',
                command: 'test:my-command',
                after: ['test:my-other-command']
              },
              {
                label: 'My Other Command',
                command: 'test:my-other-command'
              }
            ]
          }
        ]
      });
      const dispatchedEvent = { target: parent };
      expect(contextMenu.templateForEvent(dispatchedEvent)).toEqual([
        {
          label: 'Parent',
          id: `Parent`,
          submenu: [
            {
              label: 'My Other Command',
              id: 'My Other Command',
              command: 'test:my-other-command'
            },
            {
              label: 'My Command',
              id: 'My Command',
              command: 'test:my-command',
              after: ['test:my-other-command']
            }
          ]
        }
      ]);
    });
  });
});
