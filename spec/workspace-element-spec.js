/** @babel */

const { ipcRenderer } = require('electron');
const etch = require('etch');
const path = require('path');
const temp = require('temp').track();
const { Disposable } = require('event-kit');

const getNextUpdatePromise = () => etch.getScheduler().nextUpdatePromise;

describe('WorkspaceElement', () => {
  afterEach(() => {
    try {
      temp.cleanupSync();
    } catch (e) {
      // Do nothing
    }
  });

  describe('when the workspace element is focused', () => {
    it('transfers focus to the active pane', () => {
      const workspaceElement = atom.workspace.getElement();
      jasmine.attachToDOM(workspaceElement);
      const activePaneElement = atom.workspace.getActivePane().getElement();
      document.body.focus();
      expect(document.activeElement).not.toBe(activePaneElement);
      workspaceElement.focus();
      expect(document.activeElement).toBe(activePaneElement);
    });
  });

  describe('when the active pane of an inactive pane container is focused', () => {
    it('changes the active pane container', () => {
      const dock = atom.workspace.getLeftDock();
      dock.show();
      jasmine.attachToDOM(atom.workspace.getElement());
      expect(atom.workspace.getActivePaneContainer()).toBe(
        atom.workspace.getCenter()
      );
      dock
        .getActivePane()
        .getElement()
        .focus();
      expect(atom.workspace.getActivePaneContainer()).toBe(dock);
    });
  });

  describe('finding the nearest visible pane in a specific direction', () => {
    let nearestPaneElement,
      pane1,
      pane2,
      pane3,
      pane4,
      pane5,
      pane6,
      pane7,
      pane8,
      leftDockPane,
      rightDockPane,
      bottomDockPane,
      workspace,
      workspaceElement;

    beforeEach(function() {
      atom.config.set('core.destroyEmptyPanes', false);
      expect(document.hasFocus()).toBe(
        true,
        'Document needs to be focused to run this test'
      );

      workspace = atom.workspace;

      // Set up a workspace center with a grid of 9 panes, in the following
      // arrangement, where the numbers correspond to the variable names below.
      //
      // -------
      // |1|2|3|
      // -------
      // |4|5|6|
      // -------
      // |7|8|9|
      // -------

      const container = workspace.getActivePaneContainer();
      expect(container.getLocation()).toEqual('center');
      expect(container.getPanes().length).toEqual(1);

      pane1 = container.getActivePane();
      pane4 = pane1.splitDown();
      pane7 = pane4.splitDown();

      pane2 = pane1.splitRight();
      pane3 = pane2.splitRight();

      pane5 = pane4.splitRight();
      pane6 = pane5.splitRight();

      pane8 = pane7.splitRight();
      pane8.splitRight();

      const leftDock = workspace.getLeftDock();
      const rightDock = workspace.getRightDock();
      const bottomDock = workspace.getBottomDock();

      expect(leftDock.isVisible()).toBe(false);
      expect(rightDock.isVisible()).toBe(false);
      expect(bottomDock.isVisible()).toBe(false);

      expect(leftDock.getPanes().length).toBe(1);
      expect(rightDock.getPanes().length).toBe(1);
      expect(bottomDock.getPanes().length).toBe(1);

      leftDockPane = leftDock.getPanes()[0];
      rightDockPane = rightDock.getPanes()[0];
      bottomDockPane = bottomDock.getPanes()[0];

      workspaceElement = atom.workspace.getElement();
      workspaceElement.style.height = '400px';
      workspaceElement.style.width = '400px';
      jasmine.attachToDOM(workspaceElement);
    });

    describe('finding the nearest pane above', () => {
      describe('when there are multiple rows above the pane', () => {
        it('returns the pane in the adjacent row above', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'above',
            pane8
          );
          expect(nearestPaneElement).toBe(pane5.getElement());
        });
      });

      describe('when there are no rows above the pane', () => {
        it('returns null', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'above',
            pane2
          );
          expect(nearestPaneElement).toBeUndefined(); // TODO Expect toBeNull()
        });
      });

      describe('when the bottom dock contains the pane', () => {
        it('returns the pane in the adjacent row above', () => {
          workspace.getBottomDock().show();
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'above',
            bottomDockPane
          );
          expect(nearestPaneElement).toBe(pane7.getElement());
        });
      });
    });

    describe('finding the nearest pane below', () => {
      describe('when there are multiple rows below the pane', () => {
        it('returns the pane in the adjacent row below', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'below',
            pane2
          );
          expect(nearestPaneElement).toBe(pane5.getElement());
        });
      });

      describe('when there are no rows below the pane', () => {
        it('returns null', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'below',
            pane8
          );
          expect(nearestPaneElement).toBeUndefined(); // TODO Expect toBeNull()
        });
      });

      describe('when the bottom dock is visible', () => {
        describe("when the workspace center's bottommost row contains the pane", () => {
          it("returns the pane in the bottom dock's adjacent row below", () => {
            workspace.getBottomDock().show();
            nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
              'below',
              pane8
            );
            expect(nearestPaneElement).toBe(bottomDockPane.getElement());
          });
        });
      });
    });

    describe('finding the nearest pane to the left', () => {
      describe('when there are multiple columns to the left of the pane', () => {
        it('returns the pane in the adjacent column to the left', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'left',
            pane6
          );
          expect(nearestPaneElement).toBe(pane5.getElement());
        });
      });

      describe('when there are no columns to the left of the pane', () => {
        it('returns null', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'left',
            pane4
          );
          expect(nearestPaneElement).toBeUndefined(); // TODO Expect toBeNull()
        });
      });

      describe('when the right dock contains the pane', () => {
        it('returns the pane in the adjacent column to the left', () => {
          workspace.getRightDock().show();
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'left',
            rightDockPane
          );
          expect(nearestPaneElement).toBe(pane3.getElement());
        });
      });

      describe('when the left dock is visible', () => {
        describe("when the workspace center's leftmost column contains the pane", () => {
          it("returns the pane in the left dock's adjacent column to the left", () => {
            workspace.getLeftDock().show();
            nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
              'left',
              pane4
            );
            expect(nearestPaneElement).toBe(leftDockPane.getElement());
          });
        });

        describe('when the bottom dock contains the pane', () => {
          it("returns the pane in the left dock's adjacent column to the left", () => {
            workspace.getLeftDock().show();
            workspace.getBottomDock().show();
            nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
              'left',
              bottomDockPane
            );
            expect(nearestPaneElement).toBe(leftDockPane.getElement());
          });
        });
      });
    });

    describe('finding the nearest pane to the right', () => {
      describe('when there are multiple columns to the right of the pane', () => {
        it('returns the pane in the adjacent column to the right', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'right',
            pane4
          );
          expect(nearestPaneElement).toBe(pane5.getElement());
        });
      });

      describe('when there are no columns to the right of the pane', () => {
        it('returns null', () => {
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'right',
            pane6
          );
          expect(nearestPaneElement).toBeUndefined(); // TODO Expect toBeNull()
        });
      });

      describe('when the left dock contains the pane', () => {
        it('returns the pane in the adjacent column to the right', () => {
          workspace.getLeftDock().show();
          nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
            'right',
            leftDockPane
          );
          expect(nearestPaneElement).toBe(pane1.getElement());
        });
      });

      describe('when the right dock is visible', () => {
        describe("when the workspace center's rightmost column contains the pane", () => {
          it("returns the pane in the right dock's adjacent column to the right", () => {
            workspace.getRightDock().show();
            nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
              'right',
              pane6
            );
            expect(nearestPaneElement).toBe(rightDockPane.getElement());
          });
        });

        describe('when the bottom dock contains the pane', () => {
          it("returns the pane in the right dock's adjacent column to the right", () => {
            workspace.getRightDock().show();
            workspace.getBottomDock().show();
            nearestPaneElement = workspaceElement.nearestVisiblePaneInDirection(
              'right',
              bottomDockPane
            );
            expect(nearestPaneElement).toBe(rightDockPane.getElement());
          });
        });
      });
    });
  });

  describe('changing focus, copying, and moving items directionally between panes', function() {
    let workspace, workspaceElement, startingPane;

    beforeEach(function() {
      atom.config.set('core.destroyEmptyPanes', false);
      expect(document.hasFocus()).toBe(
        true,
        'Document needs to be focused to run this test'
      );

      workspace = atom.workspace;
      expect(workspace.getLeftDock().isVisible()).toBe(false);
      expect(workspace.getRightDock().isVisible()).toBe(false);
      expect(workspace.getBottomDock().isVisible()).toBe(false);

      const panes = workspace.getCenter().getPanes();
      expect(panes.length).toEqual(1);
      startingPane = panes[0];

      workspaceElement = atom.workspace.getElement();
      workspaceElement.style.height = '400px';
      workspaceElement.style.width = '400px';
      jasmine.attachToDOM(workspaceElement);
    });

    describe('::focusPaneViewAbove()', function() {
      describe('when there is a row above the focused pane', () =>
        it('focuses up to the adjacent row', function() {
          const paneAbove = startingPane.splitUp();
          startingPane.activate();
          workspaceElement.focusPaneViewAbove();
          expect(document.activeElement).toBe(paneAbove.getElement());
        }));

      describe('when there are no rows above the focused pane', () =>
        it('keeps the current pane focused', function() {
          startingPane.activate();
          workspaceElement.focusPaneViewAbove();
          expect(document.activeElement).toBe(startingPane.getElement());
        }));
    });

    describe('::focusPaneViewBelow()', function() {
      describe('when there is a row below the focused pane', () =>
        it('focuses down to the adjacent row', function() {
          const paneBelow = startingPane.splitDown();
          startingPane.activate();
          workspaceElement.focusPaneViewBelow();
          expect(document.activeElement).toBe(paneBelow.getElement());
        }));

      describe('when there are no rows below the focused pane', () =>
        it('keeps the current pane focused', function() {
          startingPane.activate();
          workspaceElement.focusPaneViewBelow();
          expect(document.activeElement).toBe(startingPane.getElement());
        }));
    });

    describe('::focusPaneViewOnLeft()', function() {
      describe('when there is a column to the left of the focused pane', () =>
        it('focuses left to the adjacent column', function() {
          const paneOnLeft = startingPane.splitLeft();
          startingPane.activate();
          workspaceElement.focusPaneViewOnLeft();
          expect(document.activeElement).toBe(paneOnLeft.getElement());
        }));

      describe('when there are no columns to the left of the focused pane', () =>
        it('keeps the current pane focused', function() {
          startingPane.activate();
          workspaceElement.focusPaneViewOnLeft();
          expect(document.activeElement).toBe(startingPane.getElement());
        }));
    });

    describe('::focusPaneViewOnRight()', function() {
      describe('when there is a column to the right of the focused pane', () =>
        it('focuses right to the adjacent column', function() {
          const paneOnRight = startingPane.splitRight();
          startingPane.activate();
          workspaceElement.focusPaneViewOnRight();
          expect(document.activeElement).toBe(paneOnRight.getElement());
        }));

      describe('when there are no columns to the right of the focused pane', () =>
        it('keeps the current pane focused', function() {
          startingPane.activate();
          workspaceElement.focusPaneViewOnRight();
          expect(document.activeElement).toBe(startingPane.getElement());
        }));
    });

    describe('::moveActiveItemToPaneAbove(keepOriginal)', function() {
      describe('when there is a row above the focused pane', () =>
        it('moves the active item up to the adjacent row', function() {
          const item = document.createElement('div');
          const paneAbove = startingPane.splitUp();
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneAbove();
          expect(workspace.paneForItem(item)).toBe(paneAbove);
          expect(paneAbove.getActiveItem()).toBe(item);
        }));

      describe('when there are no rows above the focused pane', () =>
        it('keeps the active pane focused', function() {
          const item = document.createElement('div');
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneAbove();
          expect(workspace.paneForItem(item)).toBe(startingPane);
        }));

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function() {
          const itemA = document.createElement('div');
          const itemB = document.createElement('div');
          itemA.copy = () => itemB;
          const paneAbove = startingPane.splitUp();
          startingPane.activate();
          startingPane.activateItem(itemA);
          workspaceElement.moveActiveItemToPaneAbove({ keepOriginal: true });
          expect(workspace.paneForItem(itemA)).toBe(startingPane);
          expect(paneAbove.getActiveItem()).toBe(itemB);
        }));
    });

    describe('::moveActiveItemToPaneBelow(keepOriginal)', function() {
      describe('when there is a row below the focused pane', () =>
        it('moves the active item down to the adjacent row', function() {
          const item = document.createElement('div');
          const paneBelow = startingPane.splitDown();
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneBelow();
          expect(workspace.paneForItem(item)).toBe(paneBelow);
          expect(paneBelow.getActiveItem()).toBe(item);
        }));

      describe('when there are no rows below the focused pane', () =>
        it('keeps the active item in the focused pane', function() {
          const item = document.createElement('div');
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneBelow();
          expect(workspace.paneForItem(item)).toBe(startingPane);
        }));

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function() {
          const itemA = document.createElement('div');
          const itemB = document.createElement('div');
          itemA.copy = () => itemB;
          const paneBelow = startingPane.splitDown();
          startingPane.activate();
          startingPane.activateItem(itemA);
          workspaceElement.moveActiveItemToPaneBelow({ keepOriginal: true });
          expect(workspace.paneForItem(itemA)).toBe(startingPane);
          expect(paneBelow.getActiveItem()).toBe(itemB);
        }));
    });

    describe('::moveActiveItemToPaneOnLeft(keepOriginal)', function() {
      describe('when there is a column to the left of the focused pane', () =>
        it('moves the active item left to the adjacent column', function() {
          const item = document.createElement('div');
          const paneOnLeft = startingPane.splitLeft();
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneOnLeft();
          expect(workspace.paneForItem(item)).toBe(paneOnLeft);
          expect(paneOnLeft.getActiveItem()).toBe(item);
        }));

      describe('when there are no columns to the left of the focused pane', () =>
        it('keeps the active item in the focused pane', function() {
          const item = document.createElement('div');
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneOnLeft();
          expect(workspace.paneForItem(item)).toBe(startingPane);
        }));

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function() {
          const itemA = document.createElement('div');
          const itemB = document.createElement('div');
          itemA.copy = () => itemB;
          const paneOnLeft = startingPane.splitLeft();
          startingPane.activate();
          startingPane.activateItem(itemA);
          workspaceElement.moveActiveItemToPaneOnLeft({ keepOriginal: true });
          expect(workspace.paneForItem(itemA)).toBe(startingPane);
          expect(paneOnLeft.getActiveItem()).toBe(itemB);
        }));
    });

    describe('::moveActiveItemToPaneOnRight(keepOriginal)', function() {
      describe('when there is a column to the right of the focused pane', () =>
        it('moves the active item right to the adjacent column', function() {
          const item = document.createElement('div');
          const paneOnRight = startingPane.splitRight();
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneOnRight();
          expect(workspace.paneForItem(item)).toBe(paneOnRight);
          expect(paneOnRight.getActiveItem()).toBe(item);
        }));

      describe('when there are no columns to the right of the focused pane', () =>
        it('keeps the active item in the focused pane', function() {
          const item = document.createElement('div');
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToPaneOnRight();
          expect(workspace.paneForItem(item)).toBe(startingPane);
        }));

      describe('when `keepOriginal: true` is passed in the params', () =>
        it('keeps the item and adds a copy of it to the adjacent pane', function() {
          const itemA = document.createElement('div');
          const itemB = document.createElement('div');
          itemA.copy = () => itemB;
          const paneOnRight = startingPane.splitRight();
          startingPane.activate();
          startingPane.activateItem(itemA);
          workspaceElement.moveActiveItemToPaneOnRight({ keepOriginal: true });
          expect(workspace.paneForItem(itemA)).toBe(startingPane);
          expect(paneOnRight.getActiveItem()).toBe(itemB);
        }));
    });

    describe('::moveActiveItemToNearestPaneInDirection(direction, params)', () => {
      describe('when the item is not allowed in nearest pane in the given direction', () => {
        it('does not move or copy the active item', function() {
          const item = {
            element: document.createElement('div'),
            getAllowedLocations: () => ['left', 'right']
          };

          workspace.getBottomDock().show();
          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.moveActiveItemToNearestPaneInDirection('below', {
            keepOriginal: false
          });
          expect(workspace.paneForItem(item)).toBe(startingPane);

          workspaceElement.moveActiveItemToNearestPaneInDirection('below', {
            keepOriginal: true
          });
          expect(workspace.paneForItem(item)).toBe(startingPane);
        });
      });

      describe("when the item doesn't implement a `copy` function", () => {
        it('does not copy the active item', function() {
          const item = document.createElement('div');
          const paneBelow = startingPane.splitDown();
          expect(paneBelow.getItems().length).toEqual(0);

          startingPane.activate();
          startingPane.activateItem(item);
          workspaceElement.focusPaneViewAbove();
          workspaceElement.moveActiveItemToNearestPaneInDirection('below', {
            keepOriginal: true
          });
          expect(workspace.paneForItem(item)).toBe(startingPane);
          expect(paneBelow.getItems().length).toEqual(0);
        });
      });
    });
  });

  describe('mousing over docks', () => {
    let workspaceElement;
    let originalTimeout = jasmine.getEnv().defaultTimeoutInterval;

    beforeEach(() => {
      workspaceElement = atom.workspace.getElement();
      workspaceElement.style.width = '600px';
      workspaceElement.style.height = '300px';
      jasmine.attachToDOM(workspaceElement);

      // To isolate this test from unintended events happening on the host machine,
      // we remove any listener that could cause interferences.
      window.removeEventListener(
        'mousemove',
        workspaceElement.handleEdgesMouseMove
      );
      workspaceElement.htmlElement.removeEventListener(
        'mouseleave',
        workspaceElement.handleCenterLeave
      );

      jasmine.getEnv().defaultTimeoutInterval = 10000;
    });

    afterEach(() => {
      jasmine.getEnv().defaultTimeoutInterval = originalTimeout;

      window.addEventListener(
        'mousemove',
        workspaceElement.handleEdgesMouseMove
      );
      workspaceElement.htmlElement.addEventListener(
        'mouseleave',
        workspaceElement.handleCenterLeave
      );
    });

    it('shows the toggle button when the dock is open', async () => {
      await Promise.all([
        atom.workspace.open({
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'left';
          },
          getPreferredWidth() {
            return 150;
          }
        }),
        atom.workspace.open({
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'right';
          },
          getPreferredWidth() {
            return 150;
          }
        }),
        atom.workspace.open({
          element: document.createElement('div'),
          getDefaultLocation() {
            return 'bottom';
          },
          getPreferredHeight() {
            return 100;
          }
        })
      ]);

      const leftDock = atom.workspace.getLeftDock();
      const rightDock = atom.workspace.getRightDock();
      const bottomDock = atom.workspace.getBottomDock();

      expect(leftDock.isVisible()).toBe(true);
      expect(rightDock.isVisible()).toBe(true);
      expect(bottomDock.isVisible()).toBe(true);
      expectToggleButtonHidden(leftDock);
      expectToggleButtonHidden(rightDock);
      expectToggleButtonHidden(bottomDock);

      // --- Right Dock ---

      // Mouse over where the toggle button would be if the dock were hovered
      moveMouse({ clientX: 440, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonHidden(rightDock);
      expectToggleButtonHidden(bottomDock);

      // Mouse over the dock
      moveMouse({ clientX: 460, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonVisible(rightDock, 'icon-chevron-right');
      expectToggleButtonHidden(bottomDock);

      // Mouse over the toggle button
      moveMouse({ clientX: 440, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonVisible(rightDock, 'icon-chevron-right');
      expectToggleButtonHidden(bottomDock);

      // Click the toggle button
      rightDock.refs.toggleButton.refs.innerElement.click();
      await getNextUpdatePromise();
      expect(rightDock.isVisible()).toBe(false);
      expectToggleButtonHidden(rightDock);

      // Mouse to edge of the window
      moveMouse({ clientX: 575, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(rightDock);
      moveMouse({ clientX: 598, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonVisible(rightDock, 'icon-chevron-left');

      // Click the toggle button again
      rightDock.refs.toggleButton.refs.innerElement.click();
      await getNextUpdatePromise();
      expect(rightDock.isVisible()).toBe(true);
      expectToggleButtonVisible(rightDock, 'icon-chevron-right');

      // --- Left Dock ---

      // Mouse over where the toggle button would be if the dock were hovered
      moveMouse({ clientX: 160, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonHidden(rightDock);
      expectToggleButtonHidden(bottomDock);

      // Mouse over the dock
      moveMouse({ clientX: 140, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonVisible(leftDock, 'icon-chevron-left');
      expectToggleButtonHidden(rightDock);
      expectToggleButtonHidden(bottomDock);

      // Mouse over the toggle button
      moveMouse({ clientX: 160, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonVisible(leftDock, 'icon-chevron-left');
      expectToggleButtonHidden(rightDock);
      expectToggleButtonHidden(bottomDock);

      // Click the toggle button
      leftDock.refs.toggleButton.refs.innerElement.click();
      await getNextUpdatePromise();
      expect(leftDock.isVisible()).toBe(false);
      expectToggleButtonHidden(leftDock);

      // Mouse to edge of the window
      moveMouse({ clientX: 25, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      moveMouse({ clientX: 2, clientY: 150 });
      await getNextUpdatePromise();
      expectToggleButtonVisible(leftDock, 'icon-chevron-right');

      // Click the toggle button again
      leftDock.refs.toggleButton.refs.innerElement.click();
      await getNextUpdatePromise();
      expect(leftDock.isVisible()).toBe(true);
      expectToggleButtonVisible(leftDock, 'icon-chevron-left');

      // --- Bottom Dock ---

      // Mouse over where the toggle button would be if the dock were hovered
      moveMouse({ clientX: 300, clientY: 190 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonHidden(rightDock);
      expectToggleButtonHidden(bottomDock);

      // Mouse over the dock
      moveMouse({ clientX: 300, clientY: 210 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonHidden(rightDock);
      expectToggleButtonVisible(bottomDock, 'icon-chevron-down');

      // Mouse over the toggle button
      moveMouse({ clientX: 300, clientY: 195 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      expectToggleButtonHidden(rightDock);
      expectToggleButtonVisible(bottomDock, 'icon-chevron-down');

      // Click the toggle button
      bottomDock.refs.toggleButton.refs.innerElement.click();
      await getNextUpdatePromise();
      expect(bottomDock.isVisible()).toBe(false);
      expectToggleButtonHidden(bottomDock);

      // Mouse to edge of the window
      moveMouse({ clientX: 300, clientY: 290 });
      await getNextUpdatePromise();
      expectToggleButtonHidden(leftDock);
      moveMouse({ clientX: 300, clientY: 299 });
      await getNextUpdatePromise();
      expectToggleButtonVisible(bottomDock, 'icon-chevron-up');

      // Click the toggle button again
      bottomDock.refs.toggleButton.refs.innerElement.click();
      await getNextUpdatePromise();
      expect(bottomDock.isVisible()).toBe(true);
      expectToggleButtonVisible(bottomDock, 'icon-chevron-down');
    });

    function moveMouse(coordinates) {
      // Simulate a mouse move event by calling the method that handles that event.
      workspaceElement.updateHoveredDock({
        x: coordinates.clientX,
        y: coordinates.clientY
      });
      advanceClock(100);
    }

    function expectToggleButtonHidden(dock) {
      expect(dock.refs.toggleButton.element).not.toHaveClass(
        'atom-dock-toggle-button-visible'
      );
    }

    function expectToggleButtonVisible(dock, iconClass) {
      expect(dock.refs.toggleButton.element).toHaveClass(
        'atom-dock-toggle-button-visible'
      );
      expect(dock.refs.toggleButton.refs.iconElement).toHaveClass(iconClass);
    }
  });

  describe('the scrollbar visibility class', () => {
    it('has a class based on the style of the scrollbar', () => {
      let observeCallback;
      const scrollbarStyle = require('scrollbar-style');
      spyOn(scrollbarStyle, 'observePreferredScrollbarStyle').andCallFake(
        cb => {
          observeCallback = cb;
          return new Disposable(() => {});
        }
      );

      const workspaceElement = atom.workspace.getElement();
      observeCallback('legacy');
      expect(workspaceElement.className).toMatch('scrollbars-visible-always');

      observeCallback('overlay');
      expect(workspaceElement).toHaveClass('scrollbars-visible-when-scrolling');
    });
  });

  describe('editor font styling', () => {
    let editor, editorElement, workspaceElement;

    beforeEach(async () => {
      await atom.workspace.open('sample.js');

      workspaceElement = atom.workspace.getElement();
      jasmine.attachToDOM(workspaceElement);
      editor = atom.workspace.getActiveTextEditor();
      editorElement = editor.getElement();
    });

    it("updates the font-size based on the 'editor.fontSize' config value", async () => {
      const initialCharWidth = editor.getDefaultCharWidth();
      expect(getComputedStyle(editorElement).fontSize).toBe(
        atom.config.get('editor.fontSize') + 'px'
      );

      atom.config.set(
        'editor.fontSize',
        atom.config.get('editor.fontSize') + 5
      );
      await editorElement.component.getNextUpdatePromise();
      expect(getComputedStyle(editorElement).fontSize).toBe(
        atom.config.get('editor.fontSize') + 'px'
      );
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(initialCharWidth);
    });

    it("updates the font-family based on the 'editor.fontFamily' config value", async () => {
      const initialCharWidth = editor.getDefaultCharWidth();
      let fontFamily = atom.config.get('editor.fontFamily');
      expect(getComputedStyle(editorElement).fontFamily).toBe(fontFamily);

      atom.config.set('editor.fontFamily', 'sans-serif');
      fontFamily = atom.config.get('editor.fontFamily');
      await editorElement.component.getNextUpdatePromise();
      expect(getComputedStyle(editorElement).fontFamily).toBe(fontFamily);
      expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth);
    });

    it("updates the line-height based on the 'editor.lineHeight' config value", async () => {
      const initialLineHeight = editor.getLineHeightInPixels();
      atom.config.set('editor.lineHeight', '30px');
      await editorElement.component.getNextUpdatePromise();
      expect(getComputedStyle(editorElement).lineHeight).toBe(
        atom.config.get('editor.lineHeight')
      );
      expect(editor.getLineHeightInPixels()).not.toBe(initialLineHeight);
    });

    it('increases or decreases the font size when a ctrl-mousewheel event occurs', () => {
      atom.config.set('editor.zoomFontWhenCtrlScrolling', true);
      atom.config.set('editor.fontSize', 12);

      // Zoom out
      editorElement.querySelector('span').dispatchEvent(
        new WheelEvent('mousewheel', {
          wheelDeltaY: -10,
          ctrlKey: true
        })
      );
      expect(atom.config.get('editor.fontSize')).toBe(11);

      // Zoom in
      editorElement.querySelector('span').dispatchEvent(
        new WheelEvent('mousewheel', {
          wheelDeltaY: 10,
          ctrlKey: true
        })
      );
      expect(atom.config.get('editor.fontSize')).toBe(12);

      // Not on an atom-text-editor
      workspaceElement.dispatchEvent(
        new WheelEvent('mousewheel', {
          wheelDeltaY: 10,
          ctrlKey: true
        })
      );
      expect(atom.config.get('editor.fontSize')).toBe(12);

      // No ctrl key
      editorElement.querySelector('span').dispatchEvent(
        new WheelEvent('mousewheel', {
          wheelDeltaY: 10
        })
      );
      expect(atom.config.get('editor.fontSize')).toBe(12);

      atom.config.set('editor.zoomFontWhenCtrlScrolling', false);
      editorElement.querySelector('span').dispatchEvent(
        new WheelEvent('mousewheel', {
          wheelDeltaY: 10,
          ctrlKey: true
        })
      );
      expect(atom.config.get('editor.fontSize')).toBe(12);
    });
  });

  describe('panel containers', () => {
    it('inserts panel container elements in the correct places in the DOM', () => {
      const workspaceElement = atom.workspace.getElement();

      const leftContainer = workspaceElement.querySelector(
        'atom-panel-container.left'
      );
      const rightContainer = workspaceElement.querySelector(
        'atom-panel-container.right'
      );
      expect(leftContainer.nextSibling).toBe(workspaceElement.verticalAxis);
      expect(rightContainer.previousSibling).toBe(
        workspaceElement.verticalAxis
      );

      const topContainer = workspaceElement.querySelector(
        'atom-panel-container.top'
      );
      const bottomContainer = workspaceElement.querySelector(
        'atom-panel-container.bottom'
      );
      expect(topContainer.nextSibling).toBe(workspaceElement.paneContainer);
      expect(bottomContainer.previousSibling).toBe(
        workspaceElement.paneContainer
      );

      const headerContainer = workspaceElement.querySelector(
        'atom-panel-container.header'
      );
      const footerContainer = workspaceElement.querySelector(
        'atom-panel-container.footer'
      );
      expect(headerContainer.nextSibling).toBe(workspaceElement.horizontalAxis);
      expect(footerContainer.previousSibling).toBe(
        workspaceElement.horizontalAxis
      );

      const modalContainer = workspaceElement.querySelector(
        'atom-panel-container.modal'
      );
      expect(modalContainer.parentNode).toBe(workspaceElement);
    });

    it('stretches header/footer panels to the workspace width', () => {
      const workspaceElement = atom.workspace.getElement();
      jasmine.attachToDOM(workspaceElement);
      expect(workspaceElement.offsetWidth).toBeGreaterThan(0);

      const headerItem = document.createElement('div');
      atom.workspace.addHeaderPanel({ item: headerItem });
      expect(headerItem.offsetWidth).toEqual(workspaceElement.offsetWidth);

      const footerItem = document.createElement('div');
      atom.workspace.addFooterPanel({ item: footerItem });
      expect(footerItem.offsetWidth).toEqual(workspaceElement.offsetWidth);
    });

    it('shrinks horizontal axis according to header/footer panels height', () => {
      const workspaceElement = atom.workspace.getElement();
      workspaceElement.style.height = '100px';
      const horizontalAxisElement = workspaceElement.querySelector(
        'atom-workspace-axis.horizontal'
      );
      jasmine.attachToDOM(workspaceElement);

      const originalHorizontalAxisHeight = horizontalAxisElement.offsetHeight;
      expect(workspaceElement.offsetHeight).toBeGreaterThan(0);
      expect(originalHorizontalAxisHeight).toBeGreaterThan(0);

      const headerItem = document.createElement('div');
      headerItem.style.height = '10px';
      atom.workspace.addHeaderPanel({ item: headerItem });
      expect(headerItem.offsetHeight).toBeGreaterThan(0);

      const footerItem = document.createElement('div');
      footerItem.style.height = '15px';
      atom.workspace.addFooterPanel({ item: footerItem });
      expect(footerItem.offsetHeight).toBeGreaterThan(0);

      expect(horizontalAxisElement.offsetHeight).toEqual(
        originalHorizontalAxisHeight -
          headerItem.offsetHeight -
          footerItem.offsetHeight
      );
    });
  });

  describe("the 'window:toggle-invisibles' command", () => {
    it('shows/hides invisibles in all open and future editors', () => {
      const workspaceElement = atom.workspace.getElement();
      expect(atom.config.get('editor.showInvisibles')).toBe(false);
      atom.commands.dispatch(workspaceElement, 'window:toggle-invisibles');
      expect(atom.config.get('editor.showInvisibles')).toBe(true);
      atom.commands.dispatch(workspaceElement, 'window:toggle-invisibles');
      expect(atom.config.get('editor.showInvisibles')).toBe(false);
    });
  });

  describe("the 'window:run-package-specs' command", () => {
    it("runs the package specs for the active item's project path, or the first project path", () => {
      const workspaceElement = atom.workspace.getElement();
      spyOn(ipcRenderer, 'send');

      // No project paths. Don't try to run specs.
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs');
      expect(ipcRenderer.send).not.toHaveBeenCalledWith('run-package-specs');

      const projectPaths = [temp.mkdirSync('dir1-'), temp.mkdirSync('dir2-')];
      atom.project.setPaths(projectPaths);

      // No active item. Use first project directory.
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs');
      expect(ipcRenderer.send).toHaveBeenCalledWith(
        'run-package-specs',
        path.join(projectPaths[0], 'spec'),
        {}
      );
      ipcRenderer.send.reset();

      // Active item doesn't implement ::getPath(). Use first project directory.
      const item = document.createElement('div');
      atom.workspace.getActivePane().activateItem(item);
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs');
      expect(ipcRenderer.send).toHaveBeenCalledWith(
        'run-package-specs',
        path.join(projectPaths[0], 'spec'),
        {}
      );
      ipcRenderer.send.reset();

      // Active item has no path. Use first project directory.
      item.getPath = () => null;
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs');
      expect(ipcRenderer.send).toHaveBeenCalledWith(
        'run-package-specs',
        path.join(projectPaths[0], 'spec'),
        {}
      );
      ipcRenderer.send.reset();

      // Active item has path. Use project path for item path.
      item.getPath = () => path.join(projectPaths[1], 'a-file.txt');
      atom.commands.dispatch(workspaceElement, 'window:run-package-specs');
      expect(ipcRenderer.send).toHaveBeenCalledWith(
        'run-package-specs',
        path.join(projectPaths[1], 'spec'),
        {}
      );
      ipcRenderer.send.reset();
    });

    it('passes additional options to the spec window', () => {
      const workspaceElement = atom.workspace.getElement();
      spyOn(ipcRenderer, 'send');

      const projectPath = temp.mkdirSync('dir1-');
      atom.project.setPaths([projectPath]);
      workspaceElement.runPackageSpecs({
        env: { ATOM_GITHUB_BABEL_ENV: 'coverage' }
      });

      expect(ipcRenderer.send).toHaveBeenCalledWith(
        'run-package-specs',
        path.join(projectPath, 'spec'),
        { env: { ATOM_GITHUB_BABEL_ENV: 'coverage' } }
      );
    });
  });
});
