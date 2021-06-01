const { conditionPromise } = require('./async-spec-helpers');

const Random = require('../script/node_modules/random-seed');
const { getRandomBufferRange, buildRandomLines } = require('./helpers/random');
const TextEditorComponent = require('../src/text-editor-component');
const TextEditorElement = require('../src/text-editor-element');
const TextEditor = require('../src/text-editor');
const TextBuffer = require('text-buffer');
const { Point } = TextBuffer;
const fs = require('fs');
const path = require('path');
const Grim = require('grim');
const electron = require('electron');
const clipboard = electron.clipboard;

const SAMPLE_TEXT = fs.readFileSync(
  path.join(__dirname, 'fixtures', 'sample.js'),
  'utf8'
);

document.registerElement('text-editor-component-test-element', {
  prototype: Object.create(HTMLElement.prototype, {
    attachedCallback: {
      value: function() {
        this.didAttach();
      }
    }
  })
});

const editors = [];
let verticalScrollbarWidth, horizontalScrollbarHeight;

describe('TextEditorComponent', () => {
  beforeEach(() => {
    jasmine.useRealClock();

    // Force scrollbars to be visible regardless of local system configuration
    const scrollbarStyle = document.createElement('style');
    scrollbarStyle.textContent =
      'atom-text-editor ::-webkit-scrollbar { -webkit-appearance: none }';
    jasmine.attachToDOM(scrollbarStyle);

    if (verticalScrollbarWidth == null) {
      const { component, element } = buildComponent({
        text: 'abcdefgh\n'.repeat(10),
        width: 30,
        height: 30
      });
      verticalScrollbarWidth = getVerticalScrollbarWidth(component);
      horizontalScrollbarHeight = getHorizontalScrollbarHeight(component);
      element.remove();
    }
  });

  afterEach(() => {
    for (const editor of editors) {
      editor.destroy();
    }
    editors.length = 0;
  });

  describe('rendering', () => {
    it('renders lines and line numbers for the visible region', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });

      expect(queryOnScreenLineNumberElements(element).length).toBe(13);
      expect(queryOnScreenLineElements(element).length).toBe(13);

      element.style.height = 4 * component.measurements.lineHeight + 'px';
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(9);
      expect(queryOnScreenLineElements(element).length).toBe(9);

      await setScrollTop(component, 5 * component.getLineHeight());

      // After scrolling down beyond > 3 rows, the order of line numbers and lines
      // in the DOM is a bit weird because the first tile is recycled to the bottom
      // when it is scrolled out of view
      expect(
        queryOnScreenLineNumberElements(element).map(element =>
          element.textContent.trim()
        )
      ).toEqual(['10', '11', '12', '4', '5', '6', '7', '8', '9']);
      expect(
        queryOnScreenLineElements(element).map(
          element => element.dataset.screenRow
        )
      ).toEqual(['9', '10', '11', '3', '4', '5', '6', '7', '8']);
      expect(
        queryOnScreenLineElements(element).map(element => element.textContent)
      ).toEqual([
        editor.lineTextForScreenRow(9),
        ' ', // this line is blank in the model, but we render a space to prevent the line from collapsing vertically
        editor.lineTextForScreenRow(11),
        editor.lineTextForScreenRow(3),
        editor.lineTextForScreenRow(4),
        editor.lineTextForScreenRow(5),
        editor.lineTextForScreenRow(6),
        editor.lineTextForScreenRow(7),
        editor.lineTextForScreenRow(8)
      ]);

      await setScrollTop(component, 2.5 * component.getLineHeight());
      expect(
        queryOnScreenLineNumberElements(element).map(element =>
          element.textContent.trim()
        )
      ).toEqual(['1', '2', '3', '4', '5', '6', '7', '8', '9']);
      expect(
        queryOnScreenLineElements(element).map(
          element => element.dataset.screenRow
        )
      ).toEqual(['0', '1', '2', '3', '4', '5', '6', '7', '8']);
      expect(
        queryOnScreenLineElements(element).map(element => element.textContent)
      ).toEqual([
        editor.lineTextForScreenRow(0),
        editor.lineTextForScreenRow(1),
        editor.lineTextForScreenRow(2),
        editor.lineTextForScreenRow(3),
        editor.lineTextForScreenRow(4),
        editor.lineTextForScreenRow(5),
        editor.lineTextForScreenRow(6),
        editor.lineTextForScreenRow(7),
        editor.lineTextForScreenRow(8)
      ]);
    });

    it('bases the width of the lines div on the width of the longest initially-visible screen line', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 2,
        height: 20,
        width: 100
      });

      {
        expect(editor.getApproximateLongestScreenRow()).toBe(3);
        const expectedWidth = Math.ceil(
          component.pixelPositionForScreenPosition(Point(3, Infinity)).left +
            component.getBaseCharacterWidth()
        );
        expect(element.querySelector('.lines').style.width).toBe(
          expectedWidth + 'px'
        );
      }

      {
        // Get the next update promise synchronously here to ensure we don't
        // miss the update while polling the condition.
        const nextUpdatePromise = component.getNextUpdatePromise();
        await conditionPromise(
          () => editor.getApproximateLongestScreenRow() === 6
        );
        await nextUpdatePromise;

        // Capture the width of the lines before requesting the width of
        // longest line, because making that request forces a DOM update
        const actualWidth = element.querySelector('.lines').style.width;
        const expectedWidth = Math.ceil(
          component.pixelPositionForScreenPosition(Point(6, Infinity)).left +
            component.getBaseCharacterWidth()
        );
        expect(actualWidth).toBe(expectedWidth + 'px');
      }

      // eslint-disable-next-line no-lone-blocks
      {
        // Make sure we do not throw an error if a synchronous update is
        // triggered before measuring the longest line from a
        // previously-scheduled update.
        editor.getBuffer().insert(Point(12, Infinity), 'x'.repeat(100));
        expect(editor.getLongestScreenRow()).toBe(12);

        TextEditorComponent.getScheduler().readDocument(() => {
          // This will happen before the measurement phase of the update
          // triggered above.
          component.pixelPositionForScreenPosition(Point(11, Infinity));
        });

        await component.getNextUpdatePromise();
      }
    });

    it('re-renders lines when their height changes', async () => {
      const { component, element } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });
      element.style.height = 4 * component.measurements.lineHeight + 'px';
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(9);
      expect(queryOnScreenLineElements(element).length).toBe(9);

      element.style.lineHeight = '2.0';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(6);
      expect(queryOnScreenLineElements(element).length).toBe(6);

      element.style.lineHeight = '0.7';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(12);
      expect(queryOnScreenLineElements(element).length).toBe(12);

      element.style.lineHeight = '0.05';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(13);
      expect(queryOnScreenLineElements(element).length).toBe(13);

      element.style.lineHeight = '0';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(13);
      expect(queryOnScreenLineElements(element).length).toBe(13);

      element.style.lineHeight = '1';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineNumberElements(element).length).toBe(9);
      expect(queryOnScreenLineElements(element).length).toBe(9);
    });

    it('makes the content at least as tall as the scroll container client height', async () => {
      const { component, editor } = buildComponent({
        text: 'a'.repeat(100),
        width: 50,
        height: 100
      });
      expect(component.refs.content.offsetHeight).toBe(
        100 - getHorizontalScrollbarHeight(component)
      );

      editor.setText('a\n'.repeat(30));
      await component.getNextUpdatePromise();
      expect(component.refs.content.offsetHeight).toBeGreaterThan(100);
      expect(component.refs.content.offsetHeight).toBeNear(
        component.getContentHeight(),
        2
      );
    });

    it('honors the scrollPastEnd option by adding empty space equivalent to the clientHeight to the end of the content area', async () => {
      const { component, editor } = buildComponent({
        autoHeight: false,
        autoWidth: false
      });

      await editor.update({ scrollPastEnd: true });
      await setEditorHeightInLines(component, 6);

      // scroll to end
      await setScrollTop(component, Infinity);
      expect(component.getFirstVisibleRow()).toBe(
        editor.getScreenLineCount() - 3
      );

      editor.update({ scrollPastEnd: false });
      await component.getNextUpdatePromise(); // wait for scrollable content resize
      expect(component.getFirstVisibleRow()).toBe(
        editor.getScreenLineCount() - 6
      );

      // Always allows at least 3 lines worth of overscroll if the editor is short
      await setEditorHeightInLines(component, 2);
      await editor.update({ scrollPastEnd: true });
      await setScrollTop(component, Infinity);
      expect(component.getFirstVisibleRow()).toBe(
        editor.getScreenLineCount() + 1
      );
    });

    it('does not fire onDidChangeScrollTop listeners when assigning the same maximal value and the content height has fractional pixels (regression)', async () => {
      const { component, element, editor } = buildComponent({
        autoHeight: false,
        autoWidth: false
      });
      await setEditorHeightInLines(component, 3);

      // Force a fractional content height with a block decoration
      const item = document.createElement('div');
      item.style.height = '10.6px';
      editor.decorateMarker(editor.markBufferPosition([0, 0]), {
        type: 'block',
        item
      });
      await component.getNextUpdatePromise();

      component.setScrollTop(Infinity);
      element.onDidChangeScrollTop(newScrollTop => {
        throw new Error('Scroll top should not have changed');
      });
      component.setScrollTop(component.getScrollTop());
    });

    it('gives the line number tiles an explicit width and height so their layout can be strictly contained', async () => {
      const { component, editor } = buildComponent({ rowsPerTile: 3 });

      const lineNumberGutterElement =
        component.refs.gutterContainer.refs.lineNumberGutter.element;
      expect(lineNumberGutterElement.offsetHeight).toBeNear(
        component.getScrollHeight()
      );

      for (const child of lineNumberGutterElement.children) {
        expect(child.offsetWidth).toBe(lineNumberGutterElement.offsetWidth);
        if (!child.classList.contains('line-number')) {
          for (const lineNumberElement of child.children) {
            expect(lineNumberElement.offsetWidth).toBe(
              lineNumberGutterElement.offsetWidth
            );
          }
        }
      }

      editor.setText('x\n'.repeat(99));
      await component.getNextUpdatePromise();
      expect(lineNumberGutterElement.offsetHeight).toBeNear(
        component.getScrollHeight()
      );
      for (const child of lineNumberGutterElement.children) {
        expect(child.offsetWidth).toBe(lineNumberGutterElement.offsetWidth);
        if (!child.classList.contains('line-number')) {
          for (const lineNumberElement of child.children) {
            expect(lineNumberElement.offsetWidth).toBe(
              lineNumberGutterElement.offsetWidth
            );
          }
        }
      }
    });

    it('keeps the number of tiles stable when the visible line count changes during vertical scrolling', async () => {
      const { component } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 5.5);
      expect(component.refs.lineTiles.children.length).toBe(3 + 2); // account for cursors and highlights containers

      await setScrollTop(component, 0.5 * component.getLineHeight());
      expect(component.refs.lineTiles.children.length).toBe(3 + 2); // account for cursors and highlights containers

      await setScrollTop(component, 1 * component.getLineHeight());
      expect(component.refs.lineTiles.children.length).toBe(3 + 2); // account for cursors and highlights containers
    });

    it('recycles tiles on resize', async () => {
      const { component } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 7);
      await setScrollTop(component, 3.5 * component.getLineHeight());
      const lineNode = lineNodeForScreenRow(component, 7);
      await setEditorHeightInLines(component, 4);
      expect(lineNodeForScreenRow(component, 7)).toBe(lineNode);
    });

    it("updates lines numbers when a row's foldability changes (regression)", async () => {
      const { component, editor } = buildComponent({ text: 'abc\n' });
      editor.setCursorBufferPosition([1, 0]);
      await component.getNextUpdatePromise();
      expect(
        lineNumberNodeForScreenRow(component, 0).querySelector('.foldable')
      ).toBeNull();

      editor.insertText('  def');
      await component.getNextUpdatePromise();
      expect(
        lineNumberNodeForScreenRow(component, 0).querySelector('.foldable')
      ).toBeDefined();

      editor.undo();
      await component.getNextUpdatePromise();
      expect(
        lineNumberNodeForScreenRow(component, 0).querySelector('.foldable')
      ).toBeNull();
    });

    it('shows the foldable icon on the last screen row of a buffer row that can be folded', async () => {
      const { component } = buildComponent({
        text: 'abc\n  de\nfghijklm\n  no',
        softWrapped: true
      });
      await setEditorWidthInCharacters(component, 5);
      expect(
        lineNumberNodeForScreenRow(component, 0).classList.contains('foldable')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('foldable')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 2).classList.contains('foldable')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 3).classList.contains('foldable')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 4).classList.contains('foldable')
      ).toBe(false);
    });

    it('renders dummy vertical and horizontal scrollbars when content overflows', async () => {
      const { component, editor } = buildComponent({
        height: 100,
        width: 100
      });
      const verticalScrollbar = component.refs.verticalScrollbar.element;
      const horizontalScrollbar = component.refs.horizontalScrollbar.element;
      expect(verticalScrollbar.scrollHeight).toBeNear(
        component.getContentHeight()
      );
      expect(horizontalScrollbar.scrollWidth).toBeNear(
        component.getContentWidth()
      );
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(0);
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(0);
      expect(verticalScrollbar.style.bottom).toBe(
        getVerticalScrollbarWidth(component) + 'px'
      );
      expect(verticalScrollbar.style.visibility).toBe('');
      expect(horizontalScrollbar.style.right).toBe(
        getHorizontalScrollbarHeight(component) + 'px'
      );
      expect(horizontalScrollbar.style.visibility).toBe('');
      expect(component.refs.scrollbarCorner).toBeDefined();

      setScrollTop(component, 100);
      await setScrollLeft(component, 100);
      expect(verticalScrollbar.scrollTop).toBe(100);
      expect(horizontalScrollbar.scrollLeft).toBe(100);

      verticalScrollbar.scrollTop = 120;
      horizontalScrollbar.scrollLeft = 120;
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBe(120);
      expect(component.getScrollLeft()).toBe(120);

      editor.setText('a\n'.repeat(15));
      await component.getNextUpdatePromise();
      expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(0);
      expect(getHorizontalScrollbarHeight(component)).toBe(0);
      expect(verticalScrollbar.style.visibility).toBe('');
      expect(horizontalScrollbar.style.visibility).toBe('hidden');

      editor.setText('a'.repeat(100));
      await component.getNextUpdatePromise();
      expect(getVerticalScrollbarWidth(component)).toBe(0);
      expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(0);
      expect(verticalScrollbar.style.visibility).toBe('hidden');
      expect(horizontalScrollbar.style.visibility).toBe('');

      editor.setText('');
      await component.getNextUpdatePromise();
      expect(getVerticalScrollbarWidth(component)).toBe(0);
      expect(getHorizontalScrollbarHeight(component)).toBe(0);
      expect(verticalScrollbar.style.visibility).toBe('hidden');
      expect(horizontalScrollbar.style.visibility).toBe('hidden');
    });

    describe('when scrollbar styles change or the editor element is detached and then reattached', () => {
      it('updates the bottom/right of dummy scrollbars and client height/width measurements', async () => {
        const { component, element, editor } = buildComponent({
          height: 100,
          width: 100
        });
        expect(getHorizontalScrollbarHeight(component)).toBeGreaterThan(10);
        expect(getVerticalScrollbarWidth(component)).toBeGreaterThan(10);
        setScrollTop(component, 20);
        setScrollLeft(component, 10);
        await component.getNextUpdatePromise();

        // Updating scrollbar styles.
        const style = document.createElement('style');
        style.textContent =
          '::-webkit-scrollbar { height: 10px; width: 10px; }';
        jasmine.attachToDOM(style);
        TextEditor.didUpdateScrollbarStyles();
        await component.getNextUpdatePromise();

        expect(getHorizontalScrollbarHeight(component)).toBeNear(10);
        expect(getVerticalScrollbarWidth(component)).toBeNear(10);
        expect(
          component.refs.horizontalScrollbar.element.style.right
        ).toHaveNearPixels('10px');
        expect(
          component.refs.verticalScrollbar.element.style.bottom
        ).toHaveNearPixels('10px');
        expect(component.refs.horizontalScrollbar.element.scrollLeft).toBeNear(
          10
        );
        expect(component.refs.verticalScrollbar.element.scrollTop).toBeNear(20);
        expect(component.getScrollContainerClientHeight()).toBeNear(100 - 10);
        expect(component.getScrollContainerClientWidth()).toBeNear(
          100 - component.getGutterContainerWidth() - 10
        );

        // Detaching and re-attaching the editor element.
        element.remove();
        jasmine.attachToDOM(element);

        expect(getHorizontalScrollbarHeight(component)).toBeNear(10);
        expect(getVerticalScrollbarWidth(component)).toBeNear(10);
        expect(
          component.refs.horizontalScrollbar.element.style.right
        ).toHaveNearPixels('10px');
        expect(
          component.refs.verticalScrollbar.element.style.bottom
        ).toHaveNearPixels('10px');
        expect(component.refs.horizontalScrollbar.element.scrollLeft).toBeNear(
          10
        );
        expect(component.refs.verticalScrollbar.element.scrollTop).toBeNear(20);
        expect(component.getScrollContainerClientHeight()).toBeNear(100 - 10);
        expect(component.getScrollContainerClientWidth()).toBeNear(
          100 - component.getGutterContainerWidth() - 10
        );

        // Ensure we don't throw an error trying to remeasure non-existent scrollbars for mini editors.
        await editor.update({ mini: true });
        TextEditor.didUpdateScrollbarStyles();
        component.scheduleUpdate();
        await component.getNextUpdatePromise();
      });
    });

    it('renders cursors within the visible row range', async () => {
      const { component, element, editor } = buildComponent({
        height: 40,
        rowsPerTile: 2
      });
      await setScrollTop(component, 100);

      expect(component.getRenderedStartRow()).toBe(4);
      expect(component.getRenderedEndRow()).toBe(10);

      editor.setCursorScreenPosition([0, 0], { autoscroll: false }); // out of view
      editor.addCursorAtScreenPosition([2, 2], { autoscroll: false }); // out of view
      editor.addCursorAtScreenPosition([4, 0], { autoscroll: false }); // line start
      editor.addCursorAtScreenPosition([4, 4], { autoscroll: false }); // at token boundary
      editor.addCursorAtScreenPosition([4, 6], { autoscroll: false }); // within token
      editor.addCursorAtScreenPosition([5, Infinity], { autoscroll: false }); // line end
      editor.addCursorAtScreenPosition([10, 2], { autoscroll: false }); // out of view
      await component.getNextUpdatePromise();

      let cursorNodes = Array.from(element.querySelectorAll('.cursor'));
      expect(cursorNodes.length).toBe(4);
      verifyCursorPosition(component, cursorNodes[0], 4, 0);
      verifyCursorPosition(component, cursorNodes[1], 4, 4);
      verifyCursorPosition(component, cursorNodes[2], 4, 6);
      verifyCursorPosition(component, cursorNodes[3], 5, 30);

      editor.setCursorScreenPosition([8, 11], { autoscroll: false });
      await component.getNextUpdatePromise();

      cursorNodes = Array.from(element.querySelectorAll('.cursor'));
      expect(cursorNodes.length).toBe(1);
      verifyCursorPosition(component, cursorNodes[0], 8, 11);

      editor.setCursorScreenPosition([0, 0], { autoscroll: false });
      await component.getNextUpdatePromise();

      cursorNodes = Array.from(element.querySelectorAll('.cursor'));
      expect(cursorNodes.length).toBe(0);

      editor.setSelectedScreenRange([[8, 0], [12, 0]], { autoscroll: false });
      await component.getNextUpdatePromise();
      cursorNodes = Array.from(element.querySelectorAll('.cursor'));
      expect(cursorNodes.length).toBe(0);
    });

    it('hides cursors with non-empty selections when showCursorOnSelection is false', async () => {
      const { component, element, editor } = buildComponent();
      editor.setSelectedScreenRanges([[[0, 0], [0, 3]], [[1, 0], [1, 0]]]);
      await component.getNextUpdatePromise();
      {
        const cursorNodes = Array.from(element.querySelectorAll('.cursor'));
        expect(cursorNodes.length).toBe(2);
        verifyCursorPosition(component, cursorNodes[0], 0, 3);
        verifyCursorPosition(component, cursorNodes[1], 1, 0);
      }

      editor.update({ showCursorOnSelection: false });
      await component.getNextUpdatePromise();
      {
        const cursorNodes = Array.from(element.querySelectorAll('.cursor'));
        expect(cursorNodes.length).toBe(1);
        verifyCursorPosition(component, cursorNodes[0], 1, 0);
      }

      editor.setSelectedScreenRanges([[[0, 0], [0, 3]], [[1, 0], [1, 4]]]);
      await component.getNextUpdatePromise();
      {
        const cursorNodes = Array.from(element.querySelectorAll('.cursor'));
        expect(cursorNodes.length).toBe(0);
      }
    });

    it('blinks cursors when the editor is focused and the cursors are not moving', async () => {
      assertDocumentFocused();
      const { component, element, editor } = buildComponent();
      component.props.cursorBlinkPeriod = 30;
      component.props.cursorBlinkResumeDelay = 30;
      editor.addCursorAtScreenPosition([1, 0]);

      element.focus();
      await component.getNextUpdatePromise();
      const [cursor1, cursor2] = element.querySelectorAll('.cursor');

      await conditionPromise(
        () =>
          getComputedStyle(cursor1).opacity === '1' &&
          getComputedStyle(cursor2).opacity === '1'
      );
      await conditionPromise(
        () =>
          getComputedStyle(cursor1).opacity === '0' &&
          getComputedStyle(cursor2).opacity === '0'
      );
      await conditionPromise(
        () =>
          getComputedStyle(cursor1).opacity === '1' &&
          getComputedStyle(cursor2).opacity === '1'
      );

      editor.moveRight();
      await component.getNextUpdatePromise();

      expect(getComputedStyle(cursor1).opacity).toBe('1');
      expect(getComputedStyle(cursor2).opacity).toBe('1');
    });

    it('gives cursors at the end of lines the width of an "x" character', async () => {
      const { component, element, editor } = buildComponent();
      editor.setText('abcde');
      await setEditorWidthInCharacters(component, 5.5);

      editor.setCursorScreenPosition([0, Infinity]);
      await component.getNextUpdatePromise();
      expect(element.querySelector('.cursor').offsetWidth).toBe(
        Math.round(component.getBaseCharacterWidth())
      );

      // Clip cursor width when soft-wrap is on and the cursor is at the end of
      // the line. This prevents the parent tile from disabling sub-pixel
      // anti-aliasing. For some reason, adding overflow: hidden to the cursor
      // container doesn't solve this issue so we're adding this workaround instead.
      editor.setSoftWrapped(true);
      await component.getNextUpdatePromise();
      expect(element.querySelector('.cursor').offsetWidth).toBeLessThan(
        Math.round(component.getBaseCharacterWidth())
      );
    });

    it('positions and sizes cursors correctly when they are located next to a fold marker', async () => {
      const { component, element, editor } = buildComponent();
      editor.foldBufferRange([[0, 3], [0, 6]]);

      editor.setCursorScreenPosition([0, 3]);
      await component.getNextUpdatePromise();
      verifyCursorPosition(component, element.querySelector('.cursor'), 0, 3);

      editor.setCursorScreenPosition([0, 4]);
      await component.getNextUpdatePromise();
      verifyCursorPosition(component, element.querySelector('.cursor'), 0, 4);
    });

    it('positions cursors and placeholder text correctly when the lines container has a margin and/or is padded', async () => {
      const { component, element, editor } = buildComponent({
        placeholderText: 'testing'
      });

      component.refs.lineTiles.style.marginLeft = '10px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();

      editor.setCursorBufferPosition([0, 3]);
      await component.getNextUpdatePromise();
      verifyCursorPosition(component, element.querySelector('.cursor'), 0, 3);

      editor.setCursorScreenPosition([1, 0]);
      await component.getNextUpdatePromise();
      verifyCursorPosition(component, element.querySelector('.cursor'), 1, 0);

      component.refs.lineTiles.style.paddingTop = '5px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      verifyCursorPosition(component, element.querySelector('.cursor'), 1, 0);

      editor.setCursorScreenPosition([2, 2]);
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      verifyCursorPosition(component, element.querySelector('.cursor'), 2, 2);

      editor.setText('');
      await component.getNextUpdatePromise();

      const placeholderTextLeft = element
        .querySelector('.placeholder-text')
        .getBoundingClientRect().left;
      const linesLeft = component.refs.lineTiles.getBoundingClientRect().left;
      expect(placeholderTextLeft).toBe(linesLeft);
    });

    it('places the hidden input element at the location of the last cursor if it is visible', async () => {
      const { component, editor } = buildComponent({
        height: 60,
        width: 120,
        rowsPerTile: 2
      });
      const { hiddenInput } = component.refs.cursorsAndInput.refs;
      setScrollTop(component, 100);
      await setScrollLeft(component, 40);

      expect(component.getRenderedStartRow()).toBe(4);
      expect(component.getRenderedEndRow()).toBe(10);

      // When out of view, the hidden input is positioned at 0, 0
      expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
      expect(hiddenInput.offsetTop).toBe(0);
      expect(hiddenInput.offsetLeft).toBe(0);

      // Otherwise it is positioned at the last cursor position
      editor.addCursorAtScreenPosition([7, 4]);
      await component.getNextUpdatePromise();
      expect(hiddenInput.getBoundingClientRect().top).toBe(
        clientTopForLine(component, 7)
      );
      expect(Math.round(hiddenInput.getBoundingClientRect().left)).toBeNear(
        clientLeftForCharacter(component, 7, 4)
      );
    });

    it('soft wraps lines based on the content width when soft wrap is enabled', async () => {
      let baseCharacterWidth, gutterContainerWidth;
      {
        const { component, editor } = buildComponent();
        baseCharacterWidth = component.getBaseCharacterWidth();
        gutterContainerWidth = component.getGutterContainerWidth();
        editor.destroy();
      }

      const { component, element, editor } = buildComponent({
        width: gutterContainerWidth + baseCharacterWidth * 55,
        attach: false
      });
      editor.setSoftWrapped(true);
      jasmine.attachToDOM(element);

      expect(getEditorWidthInBaseCharacters(component)).toBe(55);
      expect(lineNodeForScreenRow(component, 3).textContent).toBe(
        '    var pivot = items.shift(), current, left = [], '
      );
      expect(lineNodeForScreenRow(component, 4).textContent).toBe(
        '    right = [];'
      );

      const { scrollContainer } = component.refs;
      expect(scrollContainer.clientWidth).toBe(scrollContainer.scrollWidth);
    });

    it('correctly forces the display layer to index visible rows when resizing (regression)', async () => {
      const text = 'a'.repeat(30) + '\n' + 'b'.repeat(1000);
      const { component, element, editor } = buildComponent({
        height: 300,
        width: 800,
        attach: false,
        text
      });
      editor.setSoftWrapped(true);
      jasmine.attachToDOM(element);

      element.style.width = 200 + 'px';
      await component.getNextUpdatePromise();
      expect(queryOnScreenLineElements(element).length).toBe(24);
    });

    it('decorates the line numbers of folded lines', async () => {
      const { component, editor } = buildComponent();
      editor.foldBufferRow(1);
      await component.getNextUpdatePromise();
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('folded')
      ).toBe(true);
    });

    it('makes lines at least as wide as the scrollContainer', async () => {
      const { component, element, editor } = buildComponent();
      const { scrollContainer } = component.refs;
      editor.setText('a');
      await component.getNextUpdatePromise();

      expect(element.querySelector('.line').offsetWidth).toBe(
        scrollContainer.offsetWidth - verticalScrollbarWidth
      );
    });

    it('resizes based on the content when the autoHeight and/or autoWidth options are true', async () => {
      const { component, element, editor } = buildComponent({
        autoHeight: true,
        autoWidth: true
      });
      const editorPadding = 3;
      element.style.padding = editorPadding + 'px';
      const initialWidth = element.offsetWidth;
      const initialHeight = element.offsetHeight;
      expect(initialWidth).toBe(
        component.getGutterContainerWidth() +
          component.getContentWidth() +
          verticalScrollbarWidth +
          2 * editorPadding
      );
      expect(initialHeight).toBeNear(
        component.getContentHeight() +
          horizontalScrollbarHeight +
          2 * editorPadding
      );

      // When autoWidth is enabled, width adjusts to content
      editor.setCursorScreenPosition([6, Infinity]);
      editor.insertText('x'.repeat(50));
      await component.getNextUpdatePromise();
      expect(element.offsetWidth).toBe(
        component.getGutterContainerWidth() +
          component.getContentWidth() +
          verticalScrollbarWidth +
          2 * editorPadding
      );
      expect(element.offsetWidth).toBeGreaterThan(initialWidth);

      // When autoHeight is enabled, height adjusts to content
      editor.insertText('\n'.repeat(5));
      await component.getNextUpdatePromise();
      expect(element.offsetHeight).toBeNear(
        component.getContentHeight() +
          horizontalScrollbarHeight +
          2 * editorPadding
      );
      expect(element.offsetHeight).toBeGreaterThan(initialHeight);
    });

    it('does not render the line number gutter at all if the isLineNumberGutterVisible parameter is false', () => {
      const { element } = buildComponent({
        lineNumberGutterVisible: false
      });
      expect(element.querySelector('.line-number')).toBe(null);
    });

    it('does not render the line numbers but still renders the line number gutter if showLineNumbers is false', async () => {
      function checkScrollContainerLeft(component) {
        const { scrollContainer, gutterContainer } = component.refs;
        expect(scrollContainer.getBoundingClientRect().left).toBeNear(
          Math.round(gutterContainer.element.getBoundingClientRect().right)
        );
      }

      const { component, element, editor } = buildComponent({
        showLineNumbers: false
      });
      expect(
        Array.from(element.querySelectorAll('.line-number')).every(
          e => e.textContent === ''
        )
      ).toBe(true);
      checkScrollContainerLeft(component);

      await editor.update({ showLineNumbers: true });
      expect(
        Array.from(element.querySelectorAll('.line-number')).map(
          e => e.textContent
        )
      ).toEqual([
        '00',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        '11',
        '12',
        '13'
      ]);
      checkScrollContainerLeft(component);

      await editor.update({ showLineNumbers: false });
      expect(
        Array.from(element.querySelectorAll('.line-number')).every(
          e => e.textContent === ''
        )
      ).toBe(true);
      checkScrollContainerLeft(component);
    });

    it('supports the placeholderText parameter', () => {
      const placeholderText = 'Placeholder Test';
      const { element } = buildComponent({ placeholderText, text: '' });
      expect(element.textContent).toContain(placeholderText);
    });

    it('adds the data-grammar attribute and updates it when the grammar changes', async () => {
      await atom.packages.activatePackage('language-javascript');

      const { editor, element, component } = buildComponent();
      expect(element.dataset.grammar).toBe('text plain null-grammar');

      atom.grammars.assignLanguageMode(editor.getBuffer(), 'source.js');
      await component.getNextUpdatePromise();
      expect(element.dataset.grammar).toBe('source js');
    });

    it('adds the data-encoding attribute and updates it when the encoding changes', async () => {
      const { editor, element, component } = buildComponent();
      expect(element.dataset.encoding).toBe('utf8');

      editor.setEncoding('ascii');
      await component.getNextUpdatePromise();
      expect(element.dataset.encoding).toBe('ascii');
    });

    it('adds the has-selection class when the editor has a non-empty selection', async () => {
      const { editor, element, component } = buildComponent();
      expect(element.classList.contains('has-selection')).toBe(false);

      editor.setSelectedBufferRanges([[[0, 0], [0, 0]], [[1, 0], [1, 10]]]);
      await component.getNextUpdatePromise();
      expect(element.classList.contains('has-selection')).toBe(true);

      editor.setSelectedBufferRanges([[[0, 0], [0, 0]], [[1, 0], [1, 0]]]);
      await component.getNextUpdatePromise();
      expect(element.classList.contains('has-selection')).toBe(false);
    });

    it('assigns buffer-row and screen-row to each line number as data fields', async () => {
      const { editor, element, component } = buildComponent();
      editor.setSoftWrapped(true);
      await component.getNextUpdatePromise();
      await setEditorWidthInCharacters(component, 40);
      {
        const bufferRows = queryOnScreenLineNumberElements(element).map(
          e => e.dataset.bufferRow
        );
        const screenRows = queryOnScreenLineNumberElements(element).map(
          e => e.dataset.screenRow
        );
        expect(bufferRows).toEqual([
          '0',
          '1',
          '2',
          '2',
          '3',
          '3',
          '4',
          '5',
          '6',
          '6',
          '6',
          '7',
          '8',
          '8',
          '8',
          '9',
          '10',
          '11',
          '11',
          '12'
        ]);
        expect(screenRows).toEqual([
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '10',
          '11',
          '12',
          '13',
          '14',
          '15',
          '16',
          '17',
          '18',
          '19'
        ]);
      }

      editor.getBuffer().insert([2, 0], '\n');
      await component.getNextUpdatePromise();
      {
        const bufferRows = queryOnScreenLineNumberElements(element).map(
          e => e.dataset.bufferRow
        );
        const screenRows = queryOnScreenLineNumberElements(element).map(
          e => e.dataset.screenRow
        );
        expect(bufferRows).toEqual([
          '0',
          '1',
          '2',
          '3',
          '3',
          '4',
          '4',
          '5',
          '6',
          '7',
          '7',
          '7',
          '8',
          '9',
          '9',
          '9',
          '10',
          '11',
          '12',
          '12',
          '13'
        ]);
        expect(screenRows).toEqual([
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '10',
          '11',
          '12',
          '13',
          '14',
          '15',
          '16',
          '17',
          '18',
          '19',
          '20'
        ]);
      }
    });

    it('does not blow away class names added to the element by packages when changing the class name', async () => {
      assertDocumentFocused();
      const { component, element } = buildComponent();
      element.classList.add('a', 'b');
      expect(element.className).toBe('editor a b');
      element.focus();
      await component.getNextUpdatePromise();
      expect(element.className).toBe('editor a b is-focused');
      document.body.focus();
      await component.getNextUpdatePromise();
      expect(element.className).toBe('editor a b');
    });

    it('does not blow away class names managed by the component when packages change the element class name', async () => {
      assertDocumentFocused();
      const { component, element } = buildComponent({ mini: true });
      element.classList.add('a', 'b');
      element.focus();
      await component.getNextUpdatePromise();
      expect(element.className).toBe('editor mini a b is-focused');
      element.className = 'a c d';
      await component.getNextUpdatePromise();
      expect(element.className).toBe('a c d editor is-focused mini');
    });

    it('ignores resize events when the editor is hidden', async () => {
      const { component, element } = buildComponent({
        autoHeight: false
      });
      element.style.height = 5 * component.getLineHeight() + 'px';
      await component.getNextUpdatePromise();
      const originalClientContainerHeight = component.getClientContainerHeight();
      const originalGutterContainerWidth = component.getGutterContainerWidth();
      const originalLineNumberGutterWidth = component.getLineNumberGutterWidth();
      expect(originalClientContainerHeight).toBeGreaterThan(0);
      expect(originalGutterContainerWidth).toBeGreaterThan(0);
      expect(originalLineNumberGutterWidth).toBeGreaterThan(0);

      element.style.display = 'none';
      // In production, resize events are triggered before the intersection
      // observer detects the editor's visibility has changed. In tests, we are
      // unable to reproduce this scenario and so we simulate them.
      expect(component.visible).toBe(true);
      component.didResize();
      component.didResizeGutterContainer();
      expect(component.getClientContainerHeight()).toBe(
        originalClientContainerHeight
      );
      expect(component.getGutterContainerWidth()).toBe(
        originalGutterContainerWidth
      );
      expect(component.getLineNumberGutterWidth()).toBe(
        originalLineNumberGutterWidth
      );

      // Ensure measurements stay the same after receiving the intersection
      // observer events.
      await conditionPromise(() => !component.visible);
      expect(component.getClientContainerHeight()).toBe(
        originalClientContainerHeight
      );
      expect(component.getGutterContainerWidth()).toBe(
        originalGutterContainerWidth
      );
      expect(component.getLineNumberGutterWidth()).toBe(
        originalLineNumberGutterWidth
      );
    });

    describe('randomized tests', () => {
      let originalTimeout;

      beforeEach(() => {
        originalTimeout = jasmine.getEnv().defaultTimeoutInterval;
        jasmine.getEnv().defaultTimeoutInterval = 60 * 1000;
      });

      afterEach(() => {
        jasmine.getEnv().defaultTimeoutInterval = originalTimeout;
      });

      it('renders the visible rows correctly after randomly mutating the editor', async () => {
        const initialSeed = Date.now();
        for (var i = 0; i < 20; i++) {
          let seed = initialSeed + i;
          // seed = 1520247533732
          const failureMessage = 'Randomized test failed with seed: ' + seed;
          const random = Random(seed);

          const rowsPerTile = random.intBetween(1, 6);
          const { component, element, editor } = buildComponent({
            rowsPerTile,
            autoHeight: false
          });
          editor.setSoftWrapped(Boolean(random(2)));
          await setEditorWidthInCharacters(component, random(20));
          await setEditorHeightInLines(component, random(10));

          element.style.fontSize = random(20) + 'px';
          element.style.lineHeight = random.floatBetween(0.1, 2.0);
          TextEditor.didUpdateStyles();
          await component.getNextUpdatePromise();

          element.focus();

          for (var j = 0; j < 5; j++) {
            const k = random(100);
            const range = getRandomBufferRange(random, editor.buffer);

            if (k < 10) {
              editor.setSoftWrapped(!editor.isSoftWrapped());
            } else if (k < 15) {
              if (random(2)) setEditorWidthInCharacters(component, random(20));
              if (random(2)) setEditorHeightInLines(component, random(10));
            } else if (k < 40) {
              editor.setSelectedBufferRange(range);
              editor.backspace();
            } else if (k < 80) {
              const linesToInsert = buildRandomLines(random, 5);
              editor.setCursorBufferPosition(range.start);
              editor.insertText(linesToInsert);
            } else if (k < 90) {
              if (random(2)) {
                editor.foldBufferRange(range);
              } else {
                editor.destroyFoldsIntersectingBufferRange(range);
              }
            } else if (k < 95) {
              editor.setSelectedBufferRange(range);
            } else {
              if (random(2)) {
                component.setScrollTop(random(component.getScrollHeight()));
              }
              if (random(2)) {
                component.setScrollLeft(random(component.getScrollWidth()));
              }
            }

            component.scheduleUpdate();
            await component.getNextUpdatePromise();

            const renderedLines = queryOnScreenLineElements(element).sort(
              (a, b) => a.dataset.screenRow - b.dataset.screenRow
            );
            const renderedLineNumbers = queryOnScreenLineNumberElements(
              element
            ).sort((a, b) => a.dataset.screenRow - b.dataset.screenRow);
            const renderedStartRow = component.getRenderedStartRow();
            const expectedLines = editor.displayLayer.getScreenLines(
              renderedStartRow,
              component.getRenderedEndRow()
            );

            expect(renderedLines.length).toBe(
              expectedLines.length,
              failureMessage
            );
            expect(renderedLineNumbers.length).toBe(
              expectedLines.length,
              failureMessage
            );
            for (let k = 0; k < renderedLines.length; k++) {
              const expectedLine = expectedLines[k];
              const expectedText = expectedLine.lineText || ' ';

              const renderedLine = renderedLines[k];
              const renderedLineNumber = renderedLineNumbers[k];
              let renderedText = renderedLine.textContent;
              // We append zero width NBSPs after folds at the end of the
              // line in order to support measurement.
              if (expectedText.endsWith(editor.displayLayer.foldCharacter)) {
                renderedText = renderedText.substring(
                  0,
                  renderedText.length - 1
                );
              }

              expect(renderedText).toBe(expectedText, failureMessage);
              expect(parseInt(renderedLine.dataset.screenRow)).toBe(
                renderedStartRow + k,
                failureMessage
              );
              expect(parseInt(renderedLineNumber.dataset.screenRow)).toBe(
                renderedStartRow + k,
                failureMessage
              );
            }
          }

          element.remove();
          editor.destroy();
        }
      });
    });
  });

  describe('mini editors', () => {
    it('adds the mini attribute and class even when the element is not attached', () => {
      {
        const { element } = buildComponent({ mini: true });
        expect(element.hasAttribute('mini')).toBe(true);
        expect(element.classList.contains('mini')).toBe(true);
      }

      {
        const { element } = buildComponent({
          mini: true,
          attach: false
        });
        expect(element.hasAttribute('mini')).toBe(true);
        expect(element.classList.contains('mini')).toBe(true);
      }
    });

    it('does not render the gutter container', () => {
      const { component, element } = buildComponent({ mini: true });
      expect(component.refs.gutterContainer).toBeUndefined();
      expect(element.querySelector('gutter-container')).toBeNull();
    });

    it('does not render line decorations for the cursor line', async () => {
      const { component, element, editor } = buildComponent({ mini: true });
      expect(
        element.querySelector('.line').classList.contains('cursor-line')
      ).toBe(false);

      editor.update({ mini: false });
      await component.getNextUpdatePromise();
      expect(
        element.querySelector('.line').classList.contains('cursor-line')
      ).toBe(true);

      editor.update({ mini: true });
      await component.getNextUpdatePromise();
      expect(
        element.querySelector('.line').classList.contains('cursor-line')
      ).toBe(false);
    });

    it('does not render scrollbars', async () => {
      const { component, editor } = buildComponent({
        mini: true,
        autoHeight: false
      });
      await setEditorWidthInCharacters(component, 10);

      editor.setText('x'.repeat(20) + 'y'.repeat(20));
      await component.getNextUpdatePromise();

      expect(component.canScrollVertically()).toBe(false);
      expect(component.canScrollHorizontally()).toBe(false);
      expect(component.refs.horizontalScrollbar).toBeUndefined();
      expect(component.refs.verticalScrollbar).toBeUndefined();
    });
  });

  describe('focus', () => {
    beforeEach(() => {
      assertDocumentFocused();
    });

    it('focuses the hidden input element and adds the is-focused class when focused', async () => {
      const { component, element } = buildComponent();
      const { hiddenInput } = component.refs.cursorsAndInput.refs;

      expect(document.activeElement).not.toBe(hiddenInput);
      element.focus();
      expect(document.activeElement).toBe(hiddenInput);
      await component.getNextUpdatePromise();
      expect(element.classList.contains('is-focused')).toBe(true);

      element.focus(); // focusing back to the element does not blur
      expect(document.activeElement).toBe(hiddenInput);
      expect(element.classList.contains('is-focused')).toBe(true);

      document.body.focus();
      expect(document.activeElement).not.toBe(hiddenInput);
      await component.getNextUpdatePromise();
      expect(element.classList.contains('is-focused')).toBe(false);
    });

    it('updates the component when the hidden input is focused directly', async () => {
      const { component, element } = buildComponent();
      const { hiddenInput } = component.refs.cursorsAndInput.refs;
      expect(element.classList.contains('is-focused')).toBe(false);
      expect(document.activeElement).not.toBe(hiddenInput);

      hiddenInput.focus();
      await component.getNextUpdatePromise();
      expect(element.classList.contains('is-focused')).toBe(true);
    });

    it('gracefully handles a focus event that occurs prior to the attachedCallback of the element', () => {
      const { component, element } = buildComponent({ attach: false });
      const parent = document.createElement(
        'text-editor-component-test-element'
      );
      parent.appendChild(element);
      parent.didAttach = () => element.focus();
      jasmine.attachToDOM(parent);
      expect(document.activeElement).toBe(
        component.refs.cursorsAndInput.refs.hiddenInput
      );
    });

    it('gracefully handles a focus event that occurs prior to detecting the element has become visible', async () => {
      const { component, element } = buildComponent({ attach: false });
      element.style.display = 'none';
      jasmine.attachToDOM(element);
      element.style.display = 'block';
      element.focus();
      await component.getNextUpdatePromise();

      expect(document.activeElement).toBe(
        component.refs.cursorsAndInput.refs.hiddenInput
      );
    });

    it('emits blur events only when focus shifts to something other than the editor itself or its hidden input', () => {
      const { element } = buildComponent();

      let blurEventCount = 0;
      element.addEventListener('blur', () => blurEventCount++);

      element.focus();
      expect(blurEventCount).toBe(0);
      element.focus();
      expect(blurEventCount).toBe(0);
      document.body.focus();
      expect(blurEventCount).toBe(1);
    });
  });

  describe('autoscroll', () => {
    it('automatically scrolls vertically when the requested range is within the vertical scroll margin of the top or bottom', async () => {
      const { component, editor } = buildComponent({
        height: 120 + horizontalScrollbarHeight
      });
      expect(component.getLastVisibleRow()).toBe(7);

      editor.scrollToScreenRange([[4, 0], [6, 0]]);
      await component.getNextUpdatePromise();
      expect(component.getScrollBottom()).toBeNear(
        (6 + 1 + editor.verticalScrollMargin) * component.getLineHeight()
      );

      editor.scrollToScreenPosition([8, 0]);
      await component.getNextUpdatePromise();
      expect(component.getScrollBottom()).toBeNear(
        (8 + 1 + editor.verticalScrollMargin) *
          component.measurements.lineHeight
      );

      editor.scrollToScreenPosition([3, 0]);
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBeNear(
        (3 - editor.verticalScrollMargin) * component.measurements.lineHeight
      );

      editor.scrollToScreenPosition([2, 0]);
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBe(0);
    });

    it('does not vertically autoscroll by more than half of the visible lines if the editor is shorter than twice the scroll margin', async () => {
      const { component, element, editor } = buildComponent({
        autoHeight: false
      });
      element.style.height =
        5.5 * component.measurements.lineHeight +
        horizontalScrollbarHeight +
        'px';
      await component.getNextUpdatePromise();
      expect(component.getLastVisibleRow()).toBe(5);
      const scrollMarginInLines = 2;

      editor.scrollToScreenPosition([6, 0]);
      await component.getNextUpdatePromise();
      expect(component.getScrollBottom()).toBeNear(
        (6 + 1 + scrollMarginInLines) * component.measurements.lineHeight
      );

      editor.scrollToScreenPosition([6, 4]);
      await component.getNextUpdatePromise();
      expect(component.getScrollBottom()).toBeNear(
        (6 + 1 + scrollMarginInLines) * component.measurements.lineHeight
      );

      editor.scrollToScreenRange([[4, 4], [6, 4]]);
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBeNear(
        (4 - scrollMarginInLines) * component.measurements.lineHeight
      );

      editor.scrollToScreenRange([[4, 4], [6, 4]], { reversed: false });
      await component.getNextUpdatePromise();
      expect(component.getScrollBottom()).toBeNear(
        (6 + 1 + scrollMarginInLines) * component.measurements.lineHeight
      );
    });

    it('autoscrolls the given range to the center of the screen if the `center` option is true', async () => {
      const { component, editor } = buildComponent({ height: 50 });
      expect(component.getLastVisibleRow()).toBe(2);

      editor.scrollToScreenRange([[4, 0], [6, 0]], { center: true });
      await component.getNextUpdatePromise();

      const actualScrollCenter =
        (component.getScrollTop() + component.getScrollBottom()) / 2;
      const expectedScrollCenter = ((4 + 7) / 2) * component.getLineHeight();
      expect(actualScrollCenter).toBeCloseTo(expectedScrollCenter, 0);
    });

    it('automatically scrolls horizontally when the requested range is within the horizontal scroll margin of the right edge of the gutter or right edge of the scroll container', async () => {
      const { component, element, editor } = buildComponent();
      element.style.width =
        component.getGutterContainerWidth() +
        3 *
          editor.horizontalScrollMargin *
          component.measurements.baseCharacterWidth +
        'px';
      await component.getNextUpdatePromise();

      editor.scrollToScreenRange([[1, 12], [2, 28]]);
      await component.getNextUpdatePromise();
      let expectedScrollLeft =
        clientLeftForCharacter(component, 1, 12) -
        lineNodeForScreenRow(component, 1).getBoundingClientRect().left -
        editor.horizontalScrollMargin *
          component.measurements.baseCharacterWidth;
      expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);

      editor.scrollToScreenRange([[1, 12], [2, 28]], { reversed: false });
      await component.getNextUpdatePromise();
      expectedScrollLeft =
        component.getGutterContainerWidth() +
        clientLeftForCharacter(component, 2, 28) -
        lineNodeForScreenRow(component, 2).getBoundingClientRect().left +
        editor.horizontalScrollMargin *
          component.measurements.baseCharacterWidth -
        component.getScrollContainerClientWidth();
      expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
    });

    it('does not horizontally autoscroll by more than half of the visible "base-width" characters if the editor is narrower than twice the scroll margin', async () => {
      const { component, editor } = buildComponent({ autoHeight: false });
      await setEditorWidthInCharacters(
        component,
        1.5 * editor.horizontalScrollMargin
      );
      const editorWidthInChars =
        component.getScrollContainerClientWidth() /
        component.getBaseCharacterWidth();
      expect(Math.round(editorWidthInChars)).toBe(9);

      editor.scrollToScreenRange([[6, 10], [6, 15]]);
      await component.getNextUpdatePromise();
      let expectedScrollLeft = Math.floor(
        clientLeftForCharacter(component, 6, 10) -
          lineNodeForScreenRow(component, 1).getBoundingClientRect().left -
          Math.floor((editorWidthInChars - 1) / 2) *
            component.getBaseCharacterWidth()
      );
      expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
    });

    it('correctly autoscrolls after inserting a line that exceeds the current content width', async () => {
      const { component, element, editor } = buildComponent();
      element.style.width =
        component.getGutterContainerWidth() +
        component.getContentWidth() +
        'px';
      await component.getNextUpdatePromise();

      editor.setCursorScreenPosition([0, Infinity]);
      editor.insertText('x'.repeat(100));
      await component.getNextUpdatePromise();

      expect(component.getScrollLeft()).toBeNear(
        component.getScrollWidth() - component.getScrollContainerClientWidth()
      );
    });

    it('does not try to measure lines that do not exist when the animation frame is delivered', async () => {
      const { component, editor } = buildComponent({
        autoHeight: false,
        height: 30,
        rowsPerTile: 2
      });
      editor.scrollToBufferPosition([11, 5]);
      editor.getBuffer().deleteRows(11, 12);
      await component.getNextUpdatePromise();
      expect(component.getScrollBottom()).toBeNear(
        (10 + 1) * component.measurements.lineHeight
      );
    });

    it('accounts for the presence of horizontal scrollbars that appear during the same frame as the autoscroll', async () => {
      const { component, element, editor } = buildComponent({
        autoHeight: false
      });
      element.style.height = component.getContentHeight() / 2 + 'px';
      element.style.width = component.getScrollWidth() + 'px';
      await component.getNextUpdatePromise();

      editor.setCursorScreenPosition([10, Infinity]);
      editor.insertText('\n\n' + 'x'.repeat(100));
      await component.getNextUpdatePromise();

      expect(component.getScrollTop()).toBeNear(
        component.getScrollHeight() - component.getScrollContainerClientHeight()
      );
      expect(component.getScrollLeft()).toBeNear(
        component.getScrollWidth() - component.getScrollContainerClientWidth()
      );

      // Scrolling to the top should not throw an error. This failed
      // previously due to horizontalPositionsToMeasure not being empty after
      // autoscrolling vertically to account for the horizontal scrollbar.
      spyOn(window, 'onerror');
      await setScrollTop(component, 0);
      expect(window.onerror).not.toHaveBeenCalled();
    });
  });

  describe('logical scroll positions', () => {
    it('allows the scrollTop to be changed and queried in terms of rows via setScrollTopRow and getScrollTopRow', () => {
      const { component, element } = buildComponent({
        attach: false,
        height: 80
      });

      // Caches the scrollTopRow if we don't have measurements
      component.setScrollTopRow(6);
      expect(component.getScrollTopRow()).toBe(6);

      // Assigns the scrollTop based on the logical position when attached
      jasmine.attachToDOM(element);
      const expectedScrollTop = Math.round(6 * component.getLineHeight());
      expect(component.getScrollTopRow()).toBeNear(6);
      expect(component.getScrollTop()).toBeNear(expectedScrollTop);
      expect(component.refs.content.style.transform).toBe(
        `translate(0px, -${expectedScrollTop}px)`
      );

      // Allows the scrollTopRow to be updated while attached
      component.setScrollTopRow(4);
      expect(component.getScrollTopRow()).toBeNear(4);
      expect(component.getScrollTop()).toBeNear(
        Math.round(4 * component.getLineHeight())
      );

      // Preserves the scrollTopRow when detached
      element.remove();
      expect(component.getScrollTopRow()).toBeNear(4);
      expect(component.getScrollTop()).toBeNear(
        Math.round(4 * component.getLineHeight())
      );

      component.setScrollTopRow(6);
      expect(component.getScrollTopRow()).toBeNear(6);
      expect(component.getScrollTop()).toBeNear(
        Math.round(6 * component.getLineHeight())
      );

      jasmine.attachToDOM(element);
      element.style.height = '60px';
      expect(component.getScrollTopRow()).toBeNear(6);
      expect(component.getScrollTop()).toBeNear(
        Math.round(6 * component.getLineHeight())
      );
    });

    it('allows the scrollLeft to be changed and queried in terms of base character columns via setScrollLeftColumn and getScrollLeftColumn', () => {
      const { component, element } = buildComponent({
        attach: false,
        width: 80
      });

      // Caches the scrollTopRow if we don't have measurements
      component.setScrollLeftColumn(2);
      expect(component.getScrollLeftColumn()).toBe(2);

      // Assigns the scrollTop based on the logical position when attached
      jasmine.attachToDOM(element);
      expect(component.getScrollLeft()).toBeCloseTo(
        2 * component.getBaseCharacterWidth(),
        0
      );

      // Allows the scrollTopRow to be updated while attached
      component.setScrollLeftColumn(4);
      expect(component.getScrollLeft()).toBeCloseTo(
        4 * component.getBaseCharacterWidth(),
        0
      );

      // Preserves the scrollTopRow when detached
      element.remove();
      expect(component.getScrollLeft()).toBeCloseTo(
        4 * component.getBaseCharacterWidth(),
        0
      );

      component.setScrollLeftColumn(6);
      expect(component.getScrollLeft()).toBeCloseTo(
        6 * component.getBaseCharacterWidth(),
        0
      );

      jasmine.attachToDOM(element);
      element.style.width = '60px';
      expect(component.getScrollLeft()).toBeCloseTo(
        6 * component.getBaseCharacterWidth(),
        0
      );
    });
  });

  describe('scrolling via the mouse wheel', () => {
    it('scrolls vertically or horizontally depending on whether deltaX or deltaY is larger', () => {
      const scrollSensitivity = 30;
      const { component } = buildComponent({
        height: 50,
        width: 50,
        scrollSensitivity
      });
      // stub in place for Event.preventDefault()
      const eventPreventDefaultStub = function() {};

      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        const expectedScrollLeft = component.getScrollLeft();
        component.didMouseWheel({
          wheelDeltaX: -5,
          wheelDeltaY: -20,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBeNear(expectedScrollTop);
        expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(${-expectedScrollLeft}px, ${-expectedScrollTop}px)`
        );
      }

      {
        const expectedScrollTop =
          component.getScrollTop() - 10 * (scrollSensitivity / 100);
        const expectedScrollLeft = component.getScrollLeft();
        component.didMouseWheel({
          wheelDeltaX: -5,
          wheelDeltaY: 10,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBeNear(expectedScrollTop);
        expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(${-expectedScrollLeft}px, ${-expectedScrollTop}px)`
        );
      }

      {
        const expectedScrollTop = component.getScrollTop();
        const expectedScrollLeft = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: -20,
          wheelDeltaY: 10,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBeNear(expectedScrollTop);
        expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(${-expectedScrollLeft}px, ${-expectedScrollTop}px)`
        );
      }

      {
        const expectedScrollTop = component.getScrollTop();
        const expectedScrollLeft =
          component.getScrollLeft() - 10 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 10,
          wheelDeltaY: -8,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBeNear(expectedScrollTop);
        expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(${-expectedScrollLeft}px, ${-expectedScrollTop}px)`
        );
      }
    });

    it('inverts deltaX and deltaY when holding shift on Windows and Linux', async () => {
      const scrollSensitivity = 50;
      const { component } = buildComponent({
        height: 50,
        width: 50,
        scrollSensitivity
      });
      // stub in place for Event.preventDefault()
      const eventPreventDefaultStub = function() {};

      component.props.platform = 'linux';
      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 0,
          wheelDeltaY: -20,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBeNear(expectedScrollTop);
        expect(component.refs.content.style.transform).toBe(
          `translate(0px, -${expectedScrollTop}px)`
        );
        await setScrollTop(component, 0);
      }

      {
        const expectedScrollLeft = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 0,
          wheelDeltaY: -20,
          shiftKey: true,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollLeft()).toBeNear(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(-${expectedScrollLeft}px, 0px)`
        );
        await setScrollLeft(component, 0);
      }

      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: -20,
          wheelDeltaY: 0,
          shiftKey: true,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBe(expectedScrollTop);
        expect(component.refs.content.style.transform).toBe(
          `translate(0px, -${expectedScrollTop}px)`
        );
        await setScrollTop(component, 0);
      }

      component.props.platform = 'win32';
      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 0,
          wheelDeltaY: -20,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBe(expectedScrollTop);
        expect(component.refs.content.style.transform).toBe(
          `translate(0px, -${expectedScrollTop}px)`
        );
        await setScrollTop(component, 0);
      }

      {
        const expectedScrollLeft = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 0,
          wheelDeltaY: -20,
          shiftKey: true,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollLeft()).toBe(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(-${expectedScrollLeft}px, 0px)`
        );
        await setScrollLeft(component, 0);
      }

      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: -20,
          wheelDeltaY: 0,
          shiftKey: true,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBe(expectedScrollTop);
        expect(component.refs.content.style.transform).toBe(
          `translate(0px, -${expectedScrollTop}px)`
        );
        await setScrollTop(component, 0);
      }

      component.props.platform = 'darwin';
      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 0,
          wheelDeltaY: -20,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBe(expectedScrollTop);
        expect(component.refs.content.style.transform).toBe(
          `translate(0px, -${expectedScrollTop}px)`
        );
        await setScrollTop(component, 0);
      }

      {
        const expectedScrollTop = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: 0,
          wheelDeltaY: -20,
          shiftKey: true,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollTop()).toBe(expectedScrollTop);
        expect(component.refs.content.style.transform).toBe(
          `translate(0px, -${expectedScrollTop}px)`
        );
        await setScrollTop(component, 0);
      }

      {
        const expectedScrollLeft = 20 * (scrollSensitivity / 100);
        component.didMouseWheel({
          wheelDeltaX: -20,
          wheelDeltaY: 0,
          shiftKey: true,
          preventDefault: eventPreventDefaultStub
        });
        expect(component.getScrollLeft()).toBe(expectedScrollLeft);
        expect(component.refs.content.style.transform).toBe(
          `translate(-${expectedScrollLeft}px, 0px)`
        );
        await setScrollLeft(component, 0);
      }
    });
  });

  describe('scrolling via the API', () => {
    it('ignores scroll requests to NaN, null or undefined positions', async () => {
      const { component } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 3);
      await setEditorWidthInCharacters(component, 10);

      const initialScrollTop = Math.round(2 * component.getLineHeight());
      const initialScrollLeft = Math.round(
        5 * component.getBaseCharacterWidth()
      );
      setScrollTop(component, initialScrollTop);
      setScrollLeft(component, initialScrollLeft);
      await component.getNextUpdatePromise();

      setScrollTop(component, NaN);
      setScrollLeft(component, NaN);
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBeNear(initialScrollTop);
      expect(component.getScrollLeft()).toBeNear(initialScrollLeft);

      setScrollTop(component, null);
      setScrollLeft(component, null);
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBeNear(initialScrollTop);
      expect(component.getScrollLeft()).toBeNear(initialScrollLeft);

      setScrollTop(component, undefined);
      setScrollLeft(component, undefined);
      await component.getNextUpdatePromise();
      expect(component.getScrollTop()).toBeNear(initialScrollTop);
      expect(component.getScrollLeft()).toBeNear(initialScrollLeft);
    });
  });

  describe('line and line number decorations', () => {
    it('adds decoration classes on screen lines spanned by decorated markers', async () => {
      const { component, editor } = buildComponent({
        softWrapped: true
      });
      await setEditorWidthInCharacters(component, 55);
      expect(lineNodeForScreenRow(component, 3).textContent).toBe(
        '    var pivot = items.shift(), current, left = [], '
      );
      expect(lineNodeForScreenRow(component, 4).textContent).toBe(
        '    right = [];'
      );

      const marker1 = editor.markScreenRange([[1, 10], [3, 10]]);
      const layer = editor.addMarkerLayer();
      layer.markScreenPosition([5, 0]);
      layer.markScreenPosition([8, 0]);
      const marker4 = layer.markScreenPosition([10, 0]);
      editor.decorateMarker(marker1, {
        type: ['line', 'line-number'],
        class: 'a'
      });
      const layerDecoration = editor.decorateMarkerLayer(layer, {
        type: ['line', 'line-number'],
        class: 'b'
      });
      layerDecoration.setPropertiesForMarker(marker4, {
        type: 'line',
        class: 'c'
      });
      await component.getNextUpdatePromise();

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 4).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 5).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 8).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 10).classList.contains('b')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 10).classList.contains('c')).toBe(
        true
      );

      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 2).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 3).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 4).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 5).classList.contains('b')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 8).classList.contains('b')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 10).classList.contains('b')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 10).classList.contains('c')
      ).toBe(false);

      marker1.setScreenRange([[5, 0], [8, 0]]);
      await component.getNextUpdatePromise();

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 4).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 5).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 5).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 6).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 7).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 8).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 8).classList.contains('b')).toBe(
        true
      );

      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 2).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 3).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 4).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 5).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 5).classList.contains('b')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 6).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 7).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 8).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 8).classList.contains('b')
      ).toBe(true);
    });

    it('honors the onlyEmpty and onlyNonEmpty decoration options', async () => {
      const { component, editor } = buildComponent();
      const marker = editor.markScreenPosition([1, 0]);
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'a',
        onlyEmpty: true
      });
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'b',
        onlyNonEmpty: true
      });
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'c'
      });
      await component.getNextUpdatePromise();

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 1).classList.contains('b')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 1).classList.contains('c')).toBe(
        true
      );
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('a')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('b')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('c')
      ).toBe(true);

      marker.setScreenRange([[1, 0], [2, 4]]);
      await component.getNextUpdatePromise();

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 1).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 1).classList.contains('c')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 2).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 2).classList.contains('c')).toBe(
        true
      );
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('b')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('c')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 2).classList.contains('b')
      ).toBe(true);
      expect(
        lineNumberNodeForScreenRow(component, 2).classList.contains('c')
      ).toBe(true);
    });

    it('honors the onlyHead option', async () => {
      const { component, editor } = buildComponent();
      const marker = editor.markScreenRange([[1, 4], [3, 4]]);
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'a',
        onlyHead: true
      });
      await component.getNextUpdatePromise();

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(
        false
      );
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(
        true
      );
      expect(
        lineNumberNodeForScreenRow(component, 1).classList.contains('a')
      ).toBe(false);
      expect(
        lineNumberNodeForScreenRow(component, 3).classList.contains('a')
      ).toBe(true);
    });

    it('only decorates the last row of non-empty ranges that end at column 0 if omitEmptyLastRow is false', async () => {
      const { component, editor } = buildComponent();
      const marker = editor.markScreenRange([[1, 0], [3, 0]]);
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'a'
      });
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'b',
        omitEmptyLastRow: false
      });
      await component.getNextUpdatePromise();

      expect(lineNodeForScreenRow(component, 1).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 3).classList.contains('a')).toBe(
        false
      );

      expect(lineNodeForScreenRow(component, 1).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 2).classList.contains('b')).toBe(
        true
      );
      expect(lineNodeForScreenRow(component, 3).classList.contains('b')).toBe(
        true
      );
    });

    it('does not decorate invalidated markers', async () => {
      const { component, editor } = buildComponent();
      const marker = editor.markScreenRange([[1, 0], [3, 0]], {
        invalidate: 'touch'
      });
      editor.decorateMarker(marker, {
        type: ['line', 'line-number'],
        class: 'a'
      });
      await component.getNextUpdatePromise();
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(
        true
      );

      editor.getBuffer().insert([2, 0], 'x');
      expect(marker.isValid()).toBe(false);
      await component.getNextUpdatePromise();
      expect(lineNodeForScreenRow(component, 2).classList.contains('a')).toBe(
        false
      );
    });
  });

  describe('highlight decorations', () => {
    it('renders single-line highlights', async () => {
      const { component, element, editor } = buildComponent();
      const marker = editor.markScreenRange([[1, 2], [1, 10]]);
      editor.decorateMarker(marker, { type: 'highlight', class: 'a' });
      await component.getNextUpdatePromise();

      {
        const regions = element.querySelectorAll('.highlight.a .region.a');
        expect(regions.length).toBe(1);
        const regionRect = regions[0].getBoundingClientRect();
        expect(regionRect.top).toBe(
          lineNodeForScreenRow(component, 1).getBoundingClientRect().top
        );
        expect(Math.round(regionRect.left)).toBeNear(
          clientLeftForCharacter(component, 1, 2)
        );
        expect(Math.round(regionRect.right)).toBeNear(
          clientLeftForCharacter(component, 1, 10)
        );
      }

      marker.setScreenRange([[1, 4], [1, 8]]);
      await component.getNextUpdatePromise();

      {
        const regions = element.querySelectorAll('.highlight.a .region.a');
        expect(regions.length).toBe(1);
        const regionRect = regions[0].getBoundingClientRect();
        expect(regionRect.top).toBe(
          lineNodeForScreenRow(component, 1).getBoundingClientRect().top
        );
        expect(regionRect.bottom).toBe(
          lineNodeForScreenRow(component, 1).getBoundingClientRect().bottom
        );
        expect(Math.round(regionRect.left)).toBeNear(
          clientLeftForCharacter(component, 1, 4)
        );
        expect(Math.round(regionRect.right)).toBeNear(
          clientLeftForCharacter(component, 1, 8)
        );
      }
    });

    it('renders multi-line highlights', async () => {
      const { component, element, editor } = buildComponent({ rowsPerTile: 3 });
      const marker = editor.markScreenRange([[2, 4], [3, 4]]);
      editor.decorateMarker(marker, { type: 'highlight', class: 'a' });

      await component.getNextUpdatePromise();

      {
        expect(element.querySelectorAll('.highlight.a').length).toBe(1);

        const regions = element.querySelectorAll('.highlight.a .region.a');
        expect(regions.length).toBe(2);
        const region0Rect = regions[0].getBoundingClientRect();
        expect(region0Rect.top).toBe(
          lineNodeForScreenRow(component, 2).getBoundingClientRect().top
        );
        expect(region0Rect.bottom).toBe(
          lineNodeForScreenRow(component, 2).getBoundingClientRect().bottom
        );
        expect(Math.round(region0Rect.left)).toBeNear(
          clientLeftForCharacter(component, 2, 4)
        );
        expect(Math.round(region0Rect.right)).toBeNear(
          component.refs.content.getBoundingClientRect().right
        );

        const region1Rect = regions[1].getBoundingClientRect();
        expect(region1Rect.top).toBeNear(
          lineNodeForScreenRow(component, 3).getBoundingClientRect().top
        );
        expect(region1Rect.bottom).toBeNear(
          lineNodeForScreenRow(component, 3).getBoundingClientRect().bottom
        );
        expect(Math.round(region1Rect.left)).toBeNear(
          clientLeftForCharacter(component, 3, 0)
        );
        expect(Math.round(region1Rect.right)).toBeNear(
          clientLeftForCharacter(component, 3, 4)
        );
      }

      marker.setScreenRange([[2, 4], [5, 4]]);
      await component.getNextUpdatePromise();

      {
        expect(element.querySelectorAll('.highlight.a').length).toBe(1);

        const regions = element.querySelectorAll('.highlight.a .region.a');
        expect(regions.length).toBe(3);

        const region0Rect = regions[0].getBoundingClientRect();
        expect(region0Rect.top).toBeNear(
          lineNodeForScreenRow(component, 2).getBoundingClientRect().top
        );
        expect(region0Rect.bottom).toBeNear(
          lineNodeForScreenRow(component, 2).getBoundingClientRect().bottom
        );
        expect(Math.round(region0Rect.left)).toBeNear(
          clientLeftForCharacter(component, 2, 4)
        );
        expect(Math.round(region0Rect.right)).toBeNear(
          component.refs.content.getBoundingClientRect().right
        );

        const region1Rect = regions[1].getBoundingClientRect();
        expect(region1Rect.top).toBeNear(
          lineNodeForScreenRow(component, 3).getBoundingClientRect().top
        );
        expect(region1Rect.bottom).toBeNear(
          lineNodeForScreenRow(component, 5).getBoundingClientRect().top
        );
        expect(Math.round(region1Rect.left)).toBeNear(
          component.refs.content.getBoundingClientRect().left
        );
        expect(Math.round(region1Rect.right)).toBeNear(
          component.refs.content.getBoundingClientRect().right
        );

        const region2Rect = regions[2].getBoundingClientRect();
        expect(region2Rect.top).toBeNear(
          lineNodeForScreenRow(component, 5).getBoundingClientRect().top
        );
        expect(region2Rect.bottom).toBeNear(
          lineNodeForScreenRow(component, 6).getBoundingClientRect().top
        );
        expect(Math.round(region2Rect.left)).toBeNear(
          component.refs.content.getBoundingClientRect().left
        );
        expect(Math.round(region2Rect.right)).toBeNear(
          clientLeftForCharacter(component, 5, 4)
        );
      }
    });

    it('can flash highlight decorations', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        height: 200
      });
      const marker = editor.markScreenRange([[2, 4], [3, 4]]);
      const decoration = editor.decorateMarker(marker, {
        type: 'highlight',
        class: 'a'
      });
      decoration.flash('b', 10);

      // Flash on initial appearance of highlight
      await component.getNextUpdatePromise();
      const highlights = element.querySelectorAll('.highlight.a');
      expect(highlights.length).toBe(1);

      expect(highlights[0].classList.contains('b')).toBe(true);

      await conditionPromise(() => !highlights[0].classList.contains('b'));

      // Don't flash on next update if another flash wasn't requested
      await setScrollTop(component, 100);
      expect(highlights[0].classList.contains('b')).toBe(false);

      // Flashing the same class again before the first flash completes
      // removes the flash class and adds it back on the next frame to ensure
      // CSS transitions apply to the second flash.
      decoration.flash('e', 100);
      await component.getNextUpdatePromise();
      expect(highlights[0].classList.contains('e')).toBe(true);

      decoration.flash('e', 100);
      await component.getNextUpdatePromise();
      expect(highlights[0].classList.contains('e')).toBe(false);

      await conditionPromise(() => highlights[0].classList.contains('e'));
      await conditionPromise(() => !highlights[0].classList.contains('e'));
    });

    it("flashing a highlight decoration doesn't unflash other highlight decorations", async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        height: 200
      });
      const marker = editor.markScreenRange([[2, 4], [3, 4]]);
      const decoration = editor.decorateMarker(marker, {
        type: 'highlight',
        class: 'a'
      });

      // Flash one class
      decoration.flash('c', 1000);
      await component.getNextUpdatePromise();
      const highlights = element.querySelectorAll('.highlight.a');
      expect(highlights.length).toBe(1);
      expect(highlights[0].classList.contains('c')).toBe(true);

      // Flash another class while the previously-flashed class is still highlighted
      decoration.flash('d', 100);
      await component.getNextUpdatePromise();
      expect(highlights[0].classList.contains('c')).toBe(true);
      expect(highlights[0].classList.contains('d')).toBe(true);
    });

    it('supports layer decorations', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 12
      });
      const markerLayer = editor.addMarkerLayer();
      const marker1 = markerLayer.markScreenRange([[2, 4], [3, 4]]);
      const marker2 = markerLayer.markScreenRange([[5, 6], [7, 8]]);
      const decoration = editor.decorateMarkerLayer(markerLayer, {
        type: 'highlight',
        class: 'a'
      });
      await component.getNextUpdatePromise();

      const highlights = element.querySelectorAll('.highlight');
      expect(highlights[0].classList.contains('a')).toBe(true);
      expect(highlights[1].classList.contains('a')).toBe(true);

      decoration.setPropertiesForMarker(marker1, {
        type: 'highlight',
        class: 'b'
      });
      await component.getNextUpdatePromise();
      expect(highlights[0].classList.contains('b')).toBe(true);
      expect(highlights[1].classList.contains('a')).toBe(true);

      decoration.setPropertiesForMarker(marker1, null);
      decoration.setPropertiesForMarker(marker2, {
        type: 'highlight',
        class: 'c'
      });
      await component.getNextUpdatePromise();
      expect(highlights[0].classList.contains('a')).toBe(true);
      expect(highlights[1].classList.contains('c')).toBe(true);
    });

    it('clears highlights when recycling a tile that previously contained highlights and now does not', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 2);
      const marker = editor.markScreenRange([[1, 2], [1, 10]]);
      editor.decorateMarker(marker, { type: 'highlight', class: 'a' });

      await component.getNextUpdatePromise();
      expect(element.querySelectorAll('.highlight.a').length).toBe(1);

      await setScrollTop(component, component.getLineHeight() * 3);
      expect(element.querySelectorAll('.highlight.a').length).toBe(0);
    });

    it('does not move existing highlights when adding or removing other highlight decorations (regression)', async () => {
      const { component, element, editor } = buildComponent();

      const marker1 = editor.markScreenRange([[1, 6], [1, 10]]);
      editor.decorateMarker(marker1, { type: 'highlight', class: 'a' });
      await component.getNextUpdatePromise();
      const marker1Region = element.querySelector('.highlight.a');
      expect(
        Array.from(marker1Region.parentElement.children).indexOf(marker1Region)
      ).toBe(0);

      const marker2 = editor.markScreenRange([[1, 2], [1, 4]]);
      editor.decorateMarker(marker2, { type: 'highlight', class: 'b' });
      await component.getNextUpdatePromise();
      const marker2Region = element.querySelector('.highlight.b');
      expect(
        Array.from(marker1Region.parentElement.children).indexOf(marker1Region)
      ).toBe(0);
      expect(
        Array.from(marker2Region.parentElement.children).indexOf(marker2Region)
      ).toBe(1);

      marker2.destroy();
      await component.getNextUpdatePromise();
      expect(
        Array.from(marker1Region.parentElement.children).indexOf(marker1Region)
      ).toBe(0);
    });

    it('correctly positions highlights that end on rows preceding or following block decorations', async () => {
      const { editor, element, component } = buildComponent();

      const item1 = document.createElement('div');
      item1.style.height = '30px';
      item1.style.backgroundColor = 'blue';
      editor.decorateMarker(editor.markBufferPosition([4, 0]), {
        type: 'block',
        position: 'after',
        item: item1
      });
      const item2 = document.createElement('div');
      item2.style.height = '30px';
      item2.style.backgroundColor = 'yellow';
      editor.decorateMarker(editor.markBufferPosition([4, 0]), {
        type: 'block',
        position: 'before',
        item: item2
      });
      editor.decorateMarker(editor.markBufferRange([[3, 0], [4, Infinity]]), {
        type: 'highlight',
        class: 'highlight'
      });

      await component.getNextUpdatePromise();
      const regions = element.querySelectorAll('.highlight .region');
      expect(regions[0].offsetTop).toBeNear(3 * component.getLineHeight());
      expect(regions[0].offsetHeight).toBeNear(component.getLineHeight());
      expect(regions[1].offsetTop).toBeNear(4 * component.getLineHeight() + 30);
    });
  });

  describe('overlay decorations', () => {
    function attachFakeWindow(component) {
      const fakeWindow = document.createElement('div');
      fakeWindow.style.position = 'absolute';
      fakeWindow.style.padding = 20 + 'px';
      fakeWindow.style.backgroundColor = 'blue';
      fakeWindow.appendChild(component.element);
      jasmine.attachToDOM(fakeWindow);
      spyOn(component, 'getWindowInnerWidth').andCallFake(
        () => fakeWindow.getBoundingClientRect().width
      );
      spyOn(component, 'getWindowInnerHeight').andCallFake(
        () => fakeWindow.getBoundingClientRect().height
      );
      return fakeWindow;
    }

    it('renders overlay elements at the specified screen position unless it would overflow the window', async () => {
      const { component, editor } = buildComponent({
        width: 200,
        height: 100,
        attach: false
      });
      const fakeWindow = attachFakeWindow(component);

      await setScrollTop(component, 50);
      await setScrollLeft(component, 100);

      const marker = editor.markScreenPosition([4, 25]);

      const overlayElement = document.createElement('div');
      overlayElement.style.width = '50px';
      overlayElement.style.height = '50px';
      overlayElement.style.margin = '3px';
      overlayElement.style.backgroundColor = 'red';

      const decoration = editor.decorateMarker(marker, {
        type: 'overlay',
        item: overlayElement,
        class: 'a'
      });
      await component.getNextUpdatePromise();

      const overlayComponent = component.overlayComponents.values().next()
        .value;

      const overlayWrapper = overlayElement.parentElement;
      expect(overlayWrapper.classList.contains('a')).toBe(true);
      expect(overlayWrapper.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 5)
      );
      expect(overlayWrapper.getBoundingClientRect().left).toBeNear(
        clientLeftForCharacter(component, 4, 25)
      );

      // Updates the horizontal position on scroll
      await setScrollLeft(component, 150);
      expect(overlayWrapper.getBoundingClientRect().left).toBeNear(
        clientLeftForCharacter(component, 4, 25)
      );

      // Shifts the overlay horizontally to ensure the overlay element does not
      // overflow the window
      await setScrollLeft(component, 30);
      expect(overlayElement.getBoundingClientRect().right).toBeNear(
        fakeWindow.getBoundingClientRect().right
      );
      await setScrollLeft(component, 280);
      expect(overlayElement.getBoundingClientRect().left).toBeNear(
        fakeWindow.getBoundingClientRect().left
      );

      // Updates the vertical position on scroll
      await setScrollTop(component, 60);
      expect(overlayWrapper.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 5)
      );

      // Flips the overlay vertically to ensure the overlay element does not
      // overflow the bottom of the window
      setScrollLeft(component, 100);
      await setScrollTop(component, 0);
      expect(overlayWrapper.getBoundingClientRect().bottom).toBeNear(
        clientTopForLine(component, 4)
      );

      // Flips the overlay vertically on overlay resize if necessary
      await setScrollTop(component, 20);
      expect(overlayWrapper.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 5)
      );
      overlayElement.style.height = 60 + 'px';
      await overlayComponent.getNextUpdatePromise();
      expect(overlayWrapper.getBoundingClientRect().bottom).toBeNear(
        clientTopForLine(component, 4)
      );

      // Does not flip the overlay vertically if it would overflow the top of the window
      overlayElement.style.height = 80 + 'px';
      await overlayComponent.getNextUpdatePromise();
      expect(overlayWrapper.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 5)
      );

      // Can update overlay wrapper class
      decoration.setProperties({
        type: 'overlay',
        item: overlayElement,
        class: 'b'
      });
      await component.getNextUpdatePromise();
      expect(overlayWrapper.classList.contains('a')).toBe(false);
      expect(overlayWrapper.classList.contains('b')).toBe(true);

      decoration.setProperties({ type: 'overlay', item: overlayElement });
      await component.getNextUpdatePromise();
      expect(overlayWrapper.classList.contains('b')).toBe(false);
    });

    it('does not attempt to avoid overflowing the window if `avoidOverflow` is false on the decoration', async () => {
      const { component, editor } = buildComponent({
        width: 200,
        height: 100,
        attach: false
      });
      const fakeWindow = attachFakeWindow(component);
      const overlayElement = document.createElement('div');
      overlayElement.style.width = '50px';
      overlayElement.style.height = '50px';
      overlayElement.style.margin = '3px';
      overlayElement.style.backgroundColor = 'red';
      const marker = editor.markScreenPosition([4, 25]);
      editor.decorateMarker(marker, {
        type: 'overlay',
        item: overlayElement,
        avoidOverflow: false
      });
      await component.getNextUpdatePromise();

      await setScrollLeft(component, 30);
      expect(overlayElement.getBoundingClientRect().right).toBeGreaterThan(
        fakeWindow.getBoundingClientRect().right
      );
      await setScrollLeft(component, 280);
      expect(overlayElement.getBoundingClientRect().left).toBeLessThan(
        fakeWindow.getBoundingClientRect().left
      );
    });
  });

  describe('custom gutter decorations', () => {
    it('arranges custom gutters based on their priority', async () => {
      const { component, editor } = buildComponent();
      editor.addGutter({ name: 'e', priority: 2 });
      editor.addGutter({ name: 'a', priority: -2 });
      editor.addGutter({ name: 'd', priority: 1 });
      editor.addGutter({ name: 'b', priority: -1 });
      editor.addGutter({ name: 'c', priority: 0 });

      await component.getNextUpdatePromise();
      const gutters = component.refs.gutterContainer.element.querySelectorAll(
        '.gutter'
      );
      expect(
        Array.from(gutters).map(g => g.getAttribute('gutter-name'))
      ).toEqual(['a', 'b', 'c', 'line-number', 'd', 'e']);
    });

    it('adjusts the left edge of the scroll container based on changes to the gutter container width', async () => {
      const { component, editor } = buildComponent();
      const { scrollContainer, gutterContainer } = component.refs;

      function checkScrollContainerLeft() {
        expect(scrollContainer.getBoundingClientRect().left).toBeNear(
          Math.round(gutterContainer.element.getBoundingClientRect().right)
        );
      }

      checkScrollContainerLeft();
      const gutterA = editor.addGutter({ name: 'a' });
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();

      const gutterB = editor.addGutter({ name: 'b' });
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();

      gutterA.getElement().style.width = 100 + 'px';
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();

      gutterA.hide();
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();

      gutterA.show();
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();

      gutterA.destroy();
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();

      gutterB.destroy();
      await component.getNextUpdatePromise();
      checkScrollContainerLeft();
    });

    it('allows the element of custom gutters to be retrieved before being rendered in the editor component', async () => {
      const { component, element, editor } = buildComponent();
      const [lineNumberGutter] = editor.getGutters();
      const gutterA = editor.addGutter({ name: 'a', priority: -1 });
      const gutterB = editor.addGutter({ name: 'b', priority: 1 });

      const lineNumberGutterElement = lineNumberGutter.getElement();
      const gutterAElement = gutterA.getElement();
      const gutterBElement = gutterB.getElement();

      await component.getNextUpdatePromise();

      expect(element.contains(lineNumberGutterElement)).toBe(true);
      expect(element.contains(gutterAElement)).toBe(true);
      expect(element.contains(gutterBElement)).toBe(true);
    });

    it('can show and hide custom gutters', async () => {
      const { component, editor } = buildComponent();
      const gutterA = editor.addGutter({ name: 'a', priority: -1 });
      const gutterB = editor.addGutter({ name: 'b', priority: 1 });
      const gutterAElement = gutterA.getElement();
      const gutterBElement = gutterB.getElement();

      await component.getNextUpdatePromise();
      expect(gutterAElement.style.display).toBe('');
      expect(gutterBElement.style.display).toBe('');

      gutterA.hide();
      await component.getNextUpdatePromise();
      expect(gutterAElement.style.display).toBe('none');
      expect(gutterBElement.style.display).toBe('');

      gutterB.hide();
      await component.getNextUpdatePromise();
      expect(gutterAElement.style.display).toBe('none');
      expect(gutterBElement.style.display).toBe('none');

      gutterA.show();
      await component.getNextUpdatePromise();
      expect(gutterAElement.style.display).toBe('');
      expect(gutterBElement.style.display).toBe('none');
    });

    it('renders decorations in custom gutters', async () => {
      const { component, element, editor } = buildComponent();
      const gutterA = editor.addGutter({ name: 'a', priority: -1 });
      const gutterB = editor.addGutter({ name: 'b', priority: 1 });
      const marker1 = editor.markScreenRange([[2, 0], [4, 0]]);
      const marker2 = editor.markScreenRange([[6, 0], [7, 0]]);
      const marker3 = editor.markScreenRange([[9, 0], [12, 0]]);
      const decorationElement1 = document.createElement('div');
      const decorationElement2 = document.createElement('div');
      // Packages may adopt this class name for decorations to be styled the same as line numbers
      decorationElement2.className = 'line-number';

      const decoration1 = gutterA.decorateMarker(marker1, { class: 'a' });
      const decoration2 = gutterA.decorateMarker(marker2, {
        class: 'b',
        item: decorationElement1
      });
      const decoration3 = gutterB.decorateMarker(marker3, {
        item: decorationElement2
      });
      await component.getNextUpdatePromise();

      let [
        decorationNode1,
        decorationNode2
      ] = gutterA.getElement().firstChild.children;
      const [decorationNode3] = gutterB.getElement().firstChild.children;

      expect(decorationNode1.className).toBe('decoration a');
      expect(decorationNode1.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 2)
      );
      expect(decorationNode1.getBoundingClientRect().bottom).toBeNear(
        clientTopForLine(component, 5)
      );
      expect(decorationNode1.firstChild).toBeNull();

      expect(decorationNode2.className).toBe('decoration b');
      expect(decorationNode2.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 6)
      );
      expect(decorationNode2.getBoundingClientRect().bottom).toBeNear(
        clientTopForLine(component, 8)
      );
      expect(decorationNode2.firstChild).toBe(decorationElement1);
      expect(decorationElement1.offsetHeight).toBe(
        decorationNode2.offsetHeight
      );
      expect(decorationElement1.offsetWidth).toBe(decorationNode2.offsetWidth);

      expect(decorationNode3.className).toBe('decoration');
      expect(decorationNode3.getBoundingClientRect().top).toBeNear(
        clientTopForLine(component, 9)
      );
      expect(decorationNode3.getBoundingClientRect().bottom).toBeNear(
        clientTopForLine(component, 12) + component.getLineHeight()
      );
      expect(decorationNode3.firstChild).toBe(decorationElement2);
      expect(decorationElement2.offsetHeight).toBe(
        decorationNode3.offsetHeight
      );
      expect(decorationElement2.offsetWidth).toBe(decorationNode3.offsetWidth);

      // Inline styled height is updated when line height changes
      element.style.fontSize =
        parseInt(getComputedStyle(element).fontSize) + 10 + 'px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(decorationElement1.offsetHeight).toBe(
        decorationNode2.offsetHeight
      );
      expect(decorationElement2.offsetHeight).toBe(
        decorationNode3.offsetHeight
      );

      decoration1.setProperties({
        type: 'gutter',
        gutterName: 'a',
        class: 'c',
        item: decorationElement1
      });
      decoration2.setProperties({ type: 'gutter', gutterName: 'a' });
      decoration3.destroy();
      await component.getNextUpdatePromise();
      expect(decorationNode1.className).toBe('decoration c');
      expect(decorationNode1.firstChild).toBe(decorationElement1);
      expect(decorationElement1.offsetHeight).toBe(
        decorationNode1.offsetHeight
      );
      expect(decorationNode2.className).toBe('decoration');
      expect(decorationNode2.firstChild).toBeNull();
      expect(gutterB.getElement().firstChild.children.length).toBe(0);
    });

    it('renders custom line number gutters', async () => {
      const { component, editor } = buildComponent();
      const gutterA = editor.addGutter({
        name: 'a',
        priority: 1,
        type: 'line-number',
        class: 'a-number',
        labelFn: ({ bufferRow }) => `a - ${bufferRow}`
      });
      const gutterB = editor.addGutter({
        name: 'b',
        priority: 1,
        type: 'line-number',
        class: 'b-number',
        labelFn: ({ bufferRow }) => `b - ${bufferRow}`
      });
      editor.setText('0000\n0001\n0002\n0003\n0004\n');

      await component.getNextUpdatePromise();

      const gutterAElement = gutterA.getElement();
      const aNumbers = gutterAElement.querySelectorAll(
        'div.line-number[data-buffer-row]'
      );
      const aLabels = Array.from(aNumbers, e => e.textContent);
      expect(aLabels).toEqual([
        'a - 0',
        'a - 1',
        'a - 2',
        'a - 3',
        'a - 4',
        'a - 5'
      ]);

      const gutterBElement = gutterB.getElement();
      const bNumbers = gutterBElement.querySelectorAll(
        'div.line-number[data-buffer-row]'
      );
      const bLabels = Array.from(bNumbers, e => e.textContent);
      expect(bLabels).toEqual([
        'b - 0',
        'b - 1',
        'b - 2',
        'b - 3',
        'b - 4',
        'b - 5'
      ]);
    });

    it("updates the editor's soft wrap width when a custom gutter's measurement is available", () => {
      const { component, element, editor } = buildComponent({
        lineNumberGutterVisible: false,
        width: 400,
        softWrapped: true,
        attach: false
      });
      const gutter = editor.addGutter({ name: 'a', priority: 10 });
      gutter.getElement().style.width = '100px';

      jasmine.attachToDOM(element);

      expect(component.getGutterContainerWidth()).toBe(100);

      // Component client width - gutter container width - vertical scrollbar width
      const softWrapColumn = Math.floor(
        (400 - 100 - component.getVerticalScrollbarWidth()) /
          component.getBaseCharacterWidth()
      );
      expect(editor.getSoftWrapColumn()).toBe(softWrapColumn);
    });
  });

  describe('block decorations', () => {
    it('renders visible block decorations between the appropriate lines, refreshing and measuring them as needed', async () => {
      const editor = buildEditor({ autoHeight: false });
      const {
        item: item1,
        decoration: decoration1
      } = createBlockDecorationAtScreenRow(editor, 0, {
        height: 11,
        position: 'before'
      });
      const {
        item: item2,
        decoration: decoration2
      } = createBlockDecorationAtScreenRow(editor, 2, {
        height: 22,
        margin: 10,
        position: 'before'
      });

      // render an editor that already contains some block decorations
      const { component, element } = buildComponent({ editor, rowsPerTile: 3 });
      element.style.height =
        4 * component.getLineHeight() + horizontalScrollbarHeight + 'px';
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item1) +
          getElementHeight(item2)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item1) +
            getElementHeight(item2)
        },
        { tileStartRow: 3, height: 3 * component.getLineHeight() }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(item1.previousSibling).toBeNull();
      expect(item1.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 2));

      // add block decorations
      const {
        item: item3,
        decoration: decoration3
      } = createBlockDecorationAtScreenRow(editor, 4, {
        height: 33,
        position: 'before'
      });
      const { item: item4 } = createBlockDecorationAtScreenRow(editor, 7, {
        height: 44,
        position: 'before'
      });
      const { item: item5 } = createBlockDecorationAtScreenRow(editor, 7, {
        height: 50,
        marginBottom: 5,
        position: 'after'
      });
      const { item: item6 } = createBlockDecorationAtScreenRow(editor, 12, {
        height: 60,
        marginTop: 6,
        position: 'after'
      });
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item1) +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item1) +
            getElementHeight(item2)
        },
        {
          tileStartRow: 3,
          height: 3 * component.getLineHeight() + getElementHeight(item3)
        }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(item1.previousSibling).toBeNull();
      expect(item1.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 2));
      expect(item3.previousSibling).toBe(lineNodeForScreenRow(component, 3));
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 4));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(element.contains(item6)).toBe(false);

      // destroy decoration1
      decoration1.destroy();
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height: 3 * component.getLineHeight() + getElementHeight(item2)
        },
        {
          tileStartRow: 3,
          height: 3 * component.getLineHeight() + getElementHeight(item3)
        }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 2));
      expect(item3.previousSibling).toBe(lineNodeForScreenRow(component, 3));
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 4));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(element.contains(item6)).toBe(false);

      // move decoration2 and decoration3
      decoration2.getMarker().setHeadScreenPosition([1, 0]);
      decoration3.getMarker().setHeadScreenPosition([0, 0]);
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item2) +
            getElementHeight(item3)
        },
        { tileStartRow: 3, height: 3 * component.getLineHeight() }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item3.previousSibling).toBeNull();
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(element.contains(item6)).toBe(false);

      // change the text
      editor.getBuffer().setTextInRange([[0, 5], [0, 5]], '\n\n');
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height: 3 * component.getLineHeight() + getElementHeight(item3)
        },
        {
          tileStartRow: 3,
          height: 3 * component.getLineHeight() + getElementHeight(item2)
        }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBeNull();
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 3));
      expect(item3.previousSibling).toBeNull();
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(element.contains(item4)).toBe(false);
      expect(element.contains(item5)).toBe(false);
      expect(element.contains(item6)).toBe(false);

      // scroll past the first tile
      await setScrollTop(
        component,
        3 * component.getLineHeight() + getElementHeight(item3)
      );
      expect(component.getRenderedStartRow()).toBe(3);
      expect(component.getRenderedEndRow()).toBe(12);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 3,
          height: 3 * component.getLineHeight() + getElementHeight(item2)
        },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBeNull();
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 3));
      expect(element.contains(item3)).toBe(false);
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 9));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 9));
      expect(element.contains(item6)).toBe(false);
      await setScrollTop(component, 0);

      // undo the previous change
      editor.undo();
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item2) +
            getElementHeight(item3)
        },
        { tileStartRow: 3, height: 3 * component.getLineHeight() }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item3.previousSibling).toBeNull();
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(element.contains(item6)).toBe(false);

      // invalidate decorations. this also tests a case where two decorations in
      // the same tile change their height without affecting the tile height nor
      // the content height.
      item3.style.height = '22px';
      item3.style.margin = '10px';
      item2.style.height = '33px';
      item2.style.margin = '0px';
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item2) +
            getElementHeight(item3)
        },
        { tileStartRow: 3, height: 3 * component.getLineHeight() }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item3.previousSibling).toBeNull();
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(element.contains(item6)).toBe(false);

      // make decoration before row 0 as wide as the editor, and insert some text into it so that it wraps.
      item3.style.height = '';
      item3.style.margin = '';
      item3.style.width = '';
      item3.style.wordWrap = 'break-word';
      const contentWidthInCharacters = Math.floor(
        component.getScrollContainerClientWidth() /
          component.getBaseCharacterWidth()
      );
      item3.textContent = 'x'.repeat(contentWidthInCharacters * 2);
      await component.getNextUpdatePromise();

      // make the editor wider, so that the decoration doesn't wrap anymore.
      component.element.style.width =
        component.getGutterContainerWidth() +
        component.getScrollContainerClientWidth() * 2 +
        verticalScrollbarWidth +
        'px';
      await component.getNextUpdatePromise();
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(9);
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item2) +
            getElementHeight(item3)
        },
        { tileStartRow: 3, height: 3 * component.getLineHeight() }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(9);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item3.previousSibling).toBeNull();
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(element.contains(item6)).toBe(false);

      // make the editor taller and wider and the same time, ensuring the number
      // of rendered lines is correct.
      setEditorHeightInLines(component, 13);
      setEditorWidthInCharacters(component, 50);
      await conditionPromise(
        () =>
          component.getRenderedStartRow() === 0 &&
          component.getRenderedEndRow() === 13
      );
      expect(component.getScrollHeight()).toBeNear(
        editor.getScreenLineCount() * component.getLineHeight() +
          getElementHeight(item2) +
          getElementHeight(item3) +
          getElementHeight(item4) +
          getElementHeight(item5) +
          getElementHeight(item6)
      );
      assertTilesAreSizedAndPositionedCorrectly(component, [
        {
          tileStartRow: 0,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item2) +
            getElementHeight(item3)
        },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        {
          tileStartRow: 6,
          height:
            3 * component.getLineHeight() +
            getElementHeight(item4) +
            getElementHeight(item5)
        }
      ]);
      assertLinesAreAlignedWithLineNumbers(component);
      expect(queryOnScreenLineElements(element).length).toBe(13);
      expect(element.contains(item1)).toBe(false);
      expect(item2.previousSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 1));
      expect(item3.previousSibling).toBeNull();
      expect(item3.nextSibling).toBe(lineNodeForScreenRow(component, 0));
      expect(item4.previousSibling).toBe(lineNodeForScreenRow(component, 6));
      expect(item4.nextSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.previousSibling).toBe(lineNodeForScreenRow(component, 7));
      expect(item5.nextSibling).toBe(lineNodeForScreenRow(component, 8));
      expect(item6.previousSibling).toBe(lineNodeForScreenRow(component, 12));
    });

    it('correctly positions line numbers when block decorations are located at tile boundaries', async () => {
      const { editor, component } = buildComponent({ rowsPerTile: 3 });
      createBlockDecorationAtScreenRow(editor, 0, {
        height: 5,
        position: 'before'
      });
      createBlockDecorationAtScreenRow(editor, 2, {
        height: 7,
        position: 'after'
      });
      createBlockDecorationAtScreenRow(editor, 3, {
        height: 9,
        position: 'before'
      });
      createBlockDecorationAtScreenRow(editor, 3, {
        height: 11,
        position: 'after'
      });
      createBlockDecorationAtScreenRow(editor, 5, {
        height: 13,
        position: 'after'
      });

      await component.getNextUpdatePromise();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() + 5 + 7 },
        {
          tileStartRow: 3,
          height: 3 * component.getLineHeight() + 9 + 11 + 13
        },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);
    });

    it('removes block decorations whose markers have been destroyed', async () => {
      const { editor, component } = buildComponent({ rowsPerTile: 3 });
      const { marker } = createBlockDecorationAtScreenRow(editor, 2, {
        height: 5,
        position: 'before'
      });
      await component.getNextUpdatePromise();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() + 5 },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);

      marker.destroy();
      await component.getNextUpdatePromise();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);
    });

    it('removes block decorations whose markers are invalidated, and adds them back when they become valid again', async () => {
      const editor = buildEditor({ rowsPerTile: 3, autoHeight: false });
      const { item, decoration, marker } = createBlockDecorationAtScreenRow(
        editor,
        3,
        { height: 44, position: 'before', invalidate: 'touch' }
      );
      const { component } = buildComponent({ editor, rowsPerTile: 3 });

      // Invalidating the marker removes the block decoration.
      editor.getBuffer().deleteRows(2, 3);
      await component.getNextUpdatePromise();
      expect(item.parentElement).toBeNull();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);

      // Moving invalid markers is ignored.
      marker.setScreenRange([[2, 0], [2, 0]]);
      await component.getNextUpdatePromise();
      expect(item.parentElement).toBeNull();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);

      // Making the marker valid again adds back the block decoration.
      marker.bufferMarker.valid = true;
      marker.setScreenRange([[3, 0], [3, 0]]);
      await component.getNextUpdatePromise();
      expect(item.nextSibling).toBe(lineNodeForScreenRow(component, 3));
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() + 44 },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);

      // Destroying the decoration and invalidating the marker at the same time
      // removes the block decoration correctly.
      editor.getBuffer().deleteRows(2, 3);
      decoration.destroy();
      await component.getNextUpdatePromise();
      expect(item.parentElement).toBeNull();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);
    });

    it('does not render block decorations when decorating invalid markers', async () => {
      const editor = buildEditor({ rowsPerTile: 3, autoHeight: false });
      const { component } = buildComponent({ editor, rowsPerTile: 3 });

      const marker = editor.markScreenPosition([3, 0], { invalidate: 'touch' });
      const item = document.createElement('div');
      item.style.height = 30 + 'px';
      item.style.width = 30 + 'px';
      editor.getBuffer().deleteRows(1, 4);

      editor.decorateMarker(marker, {
        type: 'block',
        item,
        position: 'before'
      });
      await component.getNextUpdatePromise();
      expect(item.parentElement).toBeNull();
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);

      // Making the marker valid again causes the corresponding block decoration
      // to be added to the editor.
      marker.bufferMarker.valid = true;
      marker.setScreenRange([[2, 0], [2, 0]]);
      await component.getNextUpdatePromise();
      expect(item.nextSibling).toBe(lineNodeForScreenRow(component, 2));
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() + 30 },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);
    });

    it('does not try to remeasure block decorations whose markers are invalid (regression)', async () => {
      const editor = buildEditor({ rowsPerTile: 3, autoHeight: false });
      const { component } = buildComponent({ editor, rowsPerTile: 3 });
      createBlockDecorationAtScreenRow(editor, 2, {
        height: '12px',
        invalidate: 'touch'
      });
      editor.getBuffer().deleteRows(0, 3);
      await component.getNextUpdatePromise();

      // Trigger a re-measurement of all block decorations.
      await setEditorWidthInCharacters(component, 20);
      assertLinesAreAlignedWithLineNumbers(component);
      assertTilesAreSizedAndPositionedCorrectly(component, [
        { tileStartRow: 0, height: 3 * component.getLineHeight() },
        { tileStartRow: 3, height: 3 * component.getLineHeight() },
        { tileStartRow: 6, height: 3 * component.getLineHeight() }
      ]);
    });

    it('does not throw exceptions when destroying a block decoration inside a marker change event (regression)', async () => {
      const { editor, component } = buildComponent({ rowsPerTile: 3 });

      const marker = editor.markScreenPosition([2, 0]);
      marker.onDidChange(() => {
        marker.destroy();
      });
      const item = document.createElement('div');
      editor.decorateMarker(marker, { type: 'block', item });

      await component.getNextUpdatePromise();
      expect(item.nextSibling).toBe(lineNodeForScreenRow(component, 2));

      marker.setBufferRange([[0, 0], [0, 0]]);
      expect(marker.isDestroyed()).toBe(true);

      await component.getNextUpdatePromise();
      expect(item.parentElement).toBeNull();
    });

    it('does not attempt to render block decorations located outside the visible range', async () => {
      const { editor, component } = buildComponent({
        autoHeight: false,
        rowsPerTile: 2
      });
      await setEditorHeightInLines(component, 2);
      expect(component.getRenderedStartRow()).toBe(0);
      expect(component.getRenderedEndRow()).toBe(4);

      const marker1 = editor.markScreenRange([[3, 0], [5, 0]], {
        reversed: false
      });
      const item1 = document.createElement('div');
      editor.decorateMarker(marker1, { type: 'block', item: item1 });

      const marker2 = editor.markScreenRange([[3, 0], [5, 0]], {
        reversed: true
      });
      const item2 = document.createElement('div');
      editor.decorateMarker(marker2, { type: 'block', item: item2 });

      await component.getNextUpdatePromise();
      expect(item1.parentElement).toBeNull();
      expect(item2.nextSibling).toBe(lineNodeForScreenRow(component, 3));

      await setScrollTop(component, 4 * component.getLineHeight());
      expect(component.getRenderedStartRow()).toBe(4);
      expect(component.getRenderedEndRow()).toBe(8);
      expect(item1.nextSibling).toBe(lineNodeForScreenRow(component, 5));
      expect(item2.parentElement).toBeNull();
    });

    it('measures block decorations correctly when they are added before the component width has been updated', async () => {
      {
        const { editor, component, element } = buildComponent({
          autoHeight: false,
          width: 500,
          attach: false
        });
        const marker = editor.markScreenPosition([0, 0]);
        const item = document.createElement('div');
        item.textContent = 'block decoration';
        editor.decorateMarker(marker, {
          type: 'block',
          item
        });

        jasmine.attachToDOM(element);
        assertLinesAreAlignedWithLineNumbers(component);
      }

      {
        const { editor, component, element } = buildComponent({
          autoHeight: false,
          width: 800
        });
        const marker = editor.markScreenPosition([0, 0]);
        const item = document.createElement('div');
        item.textContent = 'block decoration that could wrap many times';
        editor.decorateMarker(marker, {
          type: 'block',
          item
        });

        element.style.width = '50px';
        await component.getNextUpdatePromise();
        assertLinesAreAlignedWithLineNumbers(component);
      }
    });

    it('bases the width of the block decoration measurement area on the editor scroll width', async () => {
      const { component, element } = buildComponent({
        autoHeight: false,
        width: 150
      });
      expect(component.refs.blockDecorationMeasurementArea.offsetWidth).toBe(
        component.getScrollWidth()
      );

      element.style.width = '800px';
      await component.getNextUpdatePromise();
      expect(component.refs.blockDecorationMeasurementArea.offsetWidth).toBe(
        component.getScrollWidth()
      );
    });

    it('does not change the cursor position when clicking on a block decoration', async () => {
      const { editor, component } = buildComponent();

      const decorationElement = document.createElement('div');
      decorationElement.textContent = 'Parent';
      const childElement = document.createElement('div');
      childElement.textContent = 'Child';
      decorationElement.appendChild(childElement);
      const marker = editor.markScreenPosition([4, 0]);
      editor.decorateMarker(marker, { type: 'block', item: decorationElement });
      await component.getNextUpdatePromise();

      const decorationElementClientRect = decorationElement.getBoundingClientRect();
      component.didMouseDownOnContent({
        target: decorationElement,
        detail: 1,
        button: 0,
        clientX: decorationElementClientRect.left,
        clientY: decorationElementClientRect.top
      });
      expect(editor.getCursorScreenPosition()).toEqual([0, 0]);

      const childElementClientRect = childElement.getBoundingClientRect();
      component.didMouseDownOnContent({
        target: childElement,
        detail: 1,
        button: 0,
        clientX: childElementClientRect.left,
        clientY: childElementClientRect.top
      });
      expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
    });

    it('uses the order property to control the order of block decorations at the same screen row', async () => {
      const editor = buildEditor({ autoHeight: false });
      const { component, element } = buildComponent({ editor });
      element.style.height =
        10 * component.getLineHeight() + horizontalScrollbarHeight + 'px';
      await component.getNextUpdatePromise();

      // Order parameters that differ from creation order; that collide; and that are not provided.
      const [beforeItems, beforeDecorations] = [
        30,
        20,
        undefined,
        20,
        10,
        undefined
      ]
        .map(order => {
          return createBlockDecorationAtScreenRow(editor, 2, {
            height: 10,
            position: 'before',
            order
          });
        })
        .reduce(
          (lists, result) => {
            lists[0].push(result.item);
            lists[1].push(result.decoration);
            return lists;
          },
          [[], []]
        );

      const [afterItems] = [undefined, 1, 6, undefined, 6, 2]
        .map(order => {
          return createBlockDecorationAtScreenRow(editor, 2, {
            height: 10,
            position: 'after',
            order
          });
        })
        .reduce(
          (lists, result) => {
            lists[0].push(result.item);
            lists[1].push(result.decoration);
            return lists;
          },
          [[], []]
        );

      await component.getNextUpdatePromise();

      expect(beforeItems[4].previousSibling).toBe(
        lineNodeForScreenRow(component, 1)
      );
      expect(beforeItems[4].nextSibling).toBe(beforeItems[1]);
      expect(beforeItems[1].nextSibling).toBe(beforeItems[3]);
      expect(beforeItems[3].nextSibling).toBe(beforeItems[0]);
      expect(beforeItems[0].nextSibling).toBe(beforeItems[2]);
      expect(beforeItems[2].nextSibling).toBe(beforeItems[5]);
      expect(beforeItems[5].nextSibling).toBe(
        lineNodeForScreenRow(component, 2)
      );
      expect(afterItems[1].previousSibling).toBe(
        lineNodeForScreenRow(component, 2)
      );
      expect(afterItems[1].nextSibling).toBe(afterItems[5]);
      expect(afterItems[5].nextSibling).toBe(afterItems[2]);
      expect(afterItems[2].nextSibling).toBe(afterItems[4]);
      expect(afterItems[4].nextSibling).toBe(afterItems[0]);
      expect(afterItems[0].nextSibling).toBe(afterItems[3]);

      // Create a decoration somewhere else and move it to the same screen row as the existing decorations
      const { item: later, decoration } = createBlockDecorationAtScreenRow(
        editor,
        4,
        { height: 20, position: 'after', order: 3 }
      );
      await component.getNextUpdatePromise();
      expect(later.previousSibling).toBe(lineNodeForScreenRow(component, 4));
      expect(later.nextSibling).toBe(lineNodeForScreenRow(component, 5));

      decoration.getMarker().setHeadScreenPosition([2, 0]);
      await component.getNextUpdatePromise();
      expect(later.previousSibling).toBe(afterItems[5]);
      expect(later.nextSibling).toBe(afterItems[2]);

      // Move a decoration away from its screen row and ensure the rest maintain their order
      beforeDecorations[3].getMarker().setHeadScreenPosition([5, 0]);
      await component.getNextUpdatePromise();
      expect(beforeItems[3].previousSibling).toBe(
        lineNodeForScreenRow(component, 4)
      );
      expect(beforeItems[3].nextSibling).toBe(
        lineNodeForScreenRow(component, 5)
      );

      expect(beforeItems[4].previousSibling).toBe(
        lineNodeForScreenRow(component, 1)
      );
      expect(beforeItems[4].nextSibling).toBe(beforeItems[1]);
      expect(beforeItems[1].nextSibling).toBe(beforeItems[0]);
      expect(beforeItems[0].nextSibling).toBe(beforeItems[2]);
      expect(beforeItems[2].nextSibling).toBe(beforeItems[5]);
      expect(beforeItems[5].nextSibling).toBe(
        lineNodeForScreenRow(component, 2)
      );
    });

    function createBlockDecorationAtScreenRow(
      editor,
      screenRow,
      { height, margin, marginTop, marginBottom, position, order, invalidate }
    ) {
      const marker = editor.markScreenPosition([screenRow, 0], {
        invalidate: invalidate || 'never'
      });
      const item = document.createElement('div');
      item.style.height = height + 'px';
      if (margin != null) item.style.margin = margin + 'px';
      if (marginTop != null) item.style.marginTop = marginTop + 'px';
      if (marginBottom != null) item.style.marginBottom = marginBottom + 'px';
      item.style.width = 30 + 'px';
      const decoration = editor.decorateMarker(marker, {
        type: 'block',
        item,
        position,
        order
      });
      return { item, decoration, marker };
    }

    function assertTilesAreSizedAndPositionedCorrectly(component, tiles) {
      let top = 0;
      for (let tile of tiles) {
        const linesTileElement = lineNodeForScreenRow(
          component,
          tile.tileStartRow
        ).parentElement;
        const linesTileBoundingRect = linesTileElement.getBoundingClientRect();
        expect(linesTileBoundingRect.height).toBeNear(tile.height);
        expect(linesTileBoundingRect.top).toBeNear(top);

        const lineNumbersTileElement = lineNumberNodeForScreenRow(
          component,
          tile.tileStartRow
        ).parentElement;
        const lineNumbersTileBoundingRect = lineNumbersTileElement.getBoundingClientRect();
        expect(lineNumbersTileBoundingRect.height).toBeNear(tile.height);
        expect(lineNumbersTileBoundingRect.top).toBeNear(top);

        top += tile.height;
      }
    }

    function assertLinesAreAlignedWithLineNumbers(component) {
      const startRow = component.getRenderedStartRow();
      const endRow = component.getRenderedEndRow();
      for (let row = startRow; row < endRow; row++) {
        const lineNode = lineNodeForScreenRow(component, row);
        const lineNumberNode = lineNumberNodeForScreenRow(component, row);
        expect(lineNumberNode.getBoundingClientRect().top).toBeNear(
          lineNode.getBoundingClientRect().top
        );
      }
    }
  });

  describe('cursor decorations', () => {
    it('allows default cursors to be customized', async () => {
      const { component, element, editor } = buildComponent();

      editor.addCursorAtScreenPosition([1, 0]);
      const [cursorMarker1, cursorMarker2] = editor
        .getCursors()
        .map(c => c.getMarker());

      editor.decorateMarker(cursorMarker1, { type: 'cursor', class: 'a' });
      editor.decorateMarker(cursorMarker2, {
        type: 'cursor',
        class: 'b',
        style: { visibility: 'hidden' }
      });
      editor.decorateMarker(cursorMarker2, {
        type: 'cursor',
        style: { backgroundColor: 'red' }
      });
      await component.getNextUpdatePromise();

      const cursorNodes = element.querySelectorAll('.cursor');
      expect(cursorNodes.length).toBe(2);

      expect(cursorNodes[0].className).toBe('cursor a');
      expect(cursorNodes[1].className).toBe('cursor b');
      expect(cursorNodes[1].style.visibility).toBe('hidden');
      expect(cursorNodes[1].style.backgroundColor).toBe('red');
    });

    it('allows markers that are not actually associated with cursors to be decorated as if they were cursors', async () => {
      const { component, element, editor } = buildComponent();
      const marker = editor.markScreenPosition([1, 0]);
      editor.decorateMarker(marker, { type: 'cursor', class: 'a' });
      await component.getNextUpdatePromise();

      const cursorNodes = element.querySelectorAll('.cursor');
      expect(cursorNodes.length).toBe(2);
      expect(cursorNodes[0].className).toBe('cursor');
      expect(cursorNodes[1].className).toBe('cursor a');
    });
  });

  describe('text decorations', () => {
    it('injects spans with custom class names and inline styles based on text decorations', async () => {
      const { component, element, editor } = buildComponent({ rowsPerTile: 2 });

      const markerLayer = editor.addMarkerLayer();
      const marker1 = markerLayer.markBufferRange([[0, 2], [2, 7]]);
      const marker2 = markerLayer.markBufferRange([[0, 2], [3, 8]]);
      const marker3 = markerLayer.markBufferRange([[1, 13], [2, 7]]);
      editor.decorateMarker(marker1, {
        type: 'text',
        class: 'a',
        style: { color: 'red' }
      });
      editor.decorateMarker(marker2, {
        type: 'text',
        class: 'b',
        style: { color: 'blue' }
      });
      editor.decorateMarker(marker3, {
        type: 'text',
        class: 'c',
        style: { color: 'green' }
      });
      await component.getNextUpdatePromise();

      expect(textContentOnRowMatchingSelector(component, 0, '.a')).toBe(
        editor.lineTextForScreenRow(0).slice(2)
      );
      expect(textContentOnRowMatchingSelector(component, 1, '.a')).toBe(
        editor.lineTextForScreenRow(1)
      );
      expect(textContentOnRowMatchingSelector(component, 2, '.a')).toBe(
        editor.lineTextForScreenRow(2).slice(0, 7)
      );
      expect(textContentOnRowMatchingSelector(component, 3, '.a')).toBe('');

      expect(textContentOnRowMatchingSelector(component, 0, '.b')).toBe(
        editor.lineTextForScreenRow(0).slice(2)
      );
      expect(textContentOnRowMatchingSelector(component, 1, '.b')).toBe(
        editor.lineTextForScreenRow(1)
      );
      expect(textContentOnRowMatchingSelector(component, 2, '.b')).toBe(
        editor.lineTextForScreenRow(2)
      );
      expect(textContentOnRowMatchingSelector(component, 3, '.b')).toBe(
        editor.lineTextForScreenRow(3).slice(0, 8)
      );

      expect(textContentOnRowMatchingSelector(component, 0, '.c')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 1, '.c')).toBe(
        editor.lineTextForScreenRow(1).slice(13)
      );
      expect(textContentOnRowMatchingSelector(component, 2, '.c')).toBe(
        editor.lineTextForScreenRow(2).slice(0, 7)
      );
      expect(textContentOnRowMatchingSelector(component, 3, '.c')).toBe('');

      for (const span of element.querySelectorAll('.a:not(.c)')) {
        expect(span.style.color).toBe('red');
      }
      for (const span of element.querySelectorAll('.b:not(.c):not(.a)')) {
        expect(span.style.color).toBe('blue');
      }
      for (const span of element.querySelectorAll('.c')) {
        expect(span.style.color).toBe('green');
      }

      marker2.setHeadScreenPosition([3, 10]);
      await component.getNextUpdatePromise();
      expect(textContentOnRowMatchingSelector(component, 3, '.b')).toBe(
        editor.lineTextForScreenRow(3).slice(0, 10)
      );
    });

    it('correctly handles text decorations starting before the first rendered row and/or ending after the last rendered row', async () => {
      const { component, element, editor } = buildComponent({
        autoHeight: false,
        rowsPerTile: 1
      });
      element.style.height = 4 * component.getLineHeight() + 'px';
      await component.getNextUpdatePromise();
      await setScrollTop(component, 4 * component.getLineHeight());
      expect(component.getRenderedStartRow()).toBeNear(4);
      expect(component.getRenderedEndRow()).toBeNear(9);

      const markerLayer = editor.addMarkerLayer();
      const marker1 = markerLayer.markBufferRange([[0, 0], [4, 5]]);
      const marker2 = markerLayer.markBufferRange([[7, 2], [10, 8]]);
      editor.decorateMarker(marker1, { type: 'text', class: 'a' });
      editor.decorateMarker(marker2, { type: 'text', class: 'b' });
      await component.getNextUpdatePromise();

      expect(textContentOnRowMatchingSelector(component, 4, '.a')).toBe(
        editor.lineTextForScreenRow(4).slice(0, 5)
      );
      expect(textContentOnRowMatchingSelector(component, 5, '.a')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 6, '.a')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 7, '.a')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 8, '.a')).toBe('');

      expect(textContentOnRowMatchingSelector(component, 4, '.b')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 5, '.b')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 6, '.b')).toBe('');
      expect(textContentOnRowMatchingSelector(component, 7, '.b')).toBe(
        editor.lineTextForScreenRow(7).slice(2)
      );
      expect(textContentOnRowMatchingSelector(component, 8, '.b')).toBe(
        editor.lineTextForScreenRow(8)
      );
    });

    it('does not create empty spans when a text decoration contains a row but another text decoration starts or ends at the beginning of it', async () => {
      const { component, element, editor } = buildComponent();
      const markerLayer = editor.addMarkerLayer();
      const marker1 = markerLayer.markBufferRange([[0, 2], [4, 0]]);
      const marker2 = markerLayer.markBufferRange([[2, 0], [5, 8]]);
      editor.decorateMarker(marker1, { type: 'text', class: 'a' });
      editor.decorateMarker(marker2, { type: 'text', class: 'b' });
      await component.getNextUpdatePromise();
      for (const decorationSpan of element.querySelectorAll('.a, .b')) {
        expect(decorationSpan.textContent).not.toBe('');
      }
    });

    it('does not create empty text nodes when a text decoration ends right after a text tag', async () => {
      const { component, editor } = buildComponent();
      const marker = editor.markBufferRange([[0, 8], [0, 29]]);
      editor.decorateMarker(marker, { type: 'text', class: 'a' });
      await component.getNextUpdatePromise();
      for (const textNode of textNodesForScreenRow(component, 0)) {
        expect(textNode.textContent).not.toBe('');
      }
    });

    function textContentOnRowMatchingSelector(component, row, selector) {
      return Array.from(
        lineNodeForScreenRow(component, row).querySelectorAll(selector)
      )
        .map(span => span.textContent)
        .join('');
    }
  });

  describe('mouse input', () => {
    describe('on the lines', () => {
      describe('when there is only one cursor', () => {
        it('positions the cursor on single-click or when middle-clicking', async () => {
          atom.config.set('editor.selectionClipboard', true);
          for (const button of [0, 1]) {
            const { component, editor } = buildComponent();
            const { lineHeight } = component.measurements;

            editor.setCursorScreenPosition([Infinity, Infinity], {
              autoscroll: false
            });
            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX: clientLeftForCharacter(component, 0, 0) - 1,
              clientY: clientTopForLine(component, 0) - 1
            });
            expect(editor.getCursorScreenPosition()).toEqual([0, 0]);

            const maxRow = editor.getLastScreenRow();
            editor.setCursorScreenPosition([Infinity, Infinity], {
              autoscroll: false
            });
            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                clientLeftForCharacter(
                  component,
                  maxRow,
                  editor.lineLengthForScreenRow(maxRow)
                ) + 1,
              clientY: clientTopForLine(component, maxRow) + 1
            });
            expect(editor.getCursorScreenPosition()).toEqual([
              maxRow,
              editor.lineLengthForScreenRow(maxRow)
            ]);

            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                clientLeftForCharacter(
                  component,
                  0,
                  editor.lineLengthForScreenRow(0)
                ) + 1,
              clientY: clientTopForLine(component, 0) + lineHeight / 2
            });
            expect(editor.getCursorScreenPosition()).toEqual([
              0,
              editor.lineLengthForScreenRow(0)
            ]);

            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                (clientLeftForCharacter(component, 3, 0) +
                  clientLeftForCharacter(component, 3, 1)) /
                2,
              clientY: clientTopForLine(component, 1) + lineHeight / 2
            });
            expect(editor.getCursorScreenPosition()).toEqual([1, 0]);

            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                (clientLeftForCharacter(component, 3, 14) +
                  clientLeftForCharacter(component, 3, 15)) /
                2,
              clientY: clientTopForLine(component, 3) + lineHeight / 2
            });
            expect(editor.getCursorScreenPosition()).toEqual([3, 14]);

            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                (clientLeftForCharacter(component, 3, 14) +
                  clientLeftForCharacter(component, 3, 15)) /
                  2 +
                1,
              clientY: clientTopForLine(component, 3) + lineHeight / 2
            });
            expect(editor.getCursorScreenPosition()).toEqual([3, 15]);

            editor.getBuffer().setTextInRange([[3, 14], [3, 15]], '🐣');
            await component.getNextUpdatePromise();

            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                (clientLeftForCharacter(component, 3, 14) +
                  clientLeftForCharacter(component, 3, 16)) /
                2,
              clientY: clientTopForLine(component, 3) + lineHeight / 2
            });
            expect(editor.getCursorScreenPosition()).toEqual([3, 14]);

            component.didMouseDownOnContent({
              detail: 1,
              button,
              clientX:
                (clientLeftForCharacter(component, 3, 14) +
                  clientLeftForCharacter(component, 3, 16)) /
                  2 +
                1,
              clientY: clientTopForLine(component, 3) + lineHeight / 2
            });
            expect(editor.getCursorScreenPosition()).toEqual([3, 16]);

            expect(editor.testAutoscrollRequests).toEqual([]);
          }
        });
      });

      describe('when the input is for the primary mouse button', () => {
        it('selects words on double-click', () => {
          const { component, editor } = buildComponent();
          const { clientX, clientY } = clientPositionForCharacter(
            component,
            1,
            16
          );
          component.didMouseDownOnContent({
            detail: 1,
            button: 0,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 2,
            button: 0,
            clientX,
            clientY
          });
          expect(editor.getSelectedScreenRange()).toEqual([[1, 13], [1, 21]]);
          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('selects lines on triple-click', () => {
          const { component, editor } = buildComponent();
          const { clientX, clientY } = clientPositionForCharacter(
            component,
            1,
            16
          );
          component.didMouseDownOnContent({
            detail: 1,
            button: 0,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 2,
            button: 0,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 3,
            button: 0,
            clientX,
            clientY
          });
          expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [2, 0]]);
          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('adds or removes cursors when holding cmd or ctrl when single-clicking', () => {
          atom.config.set('editor.multiCursorOnClick', true);
          const { component, editor } = buildComponent({ platform: 'darwin' });
          expect(editor.getCursorScreenPositions()).toEqual([[0, 0]]);

          // add cursor at 1, 16
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getCursorScreenPositions()).toEqual([[0, 0], [1, 16]]);

          // remove cursor at 0, 0
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 0, 0), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getCursorScreenPositions()).toEqual([[1, 16]]);

          // cmd-click cursor at 1, 16 but don't remove it because it's the last one
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getCursorScreenPositions()).toEqual([[1, 16]]);

          // cmd-clicking within a selection destroys it
          editor.addSelectionForScreenRange([[2, 10], [2, 15]], {
            autoscroll: false
          });
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 16], [1, 16]],
            [[2, 10], [2, 15]]
          ]);
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 2, 13), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 16], [1, 16]]
          ]);

          // ctrl-click does not add cursors on macOS, nor does it move the cursor
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 4), {
              detail: 1,
              button: 0,
              ctrlKey: true
            })
          );
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 16], [1, 16]]
          ]);

          // ctrl-click adds cursors on platforms *other* than macOS
          component.props.platform = 'win32';
          editor.setCursorScreenPosition([1, 4], { autoscroll: false });
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              ctrlKey: true
            })
          );
          expect(editor.getCursorScreenPositions()).toEqual([[1, 4], [1, 16]]);

          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('adds word selections when holding cmd or ctrl when double-clicking', () => {
          atom.config.set('editor.multiCursorOnClick', true);
          const { component, editor } = buildComponent();
          editor.addCursorAtScreenPosition([1, 16], { autoscroll: false });
          expect(editor.getCursorScreenPositions()).toEqual([[0, 0], [1, 16]]);

          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 2,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[0, 0], [0, 0]],
            [[1, 13], [1, 21]]
          ]);
          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('adds line selections when holding cmd or ctrl when triple-clicking', () => {
          atom.config.set('editor.multiCursorOnClick', true);
          const { component, editor } = buildComponent();
          editor.addCursorAtScreenPosition([1, 16], { autoscroll: false });
          expect(editor.getCursorScreenPositions()).toEqual([[0, 0], [1, 16]]);

          const { clientX, clientY } = clientPositionForCharacter(
            component,
            1,
            16
          );
          component.didMouseDownOnContent({
            detail: 1,
            button: 0,
            metaKey: true,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 2,
            button: 0,
            metaKey: true,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 3,
            button: 0,
            metaKey: true,
            clientX,
            clientY
          });

          expect(editor.getSelectedScreenRanges()).toEqual([
            [[0, 0], [0, 0]],
            [[1, 0], [2, 0]]
          ]);
          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('does not add cursors when holding cmd or ctrl when single-clicking', () => {
          atom.config.set('editor.multiCursorOnClick', false);
          const { component, editor } = buildComponent({ platform: 'darwin' });
          expect(editor.getCursorScreenPositions()).toEqual([[0, 0]]);

          // moves cursor to 1, 16
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getCursorScreenPositions()).toEqual([[1, 16]]);

          // ctrl-click does not add cursors on macOS, nor does it move the cursor
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 4), {
              detail: 1,
              button: 0,
              ctrlKey: true
            })
          );
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 16], [1, 16]]
          ]);

          // ctrl-click does not add cursors on platforms *other* than macOS
          component.props.platform = 'win32';
          editor.setCursorScreenPosition([1, 4], { autoscroll: false });
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              ctrlKey: true
            })
          );
          expect(editor.getCursorScreenPositions()).toEqual([[1, 16]]);

          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('does not add word selections when holding cmd or ctrl when double-clicking', () => {
          atom.config.set('editor.multiCursorOnClick', false);
          const { component, editor } = buildComponent();

          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 1,
              button: 0,
              metaKey: true
            })
          );
          component.didMouseDownOnContent(
            Object.assign(clientPositionForCharacter(component, 1, 16), {
              detail: 2,
              button: 0,
              metaKey: true
            })
          );
          expect(editor.getSelectedScreenRanges()).toEqual([
            [[1, 13], [1, 21]]
          ]);
          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('does not add line selections when holding cmd or ctrl when triple-clicking', () => {
          atom.config.set('editor.multiCursorOnClick', false);
          const { component, editor } = buildComponent();

          const { clientX, clientY } = clientPositionForCharacter(
            component,
            1,
            16
          );
          component.didMouseDownOnContent({
            detail: 1,
            button: 0,
            metaKey: true,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 2,
            button: 0,
            metaKey: true,
            clientX,
            clientY
          });
          component.didMouseDownOnContent({
            detail: 3,
            button: 0,
            metaKey: true,
            clientX,
            clientY
          });

          expect(editor.getSelectedScreenRanges()).toEqual([[[1, 0], [2, 0]]]);
          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('expands the last selection on shift-click', () => {
          const { component, editor } = buildComponent();

          editor.setCursorScreenPosition([2, 18], { autoscroll: false });
          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                shiftKey: true
              },
              clientPositionForCharacter(component, 1, 4)
            )
          );
          expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [2, 18]]);

          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                shiftKey: true
              },
              clientPositionForCharacter(component, 4, 4)
            )
          );
          expect(editor.getSelectedScreenRange()).toEqual([[2, 18], [4, 4]]);

          // reorients word-wise selections to keep the word selected regardless of
          // where the subsequent shift-click occurs
          editor.setCursorScreenPosition([2, 18], { autoscroll: false });
          editor.getLastSelection().selectWord({ autoscroll: false });
          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                shiftKey: true
              },
              clientPositionForCharacter(component, 1, 4)
            )
          );
          expect(editor.getSelectedScreenRange()).toEqual([[1, 2], [2, 20]]);

          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                shiftKey: true
              },
              clientPositionForCharacter(component, 3, 11)
            )
          );
          expect(editor.getSelectedScreenRange()).toEqual([[2, 14], [3, 13]]);

          // reorients line-wise selections to keep the line selected regardless of
          // where the subsequent shift-click occurs
          editor.setCursorScreenPosition([2, 18], { autoscroll: false });
          editor.getLastSelection().selectLine(null, { autoscroll: false });
          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                shiftKey: true
              },
              clientPositionForCharacter(component, 1, 4)
            )
          );
          expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [3, 0]]);

          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                shiftKey: true
              },
              clientPositionForCharacter(component, 3, 11)
            )
          );
          expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [4, 0]]);

          expect(editor.testAutoscrollRequests).toEqual([]);
        });

        it('expands the last selection on drag', () => {
          atom.config.set('editor.multiCursorOnClick', true);
          const { component, editor } = buildComponent();
          spyOn(component, 'handleMouseDragUntilMouseUp');

          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0
              },
              clientPositionForCharacter(component, 1, 4)
            )
          );

          {
            const {
              didDrag,
              didStopDragging
            } = component.handleMouseDragUntilMouseUp.argsForCall[0][0];
            didDrag(clientPositionForCharacter(component, 8, 8));
            expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [8, 8]]);
            didDrag(clientPositionForCharacter(component, 4, 8));
            expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [4, 8]]);
            didStopDragging();
            expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [4, 8]]);
          }

          // Click-drag a second selection... selections are not merged until the
          // drag stops.
          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0,
                metaKey: 1
              },
              clientPositionForCharacter(component, 8, 8)
            )
          );
          {
            const {
              didDrag,
              didStopDragging
            } = component.handleMouseDragUntilMouseUp.argsForCall[1][0];
            didDrag(clientPositionForCharacter(component, 2, 8));
            expect(editor.getSelectedScreenRanges()).toEqual([
              [[1, 4], [4, 8]],
              [[2, 8], [8, 8]]
            ]);
            didDrag(clientPositionForCharacter(component, 6, 8));
            expect(editor.getSelectedScreenRanges()).toEqual([
              [[1, 4], [4, 8]],
              [[6, 8], [8, 8]]
            ]);
            didDrag(clientPositionForCharacter(component, 2, 8));
            expect(editor.getSelectedScreenRanges()).toEqual([
              [[1, 4], [4, 8]],
              [[2, 8], [8, 8]]
            ]);
            didStopDragging();
            expect(editor.getSelectedScreenRanges()).toEqual([
              [[1, 4], [8, 8]]
            ]);
          }
        });

        it('expands the selection word-wise on double-click-drag', () => {
          const { component, editor } = buildComponent();
          spyOn(component, 'handleMouseDragUntilMouseUp');

          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 1,
                button: 0
              },
              clientPositionForCharacter(component, 1, 4)
            )
          );
          component.didMouseDownOnContent(
            Object.assign(
              {
                detail: 2,
                button: 0
              },
              clientPositionForCharacter(component, 1, 4)
            )
          );

          const {
            didDrag
          } = component.handleMouseDragUntilMouseUp.argsForCall[1][0];
          didDrag(clientPositionForCharacter(component, 0, 8));
          expect(editor.getSelectedScreenRange()).toEqual([[0, 4], [1, 5]]);
          didDrag(clientPositionForCharacter(component, 2, 10));
          expect(editor.getSelectedScreenRange()).toEqual([[1, 2], [2, 13]]);
        });

        it('expands the selection line-wise on triple-click-drag', () => {
          const { component, editor } = buildComponent();
          spyOn(component, 'handleMouseDragUntilMouseUp');

          const tripleClickPosition = clientPositionForCharacter(
            component,
            2,
            8
          );
          component.didMouseDownOnContent(
            Object.assign({ detail: 1, button: 0 }, tripleClickPosition)
          );
          component.didMouseDownOnContent(
            Object.assign({ detail: 2, button: 0 }, tripleClickPosition)
          );
          component.didMouseDownOnContent(
            Object.assign({ detail: 3, button: 0 }, tripleClickPosition)
          );

          const {
            didDrag
          } = component.handleMouseDragUntilMouseUp.argsForCall[2][0];
          didDrag(clientPositionForCharacter(component, 1, 8));
          expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [3, 0]]);
          didDrag(clientPositionForCharacter(component, 4, 10));
          expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [5, 0]]);
        });

        it('destroys folds when clicking on their fold markers', async () => {
          const { component, element, editor } = buildComponent();
          editor.foldBufferRow(1);
          await component.getNextUpdatePromise();

          const target = element.querySelector('.fold-marker');
          const { clientX, clientY } = clientPositionForCharacter(
            component,
            1,
            editor.lineLengthForScreenRow(1)
          );
          component.didMouseDownOnContent({
            detail: 1,
            button: 0,
            target,
            clientX,
            clientY
          });
          expect(editor.isFoldedAtBufferRow(1)).toBe(false);
          expect(editor.getCursorScreenPosition()).toEqual([0, 0]);
        });

        it('autoscrolls the content when dragging near the edge of the scroll container', async () => {
          const { component } = buildComponent({
            width: 200,
            height: 200
          });
          spyOn(component, 'handleMouseDragUntilMouseUp');

          let previousScrollTop = 0;
          let previousScrollLeft = 0;
          function assertScrolledDownAndRight() {
            expect(component.getScrollTop()).toBeGreaterThan(previousScrollTop);
            previousScrollTop = component.getScrollTop();
            expect(component.getScrollLeft()).toBeGreaterThan(
              previousScrollLeft
            );
            previousScrollLeft = component.getScrollLeft();
          }

          function assertScrolledUpAndLeft() {
            expect(component.getScrollTop()).toBeLessThan(previousScrollTop);
            previousScrollTop = component.getScrollTop();
            expect(component.getScrollLeft()).toBeLessThan(previousScrollLeft);
            previousScrollLeft = component.getScrollLeft();
          }

          component.didMouseDownOnContent({
            detail: 1,
            button: 0,
            clientX: 100,
            clientY: 100
          });
          const {
            didDrag
          } = component.handleMouseDragUntilMouseUp.argsForCall[0][0];

          didDrag({ clientX: 199, clientY: 199 });
          assertScrolledDownAndRight();
          didDrag({ clientX: 199, clientY: 199 });
          assertScrolledDownAndRight();
          didDrag({ clientX: 199, clientY: 199 });
          assertScrolledDownAndRight();
          didDrag({
            clientX: component.getGutterContainerWidth() + 1,
            clientY: 1
          });
          assertScrolledUpAndLeft();
          didDrag({
            clientX: component.getGutterContainerWidth() + 1,
            clientY: 1
          });
          assertScrolledUpAndLeft();
          didDrag({
            clientX: component.getGutterContainerWidth() + 1,
            clientY: 1
          });
          assertScrolledUpAndLeft();

          // Don't artificially update scroll position beyond possible values
          expect(component.getScrollTop()).toBe(0);
          expect(component.getScrollLeft()).toBe(0);
          didDrag({
            clientX: component.getGutterContainerWidth() + 1,
            clientY: 1
          });
          expect(component.getScrollTop()).toBe(0);
          expect(component.getScrollLeft()).toBe(0);

          const maxScrollTop = component.getMaxScrollTop();
          const maxScrollLeft = component.getMaxScrollLeft();
          setScrollTop(component, maxScrollTop);
          await setScrollLeft(component, maxScrollLeft);

          didDrag({ clientX: 199, clientY: 199 });
          didDrag({ clientX: 199, clientY: 199 });
          didDrag({ clientX: 199, clientY: 199 });
          expect(component.getScrollTop()).toBeNear(maxScrollTop);
          expect(component.getScrollLeft()).toBeNear(maxScrollLeft);
        });
      });

      it('pastes the previously selected text when clicking the middle mouse button on Linux', async () => {
        spyOn(electron.ipcRenderer, 'send').andCallFake(function(
          eventName,
          selectedText
        ) {
          if (eventName === 'write-text-to-selection-clipboard') {
            clipboard.writeText(selectedText, 'selection');
          }
        });

        const { component, editor } = buildComponent({ platform: 'linux' });

        // Middle mouse pasting.
        atom.config.set('editor.selectionClipboard', true);
        editor.setSelectedBufferRange([[1, 6], [1, 10]]);
        await conditionPromise(() => TextEditor.clipboard.read() === 'sort');
        component.didMouseDownOnContent({
          button: 1,
          clientX: clientLeftForCharacter(component, 10, 0),
          clientY: clientTopForLine(component, 10)
        });
        expect(TextEditor.clipboard.read()).toBe('sort');
        expect(editor.lineTextForBufferRow(10)).toBe('sort');
        editor.undo();

        // Doesn't paste when middle mouse button is clicked
        atom.config.set('editor.selectionClipboard', false);
        editor.setSelectedBufferRange([[1, 6], [1, 10]]);
        component.didMouseDownOnContent({
          button: 1,
          clientX: clientLeftForCharacter(component, 10, 0),
          clientY: clientTopForLine(component, 10)
        });
        expect(TextEditor.clipboard.read()).toBe('sort');
        expect(editor.lineTextForBufferRow(10)).toBe('');

        // Ensure left clicks don't interfere.
        atom.config.set('editor.selectionClipboard', true);
        editor.setSelectedBufferRange([[1, 2], [1, 5]]);
        await conditionPromise(() => TextEditor.clipboard.read() === 'var');
        component.didMouseDownOnContent({
          button: 0,
          detail: 1,
          clientX: clientLeftForCharacter(component, 10, 0),
          clientY: clientTopForLine(component, 10)
        });
        component.didMouseDownOnContent({
          button: 1,
          clientX: clientLeftForCharacter(component, 10, 0),
          clientY: clientTopForLine(component, 10)
        });
        expect(editor.lineTextForBufferRow(10)).toBe('var');
      });

      it('does not paste into a read only editor when clicking the middle mouse button on Linux', async () => {
        spyOn(electron.ipcRenderer, 'send').andCallFake(function(
          eventName,
          selectedText
        ) {
          if (eventName === 'write-text-to-selection-clipboard') {
            clipboard.writeText(selectedText, 'selection');
          }
        });

        const { component, editor } = buildComponent({
          platform: 'linux',
          readOnly: true
        });

        // Select the word 'sort' on line 2 and copy to clipboard
        editor.setSelectedBufferRange([[1, 6], [1, 10]]);
        await conditionPromise(() => TextEditor.clipboard.read() === 'sort');

        // Middle-click in the buffer at line 11, column 1
        component.didMouseDownOnContent({
          button: 1,
          clientX: clientLeftForCharacter(component, 10, 0),
          clientY: clientTopForLine(component, 10)
        });

        // Ensure that the correct text was copied but not pasted
        expect(TextEditor.clipboard.read()).toBe('sort');
        expect(editor.lineTextForBufferRow(10)).toBe('');
      });
    });

    describe('on the line number gutter', () => {
      it('selects all buffer rows intersecting the clicked screen row when a line number is clicked', async () => {
        const { component, editor } = buildComponent();
        spyOn(component, 'handleMouseDragUntilMouseUp');
        editor.setSoftWrapped(true);
        await component.getNextUpdatePromise();

        await setEditorWidthInCharacters(component, 50);
        editor.foldBufferRange([[4, Infinity], [7, Infinity]]);
        await component.getNextUpdatePromise();

        // Selects entire buffer line when clicked screen line is soft-wrapped
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          clientY: clientTopForLine(component, 3)
        });
        expect(editor.getSelectedScreenRange()).toEqual([[3, 0], [5, 0]]);
        expect(editor.getSelectedBufferRange()).toEqual([[3, 0], [4, 0]]);

        // Selects entire screen line, even if folds cause that selection to
        // span multiple buffer lines
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          clientY: clientTopForLine(component, 5)
        });
        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [6, 0]]);
        expect(editor.getSelectedBufferRange()).toEqual([[4, 0], [8, 0]]);
      });

      it('adds new selections when a line number is meta-clicked', async () => {
        const { component, editor } = buildComponent();
        editor.setSoftWrapped(true);
        await component.getNextUpdatePromise();

        await setEditorWidthInCharacters(component, 50);
        editor.foldBufferRange([[4, Infinity], [7, Infinity]]);
        await component.getNextUpdatePromise();

        // Selects entire buffer line when clicked screen line is soft-wrapped
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          metaKey: true,
          clientY: clientTopForLine(component, 3)
        });
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [5, 0]]
        ]);
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [4, 0]]
        ]);

        // Selects entire screen line, even if folds cause that selection to
        // span multiple buffer lines
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          metaKey: true,
          clientY: clientTopForLine(component, 5)
        });
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [5, 0]],
          [[5, 0], [6, 0]]
        ]);
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[0, 0], [0, 0]],
          [[3, 0], [4, 0]],
          [[4, 0], [8, 0]]
        ]);
      });

      it('expands the last selection when a line number is shift-clicked', async () => {
        const { component, editor } = buildComponent();
        spyOn(component, 'handleMouseDragUntilMouseUp');
        editor.setSoftWrapped(true);
        await component.getNextUpdatePromise();

        await setEditorWidthInCharacters(component, 50);
        editor.foldBufferRange([[4, Infinity], [7, Infinity]]);
        await component.getNextUpdatePromise();

        editor.setSelectedScreenRange([[3, 4], [3, 8]]);
        editor.addCursorAtScreenPosition([2, 10]);
        component.didMouseDownOnLineNumberGutter({
          button: 0,
          shiftKey: true,
          clientY: clientTopForLine(component, 5)
        });

        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 4], [3, 8]],
          [[2, 10], [8, 0]]
        ]);

        // Original selection is preserved when shift-click-dragging
        const {
          didDrag,
          didStopDragging
        } = component.handleMouseDragUntilMouseUp.argsForCall[0][0];
        didDrag({
          clientY: clientTopForLine(component, 1)
        });
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[3, 4], [3, 8]],
          [[1, 0], [2, 10]]
        ]);

        didDrag({
          clientY: clientTopForLine(component, 5)
        });

        didStopDragging();
        expect(editor.getSelectedBufferRanges()).toEqual([[[2, 10], [8, 0]]]);
      });

      it('expands the selection when dragging', async () => {
        const { component, editor } = buildComponent();
        spyOn(component, 'handleMouseDragUntilMouseUp');
        editor.setSoftWrapped(true);
        await component.getNextUpdatePromise();

        await setEditorWidthInCharacters(component, 50);
        editor.foldBufferRange([[4, Infinity], [7, Infinity]]);
        await component.getNextUpdatePromise();

        editor.setSelectedScreenRange([[3, 4], [3, 6]]);

        component.didMouseDownOnLineNumberGutter({
          button: 0,
          metaKey: true,
          clientY: clientTopForLine(component, 2)
        });

        const {
          didDrag,
          didStopDragging
        } = component.handleMouseDragUntilMouseUp.argsForCall[0][0];

        didDrag({
          clientY: clientTopForLine(component, 1)
        });
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[3, 4], [3, 6]],
          [[1, 0], [3, 0]]
        ]);

        didDrag({
          clientY: clientTopForLine(component, 5)
        });
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[3, 4], [3, 6]],
          [[2, 0], [6, 0]]
        ]);
        expect(editor.isFoldedAtBufferRow(4)).toBe(true);

        didDrag({
          clientY: clientTopForLine(component, 3)
        });
        expect(editor.getSelectedScreenRanges()).toEqual([
          [[3, 4], [3, 6]],
          [[2, 0], [4, 4]]
        ]);

        didStopDragging();
        expect(editor.getSelectedScreenRanges()).toEqual([[[2, 0], [4, 4]]]);
      });

      it('toggles folding when clicking on the right icon of a foldable line number', async () => {
        const { component, element, editor } = buildComponent();
        let target = element
          .querySelectorAll('.line-number')[1]
          .querySelector('.icon-right');
        expect(editor.isFoldedAtScreenRow(1)).toBe(false);

        component.didMouseDownOnLineNumberGutter({
          target,
          button: 0,
          clientY: clientTopForLine(component, 1)
        });
        expect(editor.isFoldedAtScreenRow(1)).toBe(true);
        await component.getNextUpdatePromise();

        component.didMouseDownOnLineNumberGutter({
          target,
          button: 0,
          clientY: clientTopForLine(component, 1)
        });
        await component.getNextUpdatePromise();
        expect(editor.isFoldedAtScreenRow(1)).toBe(false);

        editor.foldBufferRange([[5, 12], [5, 17]]);
        await component.getNextUpdatePromise();
        expect(editor.isFoldedAtScreenRow(5)).toBe(true);

        target = element
          .querySelectorAll('.line-number')[4]
          .querySelector('.icon-right');
        component.didMouseDownOnLineNumberGutter({
          target,
          button: 0,
          clientY: clientTopForLine(component, 4)
        });
        expect(editor.isFoldedAtScreenRow(4)).toBe(false);
      });

      it('autoscrolls when dragging near the top or bottom of the gutter', async () => {
        const { component } = buildComponent({
          width: 200,
          height: 200
        });
        spyOn(component, 'handleMouseDragUntilMouseUp');

        let previousScrollTop = 0;
        let previousScrollLeft = 0;
        function assertScrolledDown() {
          expect(component.getScrollTop()).toBeGreaterThan(previousScrollTop);
          previousScrollTop = component.getScrollTop();
          expect(component.getScrollLeft()).toBe(previousScrollLeft);
          previousScrollLeft = component.getScrollLeft();
        }

        function assertScrolledUp() {
          expect(component.getScrollTop()).toBeLessThan(previousScrollTop);
          previousScrollTop = component.getScrollTop();
          expect(component.getScrollLeft()).toBe(previousScrollLeft);
          previousScrollLeft = component.getScrollLeft();
        }

        component.didMouseDownOnLineNumberGutter({
          detail: 1,
          button: 0,
          clientX: 0,
          clientY: 100
        });
        const {
          didDrag
        } = component.handleMouseDragUntilMouseUp.argsForCall[0][0];
        didDrag({ clientX: 199, clientY: 199 });
        assertScrolledDown();
        didDrag({ clientX: 199, clientY: 199 });
        assertScrolledDown();
        didDrag({ clientX: 199, clientY: 199 });
        assertScrolledDown();
        didDrag({
          clientX: component.getGutterContainerWidth() + 1,
          clientY: 1
        });
        assertScrolledUp();
        didDrag({
          clientX: component.getGutterContainerWidth() + 1,
          clientY: 1
        });
        assertScrolledUp();
        didDrag({
          clientX: component.getGutterContainerWidth() + 1,
          clientY: 1
        });
        assertScrolledUp();

        // Don't artificially update scroll measurements beyond the minimum or
        // maximum possible scroll positions
        expect(component.getScrollTop()).toBe(0);
        expect(component.getScrollLeft()).toBe(0);
        didDrag({
          clientX: component.getGutterContainerWidth() + 1,
          clientY: 1
        });
        expect(component.getScrollTop()).toBe(0);
        expect(component.getScrollLeft()).toBe(0);

        const maxScrollTop = component.getMaxScrollTop();
        const maxScrollLeft = component.getMaxScrollLeft();
        setScrollTop(component, maxScrollTop);
        await setScrollLeft(component, maxScrollLeft);

        didDrag({ clientX: 199, clientY: 199 });
        didDrag({ clientX: 199, clientY: 199 });
        didDrag({ clientX: 199, clientY: 199 });
        expect(component.getScrollTop()).toBeNear(maxScrollTop);
        expect(component.getScrollLeft()).toBeNear(maxScrollLeft);
      });
    });

    describe('on the scrollbars', () => {
      it('delegates the mousedown events to the parent component unless the mousedown was on the actual scrollbar', async () => {
        const { component, editor } = buildComponent({ height: 100 });
        await setEditorWidthInCharacters(component, 6);

        const verticalScrollbar = component.refs.verticalScrollbar;
        const horizontalScrollbar = component.refs.horizontalScrollbar;
        const leftEdgeOfVerticalScrollbar =
          verticalScrollbar.element.getBoundingClientRect().right -
          verticalScrollbarWidth;
        const topEdgeOfHorizontalScrollbar =
          horizontalScrollbar.element.getBoundingClientRect().bottom -
          horizontalScrollbarHeight;

        verticalScrollbar.didMouseDown({
          button: 0,
          detail: 1,
          clientY: clientTopForLine(component, 4),
          clientX: leftEdgeOfVerticalScrollbar
        });
        expect(editor.getCursorScreenPosition()).toEqual([0, 0]);

        verticalScrollbar.didMouseDown({
          button: 0,
          detail: 1,
          clientY: clientTopForLine(component, 4),
          clientX: leftEdgeOfVerticalScrollbar - 1
        });
        expect(editor.getCursorScreenPosition()).toEqual([4, 6]);

        horizontalScrollbar.didMouseDown({
          button: 0,
          detail: 1,
          clientY: topEdgeOfHorizontalScrollbar,
          clientX: component.refs.content.getBoundingClientRect().left
        });
        expect(editor.getCursorScreenPosition()).toEqual([4, 6]);

        horizontalScrollbar.didMouseDown({
          button: 0,
          detail: 1,
          clientY: topEdgeOfHorizontalScrollbar - 1,
          clientX: component.refs.content.getBoundingClientRect().left
        });
        expect(editor.getCursorScreenPosition()).toEqual([4, 0]);
      });
    });
  });

  describe('paste event', () => {
    it("prevents the browser's default processing for the event on Linux", () => {
      const { component } = buildComponent({ platform: 'linux' });
      const event = { preventDefault: () => {} };
      spyOn(event, 'preventDefault');

      component.didPaste(event);
      expect(event.preventDefault).toHaveBeenCalled();
    });
  });

  describe('keyboard input', () => {
    it('handles inserted accented characters via the press-and-hold menu on macOS correctly', () => {
      const { editor, component } = buildComponent({
        text: '',
        chromeVersion: 57
      });
      editor.insertText('x');
      editor.setCursorBufferPosition([0, 1]);

      // Simulate holding the A key to open the press-and-hold menu,
      // then closing it via ESC.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeyup({ code: 'KeyA' });
      component.didKeydown({ code: 'Escape' });
      component.didKeyup({ code: 'Escape' });
      expect(editor.getText()).toBe('xa');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      expect(editor.getText()).toBe('xaa');
      editor.undo();
      expect(editor.getText()).toBe('x');

      // Simulate holding the A key to open the press-and-hold menu,
      // then selecting an alternative by typing a number.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeyup({ code: 'KeyA' });
      component.didKeydown({ code: 'Digit2' });
      component.didKeyup({ code: 'Digit2' });
      component.didTextInput({
        data: 'á',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      expect(editor.getText()).toBe('xá');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      expect(editor.getText()).toBe('xáa');
      editor.undo();
      expect(editor.getText()).toBe('x');

      // Simulate holding the A key to open the press-and-hold menu,
      // then selecting an alternative by clicking on it.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeyup({ code: 'KeyA' });
      component.didTextInput({
        data: 'á',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      expect(editor.getText()).toBe('xá');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      expect(editor.getText()).toBe('xáa');
      editor.undo();
      expect(editor.getText()).toBe('x');

      // Simulate holding the A key to open the press-and-hold menu,
      // cycling through the alternatives with the arrows, then selecting one of them with Enter.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeyup({ code: 'KeyA' });
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionStart({ data: '' });
      component.didCompositionUpdate({ data: 'à' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xà');
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionUpdate({ data: 'á' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xá');
      component.didKeydown({ code: 'Enter' });
      component.didCompositionUpdate({ data: 'á' });
      component.didTextInput({
        data: 'á',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didCompositionEnd({
        data: 'á',
        target: component.refs.cursorsAndInput.refs.hiddenInput
      });
      component.didKeyup({ code: 'Enter' });
      expect(editor.getText()).toBe('xá');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      expect(editor.getText()).toBe('xáa');
      editor.undo();
      expect(editor.getText()).toBe('x');

      // Simulate holding the A key to open the press-and-hold menu,
      // cycling through the alternatives with the arrows, then closing it via ESC.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeyup({ code: 'KeyA' });
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionStart({ data: '' });
      component.didCompositionUpdate({ data: 'à' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xà');
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionUpdate({ data: 'á' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xá');
      component.didKeydown({ code: 'Escape' });
      component.didCompositionUpdate({ data: 'a' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didCompositionEnd({
        data: 'a',
        target: component.refs.cursorsAndInput.refs.hiddenInput
      });
      component.didKeyup({ code: 'Escape' });
      expect(editor.getText()).toBe('xa');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      expect(editor.getText()).toBe('xaa');
      editor.undo();
      expect(editor.getText()).toBe('x');

      // Simulate pressing the O key and holding the A key to open the press-and-hold menu right before releasing the O key,
      // cycling through the alternatives with the arrows, then closing it via ESC.
      component.didKeydown({ code: 'KeyO' });
      component.didKeypress({ code: 'KeyO' });
      component.didTextInput({
        data: 'o',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyO' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionStart({ data: '' });
      component.didCompositionUpdate({ data: 'à' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xoà');
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionUpdate({ data: 'á' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xoá');
      component.didKeydown({ code: 'Escape' });
      component.didCompositionUpdate({ data: 'a' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didCompositionEnd({
        data: 'a',
        target: component.refs.cursorsAndInput.refs.hiddenInput
      });
      component.didKeyup({ code: 'Escape' });
      expect(editor.getText()).toBe('xoa');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      editor.undo();
      expect(editor.getText()).toBe('x');

      // Simulate holding the A key to open the press-and-hold menu,
      // cycling through the alternatives with the arrows, then closing it by changing focus.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeydown({ code: 'KeyA' });
      component.didKeydown({ code: 'KeyA' });
      component.didKeyup({ code: 'KeyA' });
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionStart({ data: '' });
      component.didCompositionUpdate({ data: 'à' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xà');
      component.didKeydown({ code: 'ArrowRight' });
      component.didCompositionUpdate({ data: 'á' });
      component.didKeyup({ code: 'ArrowRight' });
      expect(editor.getText()).toBe('xá');
      component.didCompositionUpdate({ data: 'á' });
      component.didTextInput({
        data: 'á',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didCompositionEnd({
        data: 'á',
        target: component.refs.cursorsAndInput.refs.hiddenInput
      });
      expect(editor.getText()).toBe('xá');
      // Ensure another "a" can be typed correctly.
      component.didKeydown({ code: 'KeyA' });
      component.didKeypress({ code: 'KeyA' });
      component.didTextInput({
        data: 'a',
        stopPropagation: () => {},
        preventDefault: () => {}
      });
      component.didKeyup({ code: 'KeyA' });
      expect(editor.getText()).toBe('xáa');
      editor.undo();
      expect(editor.getText()).toBe('x');
    });
  });

  describe('styling changes', () => {
    it('updates the rendered content based on new measurements when the font dimensions change', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 1,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 3);
      editor.setCursorScreenPosition([1, 29], { autoscroll: false });
      await component.getNextUpdatePromise();

      let cursorNode = element.querySelector('.cursor');
      const initialBaseCharacterWidth = editor.getDefaultCharWidth();
      const initialDoubleCharacterWidth = editor.getDoubleWidthCharWidth();
      const initialHalfCharacterWidth = editor.getHalfWidthCharWidth();
      const initialKoreanCharacterWidth = editor.getKoreanCharWidth();
      const initialRenderedLineCount = queryOnScreenLineElements(element)
        .length;
      const initialFontSize = parseInt(getComputedStyle(element).fontSize);

      expect(initialKoreanCharacterWidth).toBeDefined();
      expect(initialDoubleCharacterWidth).toBeDefined();
      expect(initialHalfCharacterWidth).toBeDefined();
      expect(initialBaseCharacterWidth).toBeDefined();
      expect(initialDoubleCharacterWidth).not.toBe(initialBaseCharacterWidth);
      expect(initialHalfCharacterWidth).not.toBe(initialBaseCharacterWidth);
      expect(initialKoreanCharacterWidth).not.toBe(initialBaseCharacterWidth);
      verifyCursorPosition(component, cursorNode, 1, 29);

      element.style.fontSize = initialFontSize - 5 + 'px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(editor.getDefaultCharWidth()).toBeLessThan(
        initialBaseCharacterWidth
      );
      expect(editor.getDoubleWidthCharWidth()).toBeLessThan(
        initialDoubleCharacterWidth
      );
      expect(editor.getHalfWidthCharWidth()).toBeLessThan(
        initialHalfCharacterWidth
      );
      expect(editor.getKoreanCharWidth()).toBeLessThan(
        initialKoreanCharacterWidth
      );
      expect(queryOnScreenLineElements(element).length).toBeGreaterThan(
        initialRenderedLineCount
      );
      verifyCursorPosition(component, cursorNode, 1, 29);

      element.style.fontSize = initialFontSize + 10 + 'px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(
        initialBaseCharacterWidth
      );
      expect(editor.getDoubleWidthCharWidth()).toBeGreaterThan(
        initialDoubleCharacterWidth
      );
      expect(editor.getHalfWidthCharWidth()).toBeGreaterThan(
        initialHalfCharacterWidth
      );
      expect(editor.getKoreanCharWidth()).toBeGreaterThan(
        initialKoreanCharacterWidth
      );
      expect(queryOnScreenLineElements(element).length).toBeLessThan(
        initialRenderedLineCount
      );
      verifyCursorPosition(component, cursorNode, 1, 29);
    });

    it('maintains the scrollTopRow and scrollLeftColumn when the font size changes', async () => {
      const { component, element } = buildComponent({
        rowsPerTile: 1,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 3);
      await setEditorWidthInCharacters(component, 20);
      component.setScrollTopRow(4);
      component.setScrollLeftColumn(10);
      await component.getNextUpdatePromise();

      const initialFontSize = parseInt(getComputedStyle(element).fontSize);
      element.style.fontSize = initialFontSize - 5 + 'px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(component.getScrollTopRow()).toBe(4);

      element.style.fontSize = initialFontSize + 5 + 'px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
      expect(component.getScrollTopRow()).toBe(4);
    });

    it('gracefully handles the editor being hidden after a styling change', async () => {
      const { component, element } = buildComponent({
        autoHeight: false
      });
      element.style.fontSize =
        parseInt(getComputedStyle(element).fontSize) + 5 + 'px';
      TextEditor.didUpdateStyles();
      element.style.display = 'none';
      await component.getNextUpdatePromise();
    });

    it('does not throw an exception when the editor is soft-wrapped and changing the font size changes also the longest screen line', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });
      editor.setText(
        'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do\n' +
          'eiusmod tempor incididunt ut labore et dolore magna' +
          'aliqua. Ut enim ad minim veniam, quis nostrud exercitation'
      );
      editor.setSoftWrapped(true);
      await setEditorHeightInLines(component, 2);
      await setEditorWidthInCharacters(component, 56);
      await setScrollTop(component, 3 * component.getLineHeight());

      element.style.fontSize = '20px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();
    });

    it('updates the width of the lines div based on the longest screen line', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 1,
        autoHeight: false
      });
      editor.setText(
        'Lorem ipsum dolor sit\n' +
          'amet, consectetur adipisicing\n' +
          'elit, sed do\n' +
          'eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation'
      );
      await setEditorHeightInLines(component, 2);

      element.style.fontSize = '20px';
      TextEditor.didUpdateStyles();
      await component.getNextUpdatePromise();

      // Capture the width of the lines before requesting the width of
      // longest line, because making that request forces a DOM update
      const actualWidth = element.querySelector('.lines').style.width;
      const expectedWidth = Math.ceil(
        component.pixelPositionForScreenPosition(Point(3, Infinity)).left +
          component.getBaseCharacterWidth()
      );
      expect(actualWidth).toBe(expectedWidth + 'px');
    });
  });

  describe('synchronous updates', () => {
    let editorElementWasUpdatedSynchronously;

    beforeEach(() => {
      editorElementWasUpdatedSynchronously =
        TextEditorElement.prototype.updatedSynchronously;
    });

    afterEach(() => {
      TextEditorElement.prototype.setUpdatedSynchronously(
        editorElementWasUpdatedSynchronously
      );
    });

    it('updates synchronously when updatedSynchronously is true', () => {
      const editor = buildEditor();
      const { element } = new TextEditorComponent({
        model: editor,
        updatedSynchronously: true
      });
      jasmine.attachToDOM(element);

      editor.setText('Lorem ipsum dolor');
      expect(
        queryOnScreenLineElements(element).map(l => l.textContent)
      ).toEqual([editor.lineTextForScreenRow(0)]);
    });

    it('does not throw an exception on attachment when setting the soft-wrap column', () => {
      const { element, editor } = buildComponent({
        width: 435,
        attach: false,
        updatedSynchronously: true
      });
      editor.setSoftWrapped(true);
      spyOn(window, 'onerror').andCallThrough();
      jasmine.attachToDOM(element); // should not throw an exception
      expect(window.onerror).not.toHaveBeenCalled();
    });

    it('updates synchronously when creating a component via TextEditor and TextEditorElement.prototype.updatedSynchronously is true', () => {
      TextEditorElement.prototype.setUpdatedSynchronously(true);
      const editor = buildEditor();
      const element = editor.element;
      jasmine.attachToDOM(element);

      editor.setText('Lorem ipsum dolor');
      expect(
        queryOnScreenLineElements(element).map(l => l.textContent)
      ).toEqual([editor.lineTextForScreenRow(0)]);
    });

    it('measures dimensions synchronously when measureDimensions is called on the component', () => {
      TextEditorElement.prototype.setUpdatedSynchronously(true);
      const editor = buildEditor({ autoHeight: false });
      const element = editor.element;
      jasmine.attachToDOM(element);

      element.style.height = '100px';
      expect(element.component.getClientContainerHeight()).not.toBe(100);
      element.component.measureDimensions();
      expect(element.component.getClientContainerHeight()).toBe(100);
    });
  });

  describe('pixelPositionForScreenPosition(point)', () => {
    it('returns the pixel position for the given point, regardless of whether or not it is currently on screen', async () => {
      const { component, editor } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 3);
      await setScrollTop(component, 3 * component.getLineHeight());

      const { component: referenceComponent } = buildComponent();
      const referenceContentRect = referenceComponent.refs.content.getBoundingClientRect();

      {
        const { top, left } = component.pixelPositionForScreenPosition({
          row: 0,
          column: 0
        });
        expect(top).toBe(
          clientTopForLine(referenceComponent, 0) - referenceContentRect.top
        );
        expect(left).toBe(
          clientLeftForCharacter(referenceComponent, 0, 0) -
            referenceContentRect.left
        );
      }

      {
        const { top, left } = component.pixelPositionForScreenPosition({
          row: 0,
          column: 5
        });
        expect(top).toBe(
          clientTopForLine(referenceComponent, 0) - referenceContentRect.top
        );
        expect(left).toBeNear(
          clientLeftForCharacter(referenceComponent, 0, 5) -
            referenceContentRect.left
        );
      }

      {
        const { top, left } = component.pixelPositionForScreenPosition({
          row: 12,
          column: 1
        });
        expect(top).toBeNear(
          clientTopForLine(referenceComponent, 12) - referenceContentRect.top
        );
        expect(left).toBeNear(
          clientLeftForCharacter(referenceComponent, 12, 1) -
            referenceContentRect.left
        );
      }

      // Measuring a currently rendered line while an autoscroll that causes
      // that line to go off-screen is in progress.
      {
        editor.setCursorScreenPosition([10, 0]);
        const { top, left } = component.pixelPositionForScreenPosition({
          row: 3,
          column: 5
        });
        expect(top).toBeNear(
          clientTopForLine(referenceComponent, 3) - referenceContentRect.top
        );
        expect(left).toBeNear(
          clientLeftForCharacter(referenceComponent, 3, 5) -
            referenceContentRect.left
        );
      }
    });

    it('does not get the component into an inconsistent state when the model has unflushed changes (regression)', async () => {
      const { component, editor } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false,
        text: ''
      });
      await setEditorHeightInLines(component, 10);

      const updatePromise = editor.getBuffer().append('hi\n');
      component.screenPositionForPixelPosition({ top: 800, left: 1 });
      await updatePromise;
    });

    it('does not shift cursors downward or render off-screen content when measuring off-screen lines (regression)', async () => {
      const { component, element } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 3);
      component.pixelPositionForScreenPosition({
        row: 12,
        column: 1
      });

      expect(element.querySelector('.cursor').getBoundingClientRect().top).toBe(
        component.refs.lineTiles.getBoundingClientRect().top
      );
      expect(
        element.querySelector('.line[data-screen-row="12"]').style.visibility
      ).toBe('hidden');

      // Ensure previously measured off screen lines don't have any weird
      // styling when they come on screen in the next frame
      await setEditorHeightInLines(component, 13);
      const previouslyMeasuredLineElement = element.querySelector(
        '.line[data-screen-row="12"]'
      );
      expect(previouslyMeasuredLineElement.style.display).toBe('');
      expect(previouslyMeasuredLineElement.style.visibility).toBe('');
    });
  });

  describe('screenPositionForPixelPosition', () => {
    it('returns the screen position for the given pixel position, regardless of whether or not it is currently on screen', async () => {
      const { component, editor } = buildComponent({
        rowsPerTile: 2,
        autoHeight: false
      });
      await setEditorHeightInLines(component, 3);
      await setScrollTop(component, 3 * component.getLineHeight());
      const { component: referenceComponent } = buildComponent();

      {
        const pixelPosition = referenceComponent.pixelPositionForScreenPosition(
          { row: 0, column: 0 }
        );
        pixelPosition.top += component.getLineHeight() / 3;
        pixelPosition.left += component.getBaseCharacterWidth() / 3;
        expect(component.screenPositionForPixelPosition(pixelPosition)).toEqual(
          [0, 0]
        );
      }

      {
        const pixelPosition = referenceComponent.pixelPositionForScreenPosition(
          { row: 0, column: 5 }
        );
        pixelPosition.top += component.getLineHeight() / 3;
        pixelPosition.left += component.getBaseCharacterWidth() / 3;
        expect(component.screenPositionForPixelPosition(pixelPosition)).toEqual(
          [0, 5]
        );
      }

      {
        const pixelPosition = referenceComponent.pixelPositionForScreenPosition(
          { row: 5, column: 7 }
        );
        pixelPosition.top += component.getLineHeight() / 3;
        pixelPosition.left += component.getBaseCharacterWidth() / 3;
        expect(component.screenPositionForPixelPosition(pixelPosition)).toEqual(
          [5, 7]
        );
      }

      {
        const pixelPosition = referenceComponent.pixelPositionForScreenPosition(
          { row: 12, column: 1 }
        );
        pixelPosition.top += component.getLineHeight() / 3;
        pixelPosition.left += component.getBaseCharacterWidth() / 3;
        expect(component.screenPositionForPixelPosition(pixelPosition)).toEqual(
          [12, 1]
        );
      }

      // Measuring a currently rendered line while an autoscroll that causes
      // that line to go off-screen is in progress.
      {
        const pixelPosition = referenceComponent.pixelPositionForScreenPosition(
          { row: 3, column: 4 }
        );
        pixelPosition.top += component.getLineHeight() / 3;
        pixelPosition.left += component.getBaseCharacterWidth() / 3;
        editor.setCursorBufferPosition([10, 0]);
        expect(component.screenPositionForPixelPosition(pixelPosition)).toEqual(
          [3, 4]
        );
      }
    });
  });

  describe('model methods that delegate to the component / element', () => {
    it('delegates setHeight and getHeight to the component', async () => {
      const { component, editor } = buildComponent({
        autoHeight: false
      });
      spyOn(Grim, 'deprecate');
      expect(editor.getHeight()).toBe(component.getScrollContainerHeight());
      expect(Grim.deprecate.callCount).toBe(1);

      editor.setHeight(100);
      await component.getNextUpdatePromise();
      expect(component.getScrollContainerHeight()).toBe(100);
      expect(Grim.deprecate.callCount).toBe(2);
    });

    it('delegates setWidth and getWidth to the component', async () => {
      const { component, editor } = buildComponent();
      spyOn(Grim, 'deprecate');
      expect(editor.getWidth()).toBe(component.getScrollContainerWidth());
      expect(Grim.deprecate.callCount).toBe(1);

      editor.setWidth(100);
      await component.getNextUpdatePromise();
      expect(component.getScrollContainerWidth()).toBe(100);
      expect(Grim.deprecate.callCount).toBe(2);
    });

    it('delegates getFirstVisibleScreenRow, getLastVisibleScreenRow, and getVisibleRowRange to the component', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });
      element.style.height = 4 * component.measurements.lineHeight + 'px';
      await component.getNextUpdatePromise();
      await setScrollTop(component, 5 * component.getLineHeight());

      expect(editor.getFirstVisibleScreenRow()).toBe(
        component.getFirstVisibleRow()
      );
      expect(editor.getLastVisibleScreenRow()).toBe(
        component.getLastVisibleRow()
      );
      expect(editor.getVisibleRowRange()).toEqual([
        component.getFirstVisibleRow(),
        component.getLastVisibleRow()
      ]);
    });

    it('assigns scrollTop on the component when calling setFirstVisibleScreenRow', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });
      element.style.height =
        4 * component.measurements.lineHeight +
        horizontalScrollbarHeight +
        'px';
      await component.getNextUpdatePromise();

      expect(component.getMaxScrollTop() / component.getLineHeight()).toBeNear(
        9
      );
      expect(component.refs.verticalScrollbar.element.scrollTop).toBe(
        0 * component.getLineHeight()
      );

      editor.setFirstVisibleScreenRow(1);
      expect(component.getFirstVisibleRow()).toBe(1);
      await component.getNextUpdatePromise();
      expect(component.refs.verticalScrollbar.element.scrollTop).toBeNear(
        1 * component.getLineHeight()
      );

      editor.setFirstVisibleScreenRow(5);
      expect(component.getFirstVisibleRow()).toBe(5);
      await component.getNextUpdatePromise();
      expect(component.refs.verticalScrollbar.element.scrollTop).toBeNear(
        5 * component.getLineHeight()
      );

      editor.setFirstVisibleScreenRow(11);
      expect(component.getFirstVisibleRow()).toBe(9);
      await component.getNextUpdatePromise();
      expect(component.refs.verticalScrollbar.element.scrollTop).toBeNear(
        9 * component.getLineHeight()
      );
    });

    it('delegates setFirstVisibleScreenColumn and getFirstVisibleScreenColumn to the component', async () => {
      const { component, element, editor } = buildComponent({
        rowsPerTile: 3,
        autoHeight: false
      });
      element.style.width = 30 * component.getBaseCharacterWidth() + 'px';
      await component.getNextUpdatePromise();
      expect(editor.getFirstVisibleScreenColumn()).toBe(0);
      expect(component.refs.horizontalScrollbar.element.scrollLeft).toBe(0);

      setScrollLeft(component, 5.5 * component.getBaseCharacterWidth());
      expect(editor.getFirstVisibleScreenColumn()).toBe(5);
      await component.getNextUpdatePromise();
      expect(component.refs.horizontalScrollbar.element.scrollLeft).toBeCloseTo(
        5.5 * component.getBaseCharacterWidth(),
        -1
      );

      editor.setFirstVisibleScreenColumn(12);
      expect(component.getScrollLeft()).toBeCloseTo(
        12 * component.getBaseCharacterWidth(),
        -1
      );
      await component.getNextUpdatePromise();
      expect(component.refs.horizontalScrollbar.element.scrollLeft).toBeCloseTo(
        12 * component.getBaseCharacterWidth(),
        -1
      );
    });
  });

  describe('handleMouseDragUntilMouseUp', () => {
    it('repeatedly schedules `didDrag` calls on new animation frames after moving the mouse, and calls `didStopDragging` on mouseup', async () => {
      const { component } = buildComponent();

      let dragEvents;
      let dragging = false;
      component.handleMouseDragUntilMouseUp({
        didDrag: event => {
          dragging = true;
          dragEvents.push(event);
        },
        didStopDragging: () => {
          dragging = false;
        }
      });
      expect(dragging).toBe(false);

      dragEvents = [];
      const moveEvent1 = new MouseEvent('mousemove');
      window.dispatchEvent(moveEvent1);
      expect(dragging).toBe(false);
      await getNextAnimationFramePromise();
      expect(dragging).toBe(true);
      expect(dragEvents).toEqual([moveEvent1]);
      await getNextAnimationFramePromise();
      expect(dragging).toBe(true);
      expect(dragEvents).toEqual([moveEvent1, moveEvent1]);

      dragEvents = [];
      const moveEvent2 = new MouseEvent('mousemove');
      window.dispatchEvent(moveEvent2);
      expect(dragging).toBe(true);
      expect(dragEvents).toEqual([]);
      await getNextAnimationFramePromise();
      expect(dragging).toBe(true);
      expect(dragEvents).toEqual([moveEvent2]);
      await getNextAnimationFramePromise();
      expect(dragging).toBe(true);
      expect(dragEvents).toEqual([moveEvent2, moveEvent2]);

      dragEvents = [];
      window.dispatchEvent(new MouseEvent('mouseup'));
      expect(dragging).toBe(false);
      expect(dragEvents).toEqual([]);
      window.dispatchEvent(new MouseEvent('mousemove'));
      await getNextAnimationFramePromise();
      expect(dragging).toBe(false);
      expect(dragEvents).toEqual([]);
    });

    it('calls `didStopDragging` if the user interacts with the keyboard while dragging', async () => {
      const { component, editor } = buildComponent();

      let dragging = false;
      function startDragging() {
        component.handleMouseDragUntilMouseUp({
          didDrag: event => {
            dragging = true;
          },
          didStopDragging: () => {
            dragging = false;
          }
        });
      }

      startDragging();
      window.dispatchEvent(new MouseEvent('mousemove'));
      await getNextAnimationFramePromise();
      expect(dragging).toBe(true);

      // Buffer changes don't cause dragging to be stopped.
      editor.insertText('X');
      expect(dragging).toBe(true);

      // Keyboard interaction prevents users from dragging further.
      component.didKeydown({ code: 'KeyX' });
      expect(dragging).toBe(false);

      window.dispatchEvent(new MouseEvent('mousemove'));
      await getNextAnimationFramePromise();
      expect(dragging).toBe(false);

      // Pressing a modifier key does not terminate dragging, (to ensure we can add new selections with the mouse)
      startDragging();
      window.dispatchEvent(new MouseEvent('mousemove'));
      await getNextAnimationFramePromise();
      expect(dragging).toBe(true);
      component.didKeydown({ key: 'Control' });
      component.didKeydown({ key: 'Alt' });
      component.didKeydown({ key: 'Shift' });
      component.didKeydown({ key: 'Meta' });
      expect(dragging).toBe(true);
    });

    function getNextAnimationFramePromise() {
      return new Promise(resolve => requestAnimationFrame(resolve));
    }
  });
});

function buildEditor(params = {}) {
  const text = params.text != null ? params.text : SAMPLE_TEXT;
  const buffer = new TextBuffer({ text });
  const editorParams = { buffer, readOnly: params.readOnly };
  if (params.height != null) params.autoHeight = false;
  for (const paramName of [
    'mini',
    'autoHeight',
    'autoWidth',
    'lineNumberGutterVisible',
    'showLineNumbers',
    'placeholderText',
    'softWrapped',
    'scrollSensitivity'
  ]) {
    if (params[paramName] != null) editorParams[paramName] = params[paramName];
  }
  atom.grammars.autoAssignLanguageMode(buffer);
  const editor = new TextEditor(editorParams);
  editor.testAutoscrollRequests = [];
  editor.onDidRequestAutoscroll(request => {
    editor.testAutoscrollRequests.push(request);
  });
  editors.push(editor);
  return editor;
}

function buildComponent(params = {}) {
  const editor = params.editor || buildEditor(params);
  const component = new TextEditorComponent({
    model: editor,
    rowsPerTile: params.rowsPerTile,
    updatedSynchronously: params.updatedSynchronously || false,
    platform: params.platform,
    chromeVersion: params.chromeVersion
  });
  const { element } = component;
  if (!editor.getAutoHeight()) {
    element.style.height = params.height ? params.height + 'px' : '600px';
  }
  if (!editor.getAutoWidth()) {
    element.style.width = params.width ? params.width + 'px' : '800px';
  }
  if (params.attach !== false) jasmine.attachToDOM(element);
  return { component, element, editor };
}

function getEditorWidthInBaseCharacters(component) {
  return Math.round(
    component.getScrollContainerWidth() / component.getBaseCharacterWidth()
  );
}

async function setEditorHeightInLines(component, heightInLines) {
  component.element.style.height =
    component.getLineHeight() * heightInLines + 'px';
  await component.getNextUpdatePromise();
}

async function setEditorWidthInCharacters(component, widthInCharacters) {
  component.element.style.width =
    component.getGutterContainerWidth() +
    widthInCharacters * component.measurements.baseCharacterWidth +
    verticalScrollbarWidth +
    'px';
  await component.getNextUpdatePromise();
}

function verifyCursorPosition(component, cursorNode, row, column) {
  const rect = cursorNode.getBoundingClientRect();
  expect(Math.round(rect.top)).toBeNear(clientTopForLine(component, row));
  expect(Math.round(rect.left)).toBe(
    Math.round(clientLeftForCharacter(component, row, column))
  );
}

function clientTopForLine(component, row) {
  return lineNodeForScreenRow(component, row).getBoundingClientRect().top;
}

function clientLeftForCharacter(component, row, column) {
  const textNodes = textNodesForScreenRow(component, row);
  let textNodeStartColumn = 0;
  for (const textNode of textNodes) {
    const textNodeEndColumn = textNodeStartColumn + textNode.textContent.length;
    if (column < textNodeEndColumn) {
      const range = document.createRange();
      range.setStart(textNode, column - textNodeStartColumn);
      range.setEnd(textNode, column - textNodeStartColumn);
      return range.getBoundingClientRect().left;
    }
    textNodeStartColumn = textNodeEndColumn;
  }

  const lastTextNode = textNodes[textNodes.length - 1];
  const range = document.createRange();
  range.setStart(lastTextNode, 0);
  range.setEnd(lastTextNode, lastTextNode.textContent.length);
  return range.getBoundingClientRect().right;
}

function clientPositionForCharacter(component, row, column) {
  return {
    clientX: clientLeftForCharacter(component, row, column),
    clientY: clientTopForLine(component, row)
  };
}

function lineNumberNodeForScreenRow(component, row) {
  const gutterElement =
    component.refs.gutterContainer.refs.lineNumberGutter.element;
  const tileStartRow = component.tileStartRowForRow(row);
  const tileIndex = component.renderedTileStartRows.indexOf(tileStartRow);
  return gutterElement.children[tileIndex + 1].children[row - tileStartRow];
}

function lineNodeForScreenRow(component, row) {
  const renderedScreenLine = component.renderedScreenLineForRow(row);
  return component.lineComponentsByScreenLineId.get(renderedScreenLine.id)
    .element;
}

function textNodesForScreenRow(component, row) {
  const screenLine = component.renderedScreenLineForRow(row);
  return component.lineComponentsByScreenLineId.get(screenLine.id).textNodes;
}

function setScrollTop(component, scrollTop) {
  component.setScrollTop(scrollTop);
  component.scheduleUpdate();
  return component.getNextUpdatePromise();
}

function setScrollLeft(component, scrollLeft) {
  component.setScrollLeft(scrollLeft);
  component.scheduleUpdate();
  return component.getNextUpdatePromise();
}

function getHorizontalScrollbarHeight(component) {
  const element = component.refs.horizontalScrollbar.element;
  return element.offsetHeight - element.clientHeight;
}

function getVerticalScrollbarWidth(component) {
  const element = component.refs.verticalScrollbar.element;
  return element.offsetWidth - element.clientWidth;
}

function assertDocumentFocused() {
  if (!document.hasFocus()) {
    throw new Error('The document needs to be focused to run this test');
  }
}

function getElementHeight(element) {
  const topRuler = document.createElement('div');
  const bottomRuler = document.createElement('div');
  let height;
  if (document.body.contains(element)) {
    element.parentElement.insertBefore(topRuler, element);
    element.parentElement.insertBefore(bottomRuler, element.nextSibling);
    height = bottomRuler.offsetTop - topRuler.offsetTop;
  } else {
    jasmine.attachToDOM(topRuler);
    jasmine.attachToDOM(element);
    jasmine.attachToDOM(bottomRuler);
    height = bottomRuler.offsetTop - topRuler.offsetTop;
    element.remove();
  }

  topRuler.remove();
  bottomRuler.remove();
  return height;
}

function queryOnScreenLineNumberElements(element) {
  return Array.from(element.querySelectorAll('.line-number:not(.dummy)'));
}

<<<<<<< HEAD
          decoration.flash('flash-class', 500)
          await decorationsUpdatedPromise(editor)
          await nextViewUpdatePromise()

          expect(highlightNode.classList.contains('flash-class')).toBe(false)

          await conditionPromise(function () {
            return highlightNode.classList.contains('flash-class')
          })
        })
      })
    })

    describe('when a decoration\'s marker moves', function () {
      it('moves rendered highlights when the buffer is changed', async function () {
        let regionStyle = componentNode.querySelector('.test-highlight .region').style
        let originalTop = parseInt(regionStyle.top)
        expect(originalTop).toBe(2 * lineHeightInPixels)

        editor.getBuffer().insert([0, 0], '\n')
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        regionStyle = componentNode.querySelector('.test-highlight .region').style
        let newTop = parseInt(regionStyle.top)
        expect(newTop).toBe(0)
      })

      it('moves rendered highlights when the marker is manually moved', async function () {
        let regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe(2 * lineHeightInPixels)

        marker.setBufferRange([[5, 8], [5, 13]])
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        regionStyle = componentNode.querySelector('.test-highlight .region').style
        expect(parseInt(regionStyle.top)).toBe(2 * lineHeightInPixels)
      })
    })

    describe('when a decoration is updated via Decoration::update', function () {
      it('renders the decoration\'s new params', async function () {
        expect(componentNode.querySelector('.test-highlight')).toBeTruthy()
        decoration.setProperties({
          type: 'highlight',
          'class': 'new-test-highlight'
        })
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()
        expect(componentNode.querySelector('.test-highlight')).toBeFalsy()
        expect(componentNode.querySelector('.new-test-highlight')).toBeTruthy()
      })
    })
  })

  describe('overlay decoration rendering', function () {
    let gutterWidth, item

    beforeEach(function () {
      item = document.createElement('div')
      item.classList.add('overlay-test')
      item.style.background = 'red'
      gutterWidth = componentNode.querySelector('.gutter').offsetWidth
    })

    describe('when the marker is empty', function () {
      it('renders an overlay decoration when added and removes the overlay when the decoration is destroyed', async function () {
        let marker = editor.markBufferRange([[2, 13], [2, 13]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          item: item
        })
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
        expect(overlay).toBe(item)

        decoration.destroy()
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        overlay = component.getTopmostDOMNode().querySelector('atom-overlay .overlay-test')
        expect(overlay).toBe(null)
      })

      it('renders the overlay element with the CSS class specified by the decoration', async function () {
        let marker = editor.markBufferRange([[2, 13], [2, 13]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          'class': 'my-overlay',
          item: item
        })

        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay.my-overlay')
        expect(overlay).not.toBe(null)
        let child = overlay.querySelector('.overlay-test')
        expect(child).toBe(item)
      })
    })

    describe('when the marker is not empty', function () {
      it('renders at the head of the marker by default', async function () {
        let marker = editor.markBufferRange([[2, 5], [2, 10]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          item: item
        })

        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        let position = wrapperNode.pixelPositionForBufferPosition([2, 10])
        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
        expect(overlay.style.left).toBe(Math.round(position.left + gutterWidth) + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')
      })
    })

    describe('positioning the overlay when near the edge of the editor', function () {
      let itemHeight, itemWidth, windowHeight, windowWidth

      beforeEach(async function () {
        atom.storeWindowDimensions()
        itemWidth = Math.round(4 * editor.getDefaultCharWidth())
        itemHeight = 4 * editor.getLineHeightInPixels()
        windowWidth = Math.round(gutterWidth + 30 * editor.getDefaultCharWidth())
        windowHeight = 10 * editor.getLineHeightInPixels()
        item.style.width = itemWidth + 'px'
        item.style.height = itemHeight + 'px'
        wrapperNode.style.width = windowWidth + 'px'
        wrapperNode.style.height = windowHeight + 'px'
        await atom.setWindowDimensions({
          width: windowWidth,
          height: windowHeight
        })

        component.measureDimensions()
        component.measureWindowSize()
        await nextViewUpdatePromise()
      })

      afterEach(function () {
        atom.restoreWindowDimensions()
      })

      it('slides horizontally left when near the right edge on #win32 and #darwin', async function () {
        let marker = editor.markBufferRange([[0, 26], [0, 26]], {
          invalidate: 'never'
        })
        let decoration = editor.decorateMarker(marker, {
          type: 'overlay',
          item: item
        })
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        let position = wrapperNode.pixelPositionForBufferPosition([0, 26])
        let overlay = component.getTopmostDOMNode().querySelector('atom-overlay')
        expect(overlay.style.left).toBe(Math.round(position.left + gutterWidth) + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')

        editor.insertText('a')
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        expect(overlay.style.left).toBe(windowWidth - itemWidth + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')

        editor.insertText('b')
        await decorationsUpdatedPromise(editor)
        await nextViewUpdatePromise()

        expect(overlay.style.left).toBe(windowWidth - itemWidth + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')

        // window size change

        windowWidth = Math.round(gutterWidth + 29 * editor.getDefaultCharWidth())
        await atom.setWindowDimensions({
          width: windowWidth,
          height: windowHeight,
        })
        atom.views.performDocumentPoll()
        expect(overlay.style.left).toBe(windowWidth - itemWidth + 'px')
        expect(overlay.style.top).toBe(position.top + editor.getLineHeightInPixels() + 'px')
      })
    })
  })

  describe('hidden input field', function () {
    it('renders the hidden input field at the position of the last cursor if the cursor is on screen and the editor is focused', async function () {
      editor.setVerticalScrollMargin(0)
      editor.setHorizontalScrollMargin(0)
      let inputNode = componentNode.querySelector('.hidden-input')
      wrapperNode.style.height = 5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(editor.getCursorScreenPosition()).toEqual([0, 0])

      wrapperNode.setScrollTop(3 * lineHeightInPixels)
      wrapperNode.setScrollLeft(3 * charWidth)
      await nextViewUpdatePromise()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      editor.setCursorBufferPosition([5, 4], {
        autoscroll: false
      })
      await decorationsUpdatedPromise(editor)
      await nextViewUpdatePromise()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      wrapperNode.focus()
      await nextViewUpdatePromise()

      expect(inputNode.offsetTop).toBe((5 * lineHeightInPixels) - wrapperNode.getScrollTop())
      expect(inputNode.offsetLeft).toBeCloseTo((4 * charWidth) - wrapperNode.getScrollLeft(), 0)

      inputNode.blur()
      await nextViewUpdatePromise()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      editor.setCursorBufferPosition([1, 2], {
        autoscroll: false
      })
      await nextViewUpdatePromise()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)

      inputNode.focus()
      await nextViewUpdatePromise()

      expect(inputNode.offsetTop).toBe(0)
      expect(inputNode.offsetLeft).toBe(0)
    })
  })

  describe('mouse interactions on the lines', function () {
    let linesNode

    beforeEach(function () {
      linesNode = componentNode.querySelector('.lines')
    })

    describe('when the mouse is single-clicked above the first line', function () {
      it('moves the cursor to the start of file buffer position', async function () {
        let height
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 3])
        height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        let coordinates = clientCoordinatesForScreenPosition([0, 2])
        coordinates.clientY = -1
        linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))

        await nextViewUpdatePromise()
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])
      })
    })

    describe('when the mouse is single-clicked below the last line', function () {
      it('moves the cursor to the end of file buffer position', async function () {
        editor.setText('foo')
        editor.setCursorBufferPosition([0, 0])
        let height = 4.5 * lineHeightInPixels
        wrapperNode.style.height = height + 'px'
        wrapperNode.style.width = 10 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        let coordinates = clientCoordinatesForScreenPosition([0, 2])
        coordinates.clientY = height * 2

        linesNode.dispatchEvent(buildMouseEvent('mousedown', coordinates))
        await nextViewUpdatePromise()

        expect(editor.getCursorScreenPosition()).toEqual([0, 3])
      })
    })

    describe('when a non-folded line is single-clicked', function () {
      describe('when no modifier keys are held down', function () {
        it('moves the cursor to the nearest screen position', async function () {
          wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
          wrapperNode.style.width = 10 * charWidth + 'px'
          component.measureDimensions()
          wrapperNode.setScrollTop(3.5 * lineHeightInPixels)
          wrapperNode.setScrollLeft(2 * charWidth)
          await nextViewUpdatePromise()
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8])))
          await nextViewUpdatePromise()
          expect(editor.getCursorScreenPosition()).toEqual([4, 8])
        })
      })

      describe('when the shift key is held down', function () {
        it('selects to the nearest screen position', async function () {
          editor.setCursorScreenPosition([3, 4])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), {
            shiftKey: true
          }))
          await nextViewUpdatePromise()
          expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [5, 6]])
        })
      })

      describe('when the command key is held down', function () {
        describe('the current cursor position and screen position do not match', function () {
          it('adds a cursor at the nearest screen position', async function () {
            editor.setCursorScreenPosition([3, 4])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 6]), {
              metaKey: true
            }))
            await nextViewUpdatePromise()
            expect(editor.getSelectedScreenRanges()).toEqual([[[3, 4], [3, 4]], [[5, 6], [5, 6]]])
          })
        })

        describe('when there are multiple cursors, and one of the cursor\'s screen position is the same as the mouse click screen position', async function () {
          it('removes a cursor at the mouse screen position', async function () {
            editor.setCursorScreenPosition([3, 4])
            editor.addCursorAtScreenPosition([5, 2])
            editor.addCursorAtScreenPosition([7, 5])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([3, 4]), {
              metaKey: true
            }))
            await nextViewUpdatePromise()
            expect(editor.getSelectedScreenRanges()).toEqual([[[5, 2], [5, 2]], [[7, 5], [7, 5]]])
          })
        })

        describe('when there is a single cursor and the click occurs at the cursor\'s screen position', async function () {
          it('neither adds a new cursor nor removes the current cursor', async function () {
            editor.setCursorScreenPosition([3, 4])
            linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([3, 4]), {
              metaKey: true
            }))
            await nextViewUpdatePromise()
            expect(editor.getSelectedScreenRanges()).toEqual([[[3, 4], [3, 4]]])
          })
        })
      })
    })

    describe('when a non-folded line is double-clicked', function () {
      describe('when no modifier keys are held down', function () {
        it('selects the word containing the nearest screen position', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [5, 13]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[6, 6], [6, 6]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), {
            detail: 1,
            shiftKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[6, 6], [8, 8]])
        })
      })

      describe('when the command key is held down', function () {
        it('selects the word containing the newly-added cursor', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRanges()).toEqual([[[0, 0], [0, 0]], [[5, 6], [5, 13]]])
        })
      })
    })

    describe('when a non-folded line is triple-clicked', function () {
      describe('when no modifier keys are held down', function () {
        it('selects the line containing the nearest screen position', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 3
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [6, 0]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([6, 6]), {
            detail: 1,
            shiftKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [7, 0]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([7, 5]), {
            detail: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([8, 8]), {
            detail: 1,
            shiftKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRange()).toEqual([[7, 5], [8, 8]])
        })
      })

      describe('when the command key is held down', function () {
        it('selects the line containing the newly-added cursor', function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 1,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 2,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
            detail: 3,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mouseup'))
          expect(editor.getSelectedScreenRanges()).toEqual([[[0, 0], [0, 0]], [[5, 0], [6, 0]]])
        })
      })
    })

    describe('when the mouse is clicked and dragged', function () {
      it('selects to the nearest screen position until the mouse button is released', async function () {
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
          which: 1
        }))
        await nextAnimationFramePromise()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), {
          which: 1
        }))
        await nextAnimationFramePromise()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [10, 0]])
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([12, 0]), {
          which: 1
        }))
        await nextAnimationFramePromise()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [10, 0]])
      })

      it('autoscrolls when the cursor approaches the boundaries of the editor', async function () {
        wrapperNode.style.height = '100px'
        wrapperNode.style.width = '100px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBe(0)

        linesNode.dispatchEvent(buildMouseEvent('mousedown', {
          clientX: 0,
          clientY: 0
        }, {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 100,
          clientY: 50
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          await nextAnimationFramePromise()
        }

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBeGreaterThan(0)
        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 100,
          clientY: 100
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          await nextAnimationFramePromise()
        }

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        let previousScrollTop = wrapperNode.getScrollTop()
        let previousScrollLeft = wrapperNode.getScrollLeft()

        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 10,
          clientY: 50
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          await nextAnimationFramePromise()
        }

        expect(wrapperNode.getScrollTop()).toBe(previousScrollTop)
        expect(wrapperNode.getScrollLeft()).toBeLessThan(previousScrollLeft)
        linesNode.dispatchEvent(buildMouseEvent('mousemove', {
          clientX: 10,
          clientY: 10
        }, {
          which: 1
        }))

        for (let i = 0; i <= 5; ++i) {
          await nextAnimationFramePromise()
        }

        expect(wrapperNode.getScrollTop()).toBeLessThan(previousScrollTop)
      })

      it('stops selecting if the mouse is dragged into the dev tools', async function () {
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
          which: 1
        }))
        await nextAnimationFramePromise()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([10, 0]), {
          which: 0
        }))
        await nextAnimationFramePromise()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), {
          which: 1
        }))
        await nextAnimationFramePromise()
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])
      })

      it('stops selecting before the buffer is modified during the drag', async function () {
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
          which: 1
        }))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [6, 8]])

        editor.insertText('x')
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 5], [2, 5]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), {
          which: 1
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 5], [2, 5]])

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
          which: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([5, 4]), {
          which: 1
        }))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [5, 4]])

        editor.delete()
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [2, 4]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 0]), {
          which: 1
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 4], [2, 4]])
      })

      describe('when the command key is held down', function () {
        it('adds a new selection and selects to the nearest screen position, then merges intersecting selections when the mouse button is released', async function () {
          editor.setSelectedScreenRange([[4, 4], [4, 9]])
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
            which: 1,
            metaKey: true
          }))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
            which: 1
          }))
          await nextAnimationFramePromise()

          expect(editor.getSelectedScreenRanges()).toEqual([[[4, 4], [4, 9]], [[2, 4], [6, 8]]])

          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([4, 6]), {
            which: 1
          }))
          await nextAnimationFramePromise()

          expect(editor.getSelectedScreenRanges()).toEqual([[[4, 4], [4, 9]], [[2, 4], [4, 6]]])
          linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([4, 6]), {
            which: 1
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[2, 4], [4, 9]]])
        })
      })

      describe('when the editor is destroyed while dragging', function () {
        it('cleans up the handlers for window.mouseup and window.mousemove', async function () {
          linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([2, 4]), {
            which: 1
          }))
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 8]), {
            which: 1
          }))
          await nextAnimationFramePromise()

          spyOn(window, 'removeEventListener').andCallThrough()
          linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([6, 10]), {
            which: 1
          }))

          editor.destroy()
          await nextAnimationFramePromise()

          for (let call of window.removeEventListener.calls) {
            call.args.pop()
          }
          expect(window.removeEventListener).toHaveBeenCalledWith('mouseup')
          expect(window.removeEventListener).toHaveBeenCalledWith('mousemove')
        })
      })
    })

    describe('when the mouse is double-clicked and dragged', function () {
      it('expands the selection over the nearest word as the cursor moves', async function () {
        jasmine.attachToDOM(wrapperNode)
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 2
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [5, 13]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([11, 11]), {
          which: 1
        }))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [12, 2]])
        let maximalScrollTop = wrapperNode.getScrollTop()
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([9, 3]), {
          which: 1
        }))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 6], [9, 4]])
        expect(wrapperNode.getScrollTop()).toBe(maximalScrollTop)
        linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([9, 3]), {
          which: 1
        }))
      })
    })

    describe('when the mouse is triple-clicked and dragged', function () {
      it('expands the selection over the nearest line as the cursor moves', async function () {
        jasmine.attachToDOM(wrapperNode)
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 1
        }))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 2
        }))
        linesNode.dispatchEvent(buildMouseEvent('mouseup'))
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([5, 10]), {
          detail: 3
        }))
        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [6, 0]])
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([11, 11]), {
          which: 1
        }))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [12, 2]])
        let maximalScrollTop = wrapperNode.getScrollTop()
        linesNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenPosition([8, 4]), {
          which: 1
        }))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[5, 0], [8, 0]])
        expect(wrapperNode.getScrollTop()).toBe(maximalScrollTop)
        linesNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([9, 3]), {
          which: 1
        }))
      })
    })

    describe('when a fold marker is clicked', function () {
      function clickElementAtPosition (marker, position) {
        linesNode.dispatchEvent(
          buildMouseEvent('mousedown', clientCoordinatesForScreenPosition(position), {target: marker})
        )
      }

      it('unfolds only the selected fold when other folds are on the same line', async function () {
        editor.foldBufferRange([[4, 6], [4, 10]])
        editor.foldBufferRange([[4, 15], [4, 20]])
        await nextViewUpdatePromise()
        let foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(2)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 6])
        await nextViewUpdatePromise()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 15])
        await nextViewUpdatePromise()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(0)
        expect(editor.isFoldedAtBufferRow(4)).toBe(false)
      })

      it('unfolds only the selected fold when other folds are inside it', async function () {
        editor.foldBufferRange([[4, 10], [4, 15]])
        editor.foldBufferRange([[4, 4], [4, 5]])
        editor.foldBufferRange([[4, 4], [4, 20]])
        await nextViewUpdatePromise()
        let foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 4])
        await nextViewUpdatePromise()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 4])
        await nextViewUpdatePromise()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(1)
        expect(editor.isFoldedAtBufferRow(4)).toBe(true)

        clickElementAtPosition(foldMarkers[0], [4, 10])
        await nextViewUpdatePromise()
        foldMarkers = component.lineNodeForScreenRow(4).querySelectorAll('.fold-marker')
        expect(foldMarkers.length).toBe(0)
        expect(editor.isFoldedAtBufferRow(4)).toBe(false)
      })
    })

    describe('when the horizontal scrollbar is interacted with', function () {
      it('clicking on the scrollbar does not move the cursor', function () {
        let target = horizontalScrollbarNode
        linesNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([4, 8]), {
          target: target
        }))
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])
      })
    })
  })

  describe('mouse interactions on the gutter', function () {
    let gutterNode

    beforeEach(function () {
      gutterNode = componentNode.querySelector('.gutter')
    })

    describe('when the component is destroyed', function () {
      it('stops listening for selection events', function () {
        component.destroy()
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
        expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [0, 0]])
      })
    })

    describe('when the gutter is clicked', function () {
      it('selects the clicked row', function () {
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4)))
        expect(editor.getSelectedScreenRange()).toEqual([[4, 0], [5, 0]])
      })
    })

    describe('when the gutter is meta-clicked', function () {
      it('creates a new selection for the clicked row', function () {
        editor.setSelectedScreenRange([[3, 0], [3, 2]])
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), {
          metaKey: true
        }))
        expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [5, 0]]])
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
          metaKey: true
        }))
        expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [5, 0]], [[6, 0], [7, 0]]])
      })
    })

    describe('when the gutter is shift-clicked', function () {
      beforeEach(function () {
        editor.setSelectedScreenRange([[3, 4], [4, 5]])
      })

      describe('when the clicked row is before the current selection\'s tail', function () {
        it('selects to the beginning of the clicked row', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
            shiftKey: true
          }))
          expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [3, 4]])
        })
      })

      describe('when the clicked row is after the current selection\'s tail', function () {
        it('selects to the beginning of the row following the clicked row', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
            shiftKey: true
          }))
          expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [7, 0]])
        })
      })
    })

    describe('when the gutter is clicked and dragged', function () {
      describe('when dragging downward', function () {
        it('selects the rows between the start and end of the drag', async function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
          await nextAnimationFramePromise()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
          expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [7, 0]])
        })
      })

      describe('when dragging upward', function () {
        it('selects the rows between the start and end of the drag', async function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
          await nextAnimationFramePromise()
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2)))
          expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [7, 0]])
        })
      })

      it('orients the selection appropriately when the mouse moves above or below the initially-clicked row', async function () {
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
        await nextAnimationFramePromise()
        expect(editor.getLastSelection().isReversed()).toBe(true)
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
        await nextAnimationFramePromise()
        expect(editor.getLastSelection().isReversed()).toBe(false)
      })

      it('autoscrolls when the cursor approaches the top or bottom of the editor', async function () {
        wrapperNode.style.height = 6 * lineHeightInPixels + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)

        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
        await nextAnimationFramePromise()

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        let maxScrollTop = wrapperNode.getScrollTop()

        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(10)))
        await nextAnimationFramePromise()

        expect(wrapperNode.getScrollTop()).toBe(maxScrollTop)

        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
        await nextAnimationFramePromise()

        expect(wrapperNode.getScrollTop()).toBeLessThan(maxScrollTop)
      })

      it('stops selecting if a textInput event occurs during the drag', async function () {
        gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2)))
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [7, 0]])

        let inputEvent = new Event('textInput')
        inputEvent.data = 'x'
        Object.defineProperty(inputEvent, 'target', {
          get: function () {
            return componentNode.querySelector('.hidden-input')
          }
        })
        componentNode.dispatchEvent(inputEvent)
        await nextAnimationFramePromise()

        expect(editor.getSelectedScreenRange()).toEqual([[2, 1], [2, 1]])
        gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(12)))
        expect(editor.getSelectedScreenRange()).toEqual([[2, 1], [2, 1]])
      })
    })

    describe('when the gutter is meta-clicked and dragged', function () {
      beforeEach(function () {
        editor.setSelectedScreenRange([[3, 0], [3, 2]])
      })

      describe('when dragging downward', function () {
        it('selects the rows between the start and end of the drag', async function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(4), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          await nextAnimationFramePromise()

          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [7, 0]]])
        })

        it('merges overlapping selections when the mouse button is released', async function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          await nextAnimationFramePromise()

          expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[2, 0], [7, 0]]])
          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[2, 0], [7, 0]]])
        })
      })

      describe('when dragging upward', function () {
        it('selects the rows between the start and end of the drag', async function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(4), {
            metaKey: true
          }))
          await nextAnimationFramePromise()

          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(4), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[3, 0], [3, 2]], [[4, 0], [7, 0]]])
        })

        it('merges overlapping selections', async function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6), {
            metaKey: true
          }))
          gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          await nextAnimationFramePromise()

          gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[2, 0], [7, 0]]])
        })
      })
    })

    describe('when the gutter is shift-clicked and dragged', function () {
      describe('when the shift-click is below the existing selection\'s tail', function () {
        describe('when dragging downward', function () {
          it('selects the rows between the existing selection\'s tail and the end of the drag', async function () {
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            await nextAnimationFramePromise()
            expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [9, 0]])
          })
        })

        describe('when dragging upward', function () {
          it('selects the rows between the end of the drag and the tail of the existing selection', async function () {
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5)))
            await nextAnimationFramePromise()
            expect(editor.getSelectedScreenRange()).toEqual([[4, 4], [6, 0]])
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            await nextAnimationFramePromise()
            expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [4, 4]])
          })
        })
      })

      describe('when the shift-click is above the existing selection\'s tail', function () {
        describe('when dragging upward', function () {
          it('selects the rows between the end of the drag and the tail of the existing selection', async function () {
            editor.setSelectedScreenRange([[4, 4], [5, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            await nextAnimationFramePromise()
            expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [4, 4]])
          })
        })

        describe('when dragging downward', function () {
          it('selects the rows between the existing selection\'s tail and the end of the drag', async function () {
            editor.setSelectedScreenRange([[3, 4], [4, 5]])
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              shiftKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(2)))
            await nextAnimationFramePromise()
            expect(editor.getSelectedScreenRange()).toEqual([[2, 0], [3, 4]])
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(8)))
            await nextAnimationFramePromise()
            expect(editor.getSelectedScreenRange()).toEqual([[3, 4], [9, 0]])
          })
        })
      })
    })

    describe('when soft wrap is enabled', function () {
      beforeEach(async function () {
        gutterNode = componentNode.querySelector('.gutter')
        editor.setSoftWrapped(true)
        await nextViewUpdatePromise()
        componentNode.style.width = 21 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()
      })

      describe('when the gutter is clicked', function () {
        it('selects the clicked buffer row', function () {
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
          expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [2, 0]])
        })
      })

      describe('when the gutter is meta-clicked', function () {
        it('creates a new selection for the clicked buffer row', function () {
          editor.setSelectedScreenRange([[1, 0], [1, 2]])
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(2), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[1, 0], [1, 2]], [[2, 0], [5, 0]]])
          gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
            metaKey: true
          }))
          expect(editor.getSelectedScreenRanges()).toEqual([[[1, 0], [1, 2]], [[2, 0], [5, 0]], [[5, 0], [10, 0]]])
        })
      })

      describe('when the gutter is shift-clicked', function () {
        beforeEach(function () {
          return editor.setSelectedScreenRange([[7, 4], [7, 6]])
        })

        describe('when the clicked row is before the current selection\'s tail', function () {
          it('selects to the beginning of the clicked buffer row', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              shiftKey: true
            }))
            expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [7, 4]])
          })
        })

        describe('when the clicked row is after the current selection\'s tail', function () {
          it('selects to the beginning of the screen row following the clicked buffer row', function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), {
              shiftKey: true
            }))
            expect(editor.getSelectedScreenRange()).toEqual([[7, 4], [17, 0]])
          })
        })
      })

      describe('when the gutter is clicked and dragged', function () {
        describe('when dragging downward', function () {
          it('selects the buffer row containing the click, then screen rows until the end of the drag', async function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(6)))
            await nextAnimationFramePromise()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(6)))
            expect(editor.getSelectedScreenRange()).toEqual([[0, 0], [6, 14]])
          })
        })

        describe('when dragging upward', function () {
          it('selects the buffer row containing the click, then screen rows until the end of the drag', async function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(6)))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
            await nextAnimationFramePromise()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(1)))
            expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [10, 0]])
          })
        })
      })

      describe('when the gutter is meta-clicked and dragged', function () {
        beforeEach(function () {
          editor.setSelectedScreenRange([[7, 4], [7, 6]])
        })

        describe('when dragging downward', function () {
          it('adds a selection from the buffer row containing the click to the screen row containing the end of the drag', async function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3), {
              metaKey: true
            }))
            await nextAnimationFramePromise()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(3), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[7, 4], [7, 6]], [[0, 0], [3, 14]]])
          })

          it('merges overlapping selections on mouseup', async function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7), {
              metaKey: true
            }))
            await nextAnimationFramePromise()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(7), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[0, 0], [7, 12]]])
          })
        })

        describe('when dragging upward', function () {
          it('adds a selection from the buffer row containing the click to the screen row containing the end of the drag', async function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11), {
              metaKey: true
            }))
            await nextAnimationFramePromise()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(11), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[7, 4], [7, 6]], [[11, 4], [20, 0]]])
          })

          it('merges overlapping selections on mouseup', async function () {
            gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(17), {
              metaKey: true
            }))
            gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(5), {
              metaKey: true
            }))
            await nextAnimationFramePromise()
            gutterNode.dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenRowInGutter(5), {
              metaKey: true
            }))
            expect(editor.getSelectedScreenRanges()).toEqual([[[5, 0], [20, 0]]])
          })
        })
      })

      describe('when the gutter is shift-clicked and dragged', function () {
        describe('when the shift-click is below the existing selection\'s tail', function () {
          describe('when dragging downward', function () {
            it('selects the screen rows between the existing selection\'s tail and the end of the drag', async function () {
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(7), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(11)))
              await nextAnimationFramePromise()
              expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [11, 5]])
            })
          })

          describe('when dragging upward', function () {
            it('selects the screen rows between the end of the drag and the tail of the existing selection', async function () {
              editor.setSelectedScreenRange([[1, 4], [1, 7]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(11), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(7)))
              await nextAnimationFramePromise()
              expect(editor.getSelectedScreenRange()).toEqual([[1, 4], [7, 12]])
            })
          })
        })

        describe('when the shift-click is above the existing selection\'s tail', function () {
          describe('when dragging upward', function () {
            it('selects the screen rows between the end of the drag and the tail of the existing selection', async function () {
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(3), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(1)))
              await nextAnimationFramePromise()
              expect(editor.getSelectedScreenRange()).toEqual([[1, 0], [7, 4]])
            })
          })

          describe('when dragging downward', function () {
            it('selects the screen rows between the existing selection\'s tail and the end of the drag', async function () {
              editor.setSelectedScreenRange([[7, 4], [7, 6]])
              gutterNode.dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenRowInGutter(1), {
                shiftKey: true
              }))
              gutterNode.dispatchEvent(buildMouseEvent('mousemove', clientCoordinatesForScreenRowInGutter(3)))
              await nextAnimationFramePromise()
              expect(editor.getSelectedScreenRange()).toEqual([[3, 2], [7, 4]])
            })
          })
        })
      })
    })
  })

  describe('focus handling', async function () {
    let inputNode
    beforeEach(function () {
      inputNode = componentNode.querySelector('.hidden-input')
    })

    it('transfers focus to the hidden input', function () {
      expect(document.activeElement).toBe(document.body)
      wrapperNode.focus()
      expect(document.activeElement).toBe(wrapperNode)
      expect(wrapperNode.shadowRoot.activeElement).toBe(inputNode)
    })

    it('adds the "is-focused" class to the editor when the hidden input is focused', async function () {
      expect(document.activeElement).toBe(document.body)
      inputNode.focus()
      await nextViewUpdatePromise()

      expect(componentNode.classList.contains('is-focused')).toBe(true)
      expect(wrapperNode.classList.contains('is-focused')).toBe(true)
      inputNode.blur()
      await nextViewUpdatePromise()

      expect(componentNode.classList.contains('is-focused')).toBe(false)
      expect(wrapperNode.classList.contains('is-focused')).toBe(false)
    })
  })

  describe('selection handling', function () {
    let cursor

    beforeEach(async function () {
      editor.setCursorScreenPosition([0, 0])
      await nextViewUpdatePromise()
    })

    it('adds the "has-selection" class to the editor when there is a selection', async function () {
      expect(componentNode.classList.contains('has-selection')).toBe(false)
      editor.selectDown()
      await nextViewUpdatePromise()
      expect(componentNode.classList.contains('has-selection')).toBe(true)
      editor.moveDown()
      await nextViewUpdatePromise()
      expect(componentNode.classList.contains('has-selection')).toBe(false)
    })
  })

  describe('scrolling', function () {
    it('updates the vertical scrollbar when the scrollTop is changed in the model', async function () {
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()
      expect(verticalScrollbarNode.scrollTop).toBe(0)
      wrapperNode.setScrollTop(10)
      await nextViewUpdatePromise()
      expect(verticalScrollbarNode.scrollTop).toBe(10)
    })

    it('updates the horizontal scrollbar and the x transform of the lines based on the scrollLeft of the model', async function () {
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      let top = 0
      let tilesNodes = component.tileNodesForLines()
      for (let tileNode of tilesNodes) {
        expect(tileNode.style['-webkit-transform']).toBe('translate3d(0px, ' + top + 'px, 0px)')
        top += tileNode.offsetHeight
      }
      expect(horizontalScrollbarNode.scrollLeft).toBe(0)
      wrapperNode.setScrollLeft(100)

      await nextViewUpdatePromise()

      top = 0
      for (let tileNode of tilesNodes) {
        expect(tileNode.style['-webkit-transform']).toBe('translate3d(-100px, ' + top + 'px, 0px)')
        top += tileNode.offsetHeight
      }
      expect(horizontalScrollbarNode.scrollLeft).toBe(100)
    })

    it('updates the scrollLeft of the model when the scrollLeft of the horizontal scrollbar changes', async function () {
      componentNode.style.width = 30 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()
      expect(wrapperNode.getScrollLeft()).toBe(0)
      horizontalScrollbarNode.scrollLeft = 100
      horizontalScrollbarNode.dispatchEvent(new UIEvent('scroll'))
      await nextViewUpdatePromise()
      expect(wrapperNode.getScrollLeft()).toBe(100)
    })

    it('does not obscure the last line with the horizontal scrollbar', async function () {
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      wrapperNode.setScrollBottom(wrapperNode.getScrollHeight())
      await nextViewUpdatePromise()

      let lastLineNode = component.lineNodeForScreenRow(editor.getLastScreenRow())
      let bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
      topOfHorizontalScrollbar = horizontalScrollbarNode.getBoundingClientRect().top
      expect(bottomOfLastLine).toBe(topOfHorizontalScrollbar)
      wrapperNode.style.width = 100 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      bottomOfLastLine = lastLineNode.getBoundingClientRect().bottom
      let bottomOfEditor = componentNode.getBoundingClientRect().bottom
      expect(bottomOfLastLine).toBe(bottomOfEditor)
    })

    it('does not obscure the last character of the longest line with the vertical scrollbar', async function () {
      wrapperNode.style.height = 7 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      wrapperNode.setScrollLeft(Infinity)

      await nextViewUpdatePromise()
      let rightOfLongestLine = component.lineNodeForScreenRow(6).querySelector('.line > span:last-child').getBoundingClientRect().right
      let leftOfVerticalScrollbar = verticalScrollbarNode.getBoundingClientRect().left
      expect(Math.round(rightOfLongestLine)).toBeCloseTo(leftOfVerticalScrollbar - 1, 0)
    })

    it('only displays dummy scrollbars when scrollable in that direction', async function () {
      expect(verticalScrollbarNode.style.display).toBe('none')
      expect(horizontalScrollbarNode.style.display).toBe('none')
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(verticalScrollbarNode.style.display).toBe('')
      expect(horizontalScrollbarNode.style.display).toBe('none')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(verticalScrollbarNode.style.display).toBe('')
      expect(horizontalScrollbarNode.style.display).toBe('')
      wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(verticalScrollbarNode.style.display).toBe('none')
      expect(horizontalScrollbarNode.style.display).toBe('')
    })

    it('makes the dummy scrollbar divs only as tall/wide as the actual scrollbars', async function () {
      wrapperNode.style.height = 4 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      atom.styles.addStyleSheet('::-webkit-scrollbar {\n  width: 8px;\n  height: 8px;\n}', {
        context: 'atom-text-editor'
      })

      await nextAnimationFramePromise()
      await nextAnimationFramePromise()

      let scrollbarCornerNode = componentNode.querySelector('.scrollbar-corner')
      expect(verticalScrollbarNode.offsetWidth).toBe(8)
      expect(horizontalScrollbarNode.offsetHeight).toBe(8)
      expect(scrollbarCornerNode.offsetWidth).toBe(8)
      expect(scrollbarCornerNode.offsetHeight).toBe(8)
      atom.themes.removeStylesheet('test')
    })

    it('assigns the bottom/right of the scrollbars to the width of the opposite scrollbar if it is visible', async function () {
      let scrollbarCornerNode = componentNode.querySelector('.scrollbar-corner')
      expect(verticalScrollbarNode.style.bottom).toBe('0px')
      expect(horizontalScrollbarNode.style.right).toBe('0px')
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = '1000px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(verticalScrollbarNode.style.bottom).toBe('0px')
      expect(horizontalScrollbarNode.style.right).toBe(verticalScrollbarNode.offsetWidth + 'px')
      expect(scrollbarCornerNode.style.display).toBe('none')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(verticalScrollbarNode.style.bottom).toBe(horizontalScrollbarNode.offsetHeight + 'px')
      expect(horizontalScrollbarNode.style.right).toBe(verticalScrollbarNode.offsetWidth + 'px')
      expect(scrollbarCornerNode.style.display).toBe('')
      wrapperNode.style.height = 20 * lineHeightInPixels + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(verticalScrollbarNode.style.bottom).toBe(horizontalScrollbarNode.offsetHeight + 'px')
      expect(horizontalScrollbarNode.style.right).toBe('0px')
      expect(scrollbarCornerNode.style.display).toBe('none')
    })

    it('accounts for the width of the gutter in the scrollWidth of the horizontal scrollbar', async function () {
      let gutterNode = componentNode.querySelector('.gutter')
      componentNode.style.width = 10 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      expect(horizontalScrollbarNode.scrollWidth).toBe(wrapperNode.getScrollWidth())
      expect(horizontalScrollbarNode.style.left).toBe('0px')
    })
  })

  describe('mousewheel events', function () {
    beforeEach(function () {
      atom.config.set('editor.scrollSensitivity', 100)
    })

    describe('updating scrollTop and scrollLeft', function () {
      beforeEach(async function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()
      })

      it('updates the scrollLeft or scrollTop on mousewheel events depending on which delta is greater (x or y)', async function () {
        expect(verticalScrollbarNode.scrollTop).toBe(0)
        expect(horizontalScrollbarNode.scrollLeft).toBe(0)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -5,
          wheelDeltaY: -10
        }))
        await nextAnimationFramePromise()

        expect(verticalScrollbarNode.scrollTop).toBe(10)
        expect(horizontalScrollbarNode.scrollLeft).toBe(0)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -15,
          wheelDeltaY: -5
        }))
        await nextAnimationFramePromise()

        expect(verticalScrollbarNode.scrollTop).toBe(10)
        expect(horizontalScrollbarNode.scrollLeft).toBe(15)
      })

      it('updates the scrollLeft or scrollTop according to the scroll sensitivity', async function () {
        atom.config.set('editor.scrollSensitivity', 50)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -5,
          wheelDeltaY: -10
        }))
        await nextAnimationFramePromise()

        expect(horizontalScrollbarNode.scrollLeft).toBe(0)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: -15,
          wheelDeltaY: -5
        }))
        await nextAnimationFramePromise()

        expect(verticalScrollbarNode.scrollTop).toBe(5)
        expect(horizontalScrollbarNode.scrollLeft).toBe(7)
      })

      it('uses the previous scrollSensitivity when the value is not an int', async function () {
        atom.config.set('editor.scrollSensitivity', 'nope')
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -10
        }))
        await nextAnimationFramePromise()
        expect(verticalScrollbarNode.scrollTop).toBe(10)
      })

      it('parses negative scrollSensitivity values at the minimum', async function () {
        atom.config.set('editor.scrollSensitivity', -50)
        componentNode.dispatchEvent(new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -10
        }))
        await nextAnimationFramePromise()
        expect(verticalScrollbarNode.scrollTop).toBe(1)
      })
    })

    describe('when the mousewheel event\'s target is a line', function () {
      it('keeps the line on the DOM if it is scrolled off-screen', async function () {
        component.presenter.stoppedScrollingDelay = 3000 // account for slower build machines
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        let lineNode = componentNode.querySelector('.line')
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        await nextViewUpdatePromise()

        expect(componentNode.contains(lineNode)).toBe(true)
      })

      it('does not set the mouseWheelScreenRow if scrolling horizontally', async function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        let lineNode = componentNode.querySelector('.line')
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 10,
          wheelDeltaY: 0
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        await nextAnimationFramePromise()

        expect(component.presenter.mouseWheelScreenRow).toBe(null)
      })

      it('clears the mouseWheelScreenRow after a delay even if the event does not cause scrolling', async function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        let lineNode = componentNode.querySelector('.line')
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: 10
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(component.presenter.mouseWheelScreenRow).toBe(0)

        await conditionPromise(function () {
          return component.presenter.mouseWheelScreenRow == null
        })
      })

      it('does not preserve the line if it is on screen', function () {
        let lineNode, lineNodes, wheelEvent
        expect(componentNode.querySelectorAll('.line-number').length).toBe(14)
        lineNodes = componentNode.querySelectorAll('.line')
        expect(lineNodes.length).toBe(13)
        lineNode = lineNodes[0]
        wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: 100
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        expect(component.presenter.mouseWheelScreenRow).toBe(0)
        editor.insertText('hello')
        expect(componentNode.querySelectorAll('.line-number').length).toBe(14)
        expect(componentNode.querySelectorAll('.line').length).toBe(13)
      })
    })

    describe('when the mousewheel event\'s target is a line number', function () {
      it('keeps the line number on the DOM if it is scrolled off-screen', async function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        let lineNumberNode = componentNode.querySelectorAll('.line-number')[1]
        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return lineNumberNode
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        await nextAnimationFramePromise()

        expect(componentNode.contains(lineNumberNode)).toBe(true)
      })
    })

    describe('when the mousewheel event\'s target is a block decoration', function () {
      it('keeps it on the DOM if it is scrolled off-screen', async function () {
        wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
        wrapperNode.style.width = 20 * charWidth + 'px'
        component.measureDimensions()
        await nextViewUpdatePromise()

        let item = document.createElement("div")
        item.style.width = "30px"
        item.style.height = "30px"
        item.className = "decoration-1"
        editor.decorateMarker(
          editor.markScreenPosition([0, 0], {invalidate: "never"}),
          {type: "block", item: item}
        )

        await nextViewUpdatePromise()

        let wheelEvent = new WheelEvent('mousewheel', {
          wheelDeltaX: 0,
          wheelDeltaY: -500
        })
        Object.defineProperty(wheelEvent, 'target', {
          get: function () {
            return item
          }
        })
        componentNode.dispatchEvent(wheelEvent)
        await nextAnimationFramePromise()

        expect(component.getTopmostDOMNode().contains(item)).toBe(true)
      })
    })

    it('only prevents the default action of the mousewheel event if it actually lead to scrolling', async function () {
      spyOn(WheelEvent.prototype, 'preventDefault').andCallThrough()
      wrapperNode.style.height = 4.5 * lineHeightInPixels + 'px'
      wrapperNode.style.width = 20 * charWidth + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 0,
        wheelDeltaY: 50
      }))
      expect(wrapperNode.getScrollTop()).toBe(0)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 0,
        wheelDeltaY: -3000
      }))
      await nextAnimationFramePromise()

      let maxScrollTop = wrapperNode.getScrollTop()
      expect(WheelEvent.prototype.preventDefault).toHaveBeenCalled()
      WheelEvent.prototype.preventDefault.reset()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 0,
        wheelDeltaY: -30
      }))
      expect(wrapperNode.getScrollTop()).toBe(maxScrollTop)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: 50,
        wheelDeltaY: 0
      }))
      expect(wrapperNode.getScrollLeft()).toBe(0)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: -3000,
        wheelDeltaY: 0
      }))
      await nextAnimationFramePromise()

      let maxScrollLeft = wrapperNode.getScrollLeft()
      expect(WheelEvent.prototype.preventDefault).toHaveBeenCalled()
      WheelEvent.prototype.preventDefault.reset()
      componentNode.dispatchEvent(new WheelEvent('mousewheel', {
        wheelDeltaX: -30,
        wheelDeltaY: 0
      }))
      expect(wrapperNode.getScrollLeft()).toBe(maxScrollLeft)
      expect(WheelEvent.prototype.preventDefault).not.toHaveBeenCalled()
    })
  })

  describe('input events', function () {
    function buildTextInputEvent ({data, target}) {
      let event = new Event('textInput')
      event.data = data
      Object.defineProperty(event, 'target', {
        get: function () {
          return target
        }
      })
      return event
    }

    function buildKeydownEvent ({keyCode, target}) {
      let event = new KeyboardEvent('keydown')
      Object.defineProperty(event, 'keyCode', {
        get: function () {
          return keyCode
        }
      })
      Object.defineProperty(event, 'target', {
        get: function () {
          return target
        }
      })
      return event
    }

    let inputNode

    beforeEach(function () {
      inputNode = componentNode.querySelector('.hidden-input')
    })

    it('inserts the newest character in the input\'s value into the buffer', async function () {
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'x',
        target: inputNode
      }))
      await nextViewUpdatePromise()

      expect(editor.lineTextForBufferRow(0)).toBe('xvar quicksort = function () {')
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'y',
        target: inputNode
      }))

      expect(editor.lineTextForBufferRow(0)).toBe('xyvar quicksort = function () {')
    })

    it('replaces the last character if a keypress event is bracketed by keydown events with matching keyCodes, which occurs when the accented character menu is shown', async function () {
      componentNode.dispatchEvent(buildKeydownEvent({keyCode: 85, target: inputNode}))
      componentNode.dispatchEvent(buildTextInputEvent({data: 'u', target: inputNode}))
      componentNode.dispatchEvent(new KeyboardEvent('keypress'))
      componentNode.dispatchEvent(buildKeydownEvent({keyCode: 85, target: inputNode}))
      componentNode.dispatchEvent(new KeyboardEvent('keyup'))
      await nextViewUpdatePromise()

      expect(editor.lineTextForBufferRow(0)).toBe('uvar quicksort = function () {')
      inputNode.setSelectionRange(0, 1)
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'ü',
        target: inputNode
      }))
      await nextViewUpdatePromise()

      expect(editor.lineTextForBufferRow(0)).toBe('üvar quicksort = function () {')
    })

    it('does not handle input events when input is disabled', async function () {
      component.setInputEnabled(false)
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'x',
        target: inputNode
      }))
      expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
      await nextAnimationFramePromise()
      expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
    })

    it('groups events that occur close together in time into single undo entries', function () {
      let currentTime = 0
      spyOn(Date, 'now').andCallFake(function () {
        return currentTime
      })
      atom.config.set('editor.undoGroupingInterval', 100)
      editor.setText('')
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'x',
        target: inputNode
      }))
      currentTime += 99
      componentNode.dispatchEvent(buildTextInputEvent({
        data: 'y',
        target: inputNode
      }))
      currentTime += 99
      componentNode.dispatchEvent(new CustomEvent('editor:duplicate-lines', {
        bubbles: true,
        cancelable: true
      }))
      currentTime += 101
      componentNode.dispatchEvent(new CustomEvent('editor:duplicate-lines', {
        bubbles: true,
        cancelable: true
      }))
      expect(editor.getText()).toBe('xy\nxy\nxy')
      componentNode.dispatchEvent(new CustomEvent('core:undo', {
        bubbles: true,
        cancelable: true
      }))
      expect(editor.getText()).toBe('xy\nxy')
      componentNode.dispatchEvent(new CustomEvent('core:undo', {
        bubbles: true,
        cancelable: true
      }))
      expect(editor.getText()).toBe('')
    })

    describe('when IME composition is used to insert international characters', function () {
      function buildIMECompositionEvent (event, {data, target} = {}) {
        event = new Event(event)
        event.data = data
        Object.defineProperty(event, 'target', {
          get: function () {
            return target
          }
        })
        return event
      }

      let inputNode

      beforeEach(function () {
        inputNode = componentNode.querySelector('.hidden-input')
      })

      describe('when nothing is selected', function () {
        it('inserts the chosen completion', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('svar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('sdvar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: '速度',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('速度var quicksort = function () {')
        })

        it('reverts back to the original text when the completion helper is dismissed', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('svar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('sdvar quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
        })

        it('allows multiple accented character to be inserted with the \' on a US international layout', function () {
          inputNode.value = '\''
          inputNode.setSelectionRange(0, 1)
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: '\'',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('\'var quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: 'á',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('ávar quicksort = function () {')
          inputNode.value = '\''
          inputNode.setSelectionRange(0, 1)
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: '\'',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('á\'var quicksort = function () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: 'á',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('áávar quicksort = function () {')
        })
      })

      describe('when a string is selected', function () {
        beforeEach(function () {
          editor.setSelectedBufferRanges([[[0, 4], [0, 9]], [[0, 16], [0, 19]]])
        })

        it('inserts the chosen completion', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var ssort = sction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var sdsort = sdction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildTextInputEvent({
            data: '速度',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var 速度sort = 速度ction () {')
        })

        it('reverts back to the original text when the completion helper is dismissed', function () {
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionstart', {
            target: inputNode
          }))
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 's',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var ssort = sction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionupdate', {
            data: 'sd',
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var sdsort = sdction () {')
          componentNode.dispatchEvent(buildIMECompositionEvent('compositionend', {
            target: inputNode
          }))
          expect(editor.lineTextForBufferRow(0)).toBe('var quicksort = function () {')
        })
      })
    })
  })

  describe('commands', function () {
    describe('editor:consolidate-selections', function () {
      it('consolidates selections on the editor model, aborting the key binding if there is only one selection', function () {
        spyOn(editor, 'consolidateSelections').andCallThrough()
        let event = new CustomEvent('editor:consolidate-selections', {
          bubbles: true,
          cancelable: true
        })
        event.abortKeyBinding = jasmine.createSpy('event.abortKeyBinding')
        componentNode.dispatchEvent(event)
        expect(editor.consolidateSelections).toHaveBeenCalled()
        expect(event.abortKeyBinding).toHaveBeenCalled()
      })
    })
  })

  describe('when decreasing the fontSize', async function () {
    it('decreases the widths of the korean char, the double width char and the half width char', async function () {
      originalDefaultCharWidth = editor.getDefaultCharWidth()
      koreanDefaultCharWidth = editor.getKoreanCharWidth()
      doubleWidthDefaultCharWidth = editor.getDoubleWidthCharWidth()
      halfWidthDefaultCharWidth = editor.getHalfWidthCharWidth()
      component.setFontSize(10)
      await nextViewUpdatePromise()
      expect(editor.getDefaultCharWidth()).toBeLessThan(originalDefaultCharWidth)
      expect(editor.getKoreanCharWidth()).toBeLessThan(koreanDefaultCharWidth)
      expect(editor.getDoubleWidthCharWidth()).toBeLessThan(doubleWidthDefaultCharWidth)
      expect(editor.getHalfWidthCharWidth()).toBeLessThan(halfWidthDefaultCharWidth)
    })
  })

  describe('when increasing the fontSize', function() {
    it('increases the widths of the korean char, the double width char and the half width char', async function () {
      originalDefaultCharWidth = editor.getDefaultCharWidth()
      koreanDefaultCharWidth = editor.getKoreanCharWidth()
      doubleWidthDefaultCharWidth = editor.getDoubleWidthCharWidth()
      halfWidthDefaultCharWidth = editor.getHalfWidthCharWidth()
      component.setFontSize(25)
      await nextViewUpdatePromise()
      expect(editor.getDefaultCharWidth()).toBeGreaterThan(originalDefaultCharWidth)
      expect(editor.getKoreanCharWidth()).toBeGreaterThan(koreanDefaultCharWidth)
      expect(editor.getDoubleWidthCharWidth()).toBeGreaterThan(doubleWidthDefaultCharWidth)
      expect(editor.getHalfWidthCharWidth()).toBeGreaterThan(halfWidthDefaultCharWidth)
    })
  })

  describe('hiding and showing the editor', function () {
    describe('when the editor is hidden when it is mounted', function () {
      it('defers measurement and rendering until the editor becomes visible', function () {
        wrapperNode.remove()
        let hiddenParent = document.createElement('div')
        hiddenParent.style.display = 'none'
        contentNode.appendChild(hiddenParent)
        wrapperNode = new TextEditorElement()
        wrapperNode.tileSize = TILE_SIZE
        wrapperNode.initialize(editor, atom)
        hiddenParent.appendChild(wrapperNode)
        component = wrapperNode.component
        componentNode = component.getDomNode()
        expect(componentNode.querySelectorAll('.line').length).toBe(0)
        hiddenParent.style.display = 'block'
        atom.views.performDocumentPoll()
        expect(componentNode.querySelectorAll('.line').length).toBeGreaterThan(0)
      })
    })

    describe('when the lineHeight changes while the editor is hidden', function () {
      it('does not attempt to measure the lineHeightInPixels until the editor becomes visible again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        let initialLineHeightInPixels = editor.getLineHeightInPixels()
        component.setLineHeight(2)
        expect(editor.getLineHeightInPixels()).toBe(initialLineHeightInPixels)
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        expect(editor.getLineHeightInPixels()).not.toBe(initialLineHeightInPixels)
      })
    })

    describe('when the fontSize changes while the editor is hidden', function () {
      it('does not attempt to measure the lineHeightInPixels or defaultCharWidth until the editor becomes visible again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        let initialLineHeightInPixels = editor.getLineHeightInPixels()
        let initialCharWidth = editor.getDefaultCharWidth()
        component.setFontSize(22)
        expect(editor.getLineHeightInPixels()).toBe(initialLineHeightInPixels)
        expect(editor.getDefaultCharWidth()).toBe(initialCharWidth)
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        expect(editor.getLineHeightInPixels()).not.toBe(initialLineHeightInPixels)
        expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth)
      })

      it('does not re-measure character widths until the editor is shown again', async function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        component.setFontSize(22)
        editor.getBuffer().insert([0, 0], 'a')
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        editor.setCursorBufferPosition([0, Infinity])
        await nextViewUpdatePromise()
        let cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        let line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBeCloseTo(line0Right, 0)
      })
    })

    describe('when the fontFamily changes while the editor is hidden', function () {
      it('does not attempt to measure the defaultCharWidth until the editor becomes visible again', function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        let initialLineHeightInPixels = editor.getLineHeightInPixels()
        let initialCharWidth = editor.getDefaultCharWidth()
        component.setFontFamily('serif')
        expect(editor.getDefaultCharWidth()).toBe(initialCharWidth)
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        expect(editor.getDefaultCharWidth()).not.toBe(initialCharWidth)
      })

      it('does not re-measure character widths until the editor is shown again', async function () {
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        component.setFontFamily('serif')
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        editor.setCursorBufferPosition([0, Infinity])
        await nextViewUpdatePromise()
        let cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        let line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBeCloseTo(line0Right, 0)
      })
    })

    describe('when stylesheets change while the editor is hidden', function () {
      afterEach(function () {
        atom.themes.removeStylesheet('test')
      })

      it('does not re-measure character widths until the editor is shown again', async function () {
        atom.config.set('editor.fontFamily', 'sans-serif')
        wrapperNode.style.display = 'none'
        component.checkForVisibilityChange()
        atom.themes.applyStylesheet('test', '.function.js {\n  font-weight: bold;\n}')
        wrapperNode.style.display = ''
        component.checkForVisibilityChange()
        editor.setCursorBufferPosition([0, Infinity])
        await nextViewUpdatePromise()
        let cursorLeft = componentNode.querySelector('.cursor').getBoundingClientRect().left
        let line0Right = componentNode.querySelector('.line > span:last-child').getBoundingClientRect().right
        expect(cursorLeft).toBeCloseTo(line0Right, 0)
      })
    })
  })

  describe('soft wrapping', function () {
    beforeEach(async function () {
      editor.setSoftWrapped(true)
      await nextViewUpdatePromise()
    })

    it('updates the wrap location when the editor is resized', async function () {
      let newHeight = 4 * editor.getLineHeightInPixels() + 'px'
      expect(parseInt(newHeight)).toBeLessThan(wrapperNode.offsetHeight)
      wrapperNode.style.height = newHeight
      await nextViewUpdatePromise()

      expect(componentNode.querySelectorAll('.line')).toHaveLength(7)
      let gutterWidth = componentNode.querySelector('.gutter').offsetWidth
      componentNode.style.width = gutterWidth + 14 * charWidth + wrapperNode.getVerticalScrollbarWidth() + 'px'
      atom.views.performDocumentPoll()
      await nextViewUpdatePromise()
      expect(componentNode.querySelector('.line').textContent).toBe('var quicksort ')
    })

    it('accounts for the scroll view\'s padding when determining the wrap location', async function () {
      let scrollViewNode = componentNode.querySelector('.scroll-view')
      scrollViewNode.style.paddingLeft = 20 + 'px'
      componentNode.style.width = 30 * charWidth + 'px'
      atom.views.performDocumentPoll()
      await nextViewUpdatePromise()
      expect(component.lineNodeForScreenRow(0).textContent).toBe('var quicksort = ')
    })
  })

  describe('default decorations', function () {
    it('applies .cursor-line decorations for line numbers overlapping selections', async function () {
      editor.setCursorScreenPosition([4, 4])
      await nextViewUpdatePromise()

      expect(lineNumberHasClass(3, 'cursor-line')).toBe(false)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(5, 'cursor-line')).toBe(false)
      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      await nextViewUpdatePromise()

      expect(lineNumberHasClass(3, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(true)
      editor.setSelectedScreenRange([[3, 4], [4, 0]])
      await nextViewUpdatePromise()

      expect(lineNumberHasClass(3, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(false)
    })

    it('does not apply .cursor-line to the last line of a selection if it\'s empty', async function () {
      editor.setSelectedScreenRange([[3, 4], [5, 0]])
      await nextViewUpdatePromise()
      expect(lineNumberHasClass(3, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(4, 'cursor-line')).toBe(true)
      expect(lineNumberHasClass(5, 'cursor-line')).toBe(false)
    })

    it('applies .cursor-line decorations for lines containing the cursor in non-empty selections', async function () {
      editor.setCursorScreenPosition([4, 4])
      await nextViewUpdatePromise()

      expect(lineHasClass(3, 'cursor-line')).toBe(false)
      expect(lineHasClass(4, 'cursor-line')).toBe(true)
      expect(lineHasClass(5, 'cursor-line')).toBe(false)
      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      await nextViewUpdatePromise()

      expect(lineHasClass(2, 'cursor-line')).toBe(false)
      expect(lineHasClass(3, 'cursor-line')).toBe(false)
      expect(lineHasClass(4, 'cursor-line')).toBe(false)
      expect(lineHasClass(5, 'cursor-line')).toBe(false)
    })

    it('applies .cursor-line-no-selection to line numbers for rows containing the cursor when the selection is empty', async function () {
      editor.setCursorScreenPosition([4, 4])
      await nextViewUpdatePromise()

      expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe(true)
      editor.setSelectedScreenRange([[3, 4], [4, 4]])
      await nextViewUpdatePromise()

      expect(lineNumberHasClass(4, 'cursor-line-no-selection')).toBe(false)
    })
  })

  describe('height', function () {
    describe('when the wrapper view has an explicit height', function () {
      it('does not assign a height on the component node', async function () {
        wrapperNode.style.height = '200px'
        component.measureDimensions()
        await nextViewUpdatePromise()
        expect(componentNode.style.height).toBe('')
      })
    })

    describe('when the wrapper view does not have an explicit height', function () {
      it('assigns a height on the component node based on the editor\'s content', function () {
        expect(wrapperNode.style.height).toBe('')
        expect(componentNode.style.height).toBe(editor.getScreenLineCount() * lineHeightInPixels + 'px')
      })
    })
  })

  describe('width', function () {
    it('sizes the editor element according to the content width when auto width is true, or according to the container width otherwise', async function () {
      await nextViewUpdatePromise()

      contentNode.style.width = '600px'
      component.measureDimensions()
      editor.setText("abcdefghi")
      await nextViewUpdatePromise()
      expect(wrapperNode.offsetWidth).toBe(contentNode.offsetWidth)

      editor.update({autoWidth: true})
      await nextViewUpdatePromise()
      const editorWidth1 = wrapperNode.offsetWidth
      expect(editorWidth1).toBeGreaterThan(0)
      expect(editorWidth1).toBeLessThan(contentNode.offsetWidth)

      editor.setText("abcdefghijkl")
      editor.update({autoWidth: true})
      await nextViewUpdatePromise()
      const editorWidth2 = wrapperNode.offsetWidth
      expect(editorWidth2).toBeGreaterThan(editorWidth1)
      expect(editorWidth2).toBeLessThan(contentNode.offsetWidth)

      editor.update({autoWidth: false})
      await nextViewUpdatePromise()
      expect(wrapperNode.offsetWidth).toBe(contentNode.offsetWidth)
    })
  })

  describe('when the "mini" property is true', function () {
    beforeEach(async function () {
      editor.setMini(true)
      await nextViewUpdatePromise()
    })

    it('does not render the gutter', function () {
      expect(componentNode.querySelector('.gutter')).toBeNull()
    })

    it('adds the "mini" class to the wrapper view', function () {
      expect(wrapperNode.classList.contains('mini')).toBe(true)
    })

    it('does not have an opaque background on lines', function () {
      expect(component.linesComponent.getDomNode().getAttribute('style')).not.toContain('background-color')
    })

    it('does not render invisible characters', function () {
      atom.config.set('editor.invisibles', {
        eol: 'E'
      })
      atom.config.set('editor.showInvisibles', true)
      expect(component.lineNodeForScreenRow(0).textContent).toBe('var quicksort = function () {')
    })

    it('does not assign an explicit line-height on the editor contents', function () {
      expect(componentNode.style.lineHeight).toBe('')
    })

    it('does not apply cursor-line decorations', function () {
      expect(component.lineNodeForScreenRow(0).classList.contains('cursor-line')).toBe(false)
    })
  })

  describe('when placholderText is specified', function () {
    it('renders the placeholder text when the buffer is empty', async function () {
      editor.setPlaceholderText('Hello World')
      expect(componentNode.querySelector('.placeholder-text')).toBeNull()
      editor.setText('')
      await nextViewUpdatePromise()

      expect(componentNode.querySelector('.placeholder-text').textContent).toBe('Hello World')
      editor.setText('hey')
      await nextViewUpdatePromise()

      expect(componentNode.querySelector('.placeholder-text')).toBeNull()
    })
  })

  describe('grammar data attributes', function () {
    it('adds and updates the grammar data attribute based on the current grammar', function () {
      expect(wrapperNode.dataset.grammar).toBe('source js')
      editor.setGrammar(atom.grammars.nullGrammar)
      expect(wrapperNode.dataset.grammar).toBe('text plain null-grammar')
    })
  })

  describe('encoding data attributes', function () {
    it('adds and updates the encoding data attribute based on the current encoding', function () {
      expect(wrapperNode.dataset.encoding).toBe('utf8')
      editor.setEncoding('utf16le')
      expect(wrapperNode.dataset.encoding).toBe('utf16le')
    })
  })

  describe('detaching and reattaching the editor (regression)', function () {
    it('does not throw an exception', function () {
      wrapperNode.remove()
      jasmine.attachToDOM(wrapperNode)
      atom.commands.dispatch(wrapperNode, 'core:move-right')
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])
    })
  })

  describe('scoped config settings', function () {
    let coffeeComponent, coffeeEditor

    beforeEach(async function () {
      await atom.packages.activatePackage('language-coffee-script')
      coffeeEditor = await atom.workspace.open('coffee.coffee', {autoIndent: false})
    })

    afterEach(function () {
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()
    })

    describe('soft wrap settings', function () {
      beforeEach(function () {
        atom.config.set('editor.softWrap', true, {
          scopeSelector: '.source.coffee'
        })
        atom.config.set('editor.preferredLineLength', 17, {
          scopeSelector: '.source.coffee'
        })
        atom.config.set('editor.softWrapAtPreferredLineLength', true, {
          scopeSelector: '.source.coffee'
        })
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(20)
        coffeeEditor.setDefaultCharWidth(1)
        coffeeEditor.setEditorWidthInChars(20)
      })

      it('wraps lines when editor.softWrap is true for a matching scope', function () {
        expect(editor.lineTextForScreenRow(2)).toEqual('    if (items.length <= 1) return items;')
        expect(coffeeEditor.lineTextForScreenRow(3)).toEqual('    return items ')
      })

      it('updates the wrapped lines when editor.preferredLineLength changes', function () {
        atom.config.set('editor.preferredLineLength', 20, {
          scopeSelector: '.source.coffee'
        })
        expect(coffeeEditor.lineTextForScreenRow(2)).toEqual('    return items if ')
      })

      it('updates the wrapped lines when editor.softWrapAtPreferredLineLength changes', function () {
        atom.config.set('editor.softWrapAtPreferredLineLength', false, {
          scopeSelector: '.source.coffee'
        })
        expect(coffeeEditor.lineTextForScreenRow(2)).toEqual('    return items if ')
      })

      it('updates the wrapped lines when editor.softWrap changes', function () {
        atom.config.set('editor.softWrap', false, {
          scopeSelector: '.source.coffee'
        })
        expect(coffeeEditor.lineTextForScreenRow(2)).toEqual('    return items if items.length <= 1')
        atom.config.set('editor.softWrap', true, {
          scopeSelector: '.source.coffee'
        })
        expect(coffeeEditor.lineTextForScreenRow(3)).toEqual('    return items ')
      })

      it('updates the wrapped lines when the grammar changes', function () {
        editor.setGrammar(coffeeEditor.getGrammar())
        expect(editor.isSoftWrapped()).toBe(true)
        expect(editor.lineTextForScreenRow(0)).toEqual('var quicksort = ')
      })

      describe('::isSoftWrapped()', function () {
        it('returns the correct value based on the scoped settings', function () {
          expect(editor.isSoftWrapped()).toBe(false)
          expect(coffeeEditor.isSoftWrapped()).toBe(true)
        })
      })
    })

    describe('invisibles settings', function () {
      const jsInvisibles = {
        eol: 'J',
        space: 'A',
        tab: 'V',
        cr: 'A'
      }
      const coffeeInvisibles = {
        eol: 'C',
        space: 'O',
        tab: 'F',
        cr: 'E'
      }

      beforeEach(async function () {
        atom.config.set('editor.showInvisibles', true, {
          scopeSelector: '.source.js'
        })
        atom.config.set('editor.invisibles', jsInvisibles, {
          scopeSelector: '.source.js'
        })
        atom.config.set('editor.showInvisibles', false, {
          scopeSelector: '.source.coffee'
        })
        atom.config.set('editor.invisibles', coffeeInvisibles, {
          scopeSelector: '.source.coffee'
        })
        editor.setText(' a line with tabs\tand spaces \n')
        await nextViewUpdatePromise()
      })

      it('renders the invisibles when editor.showInvisibles is true for a given grammar', function () {
        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + jsInvisibles.space + 'a line with tabs' + jsInvisibles.tab + 'and spaces' + jsInvisibles.space + jsInvisibles.eol)
      })

      it('does not render the invisibles when editor.showInvisibles is false for a given grammar', async function () {
        editor.setGrammar(coffeeEditor.getGrammar())
        await nextViewUpdatePromise()
        expect(component.lineNodeForScreenRow(0).textContent).toBe(' a line with tabs and spaces ')
      })

      it('re-renders the invisibles when the invisible settings change', async function () {
        let jsGrammar = editor.getGrammar()
        editor.setGrammar(coffeeEditor.getGrammar())
        atom.config.set('editor.showInvisibles', true, {
          scopeSelector: '.source.coffee'
        })
        await nextViewUpdatePromise()

        let newInvisibles = {
          eol: 'N',
          space: 'E',
          tab: 'W',
          cr: 'I'
        }

        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + coffeeInvisibles.space + 'a line with tabs' + coffeeInvisibles.tab + 'and spaces' + coffeeInvisibles.space + coffeeInvisibles.eol)
        atom.config.set('editor.invisibles', newInvisibles, {
          scopeSelector: '.source.coffee'
        })
        await nextViewUpdatePromise()

        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + newInvisibles.space + 'a line with tabs' + newInvisibles.tab + 'and spaces' + newInvisibles.space + newInvisibles.eol)
        editor.setGrammar(jsGrammar)
        await nextViewUpdatePromise()

        expect(component.lineNodeForScreenRow(0).textContent).toBe('' + jsInvisibles.space + 'a line with tabs' + jsInvisibles.tab + 'and spaces' + jsInvisibles.space + jsInvisibles.eol)
      })
    })

    describe('editor.showIndentGuide', function () {
      beforeEach(async function () {
        atom.config.set('editor.showIndentGuide', true, {
          scopeSelector: '.source.js'
        })
        atom.config.set('editor.showIndentGuide', false, {
          scopeSelector: '.source.coffee'
        })
        await nextViewUpdatePromise()
      })

      it('has an "indent-guide" class when scoped editor.showIndentGuide is true, but not when scoped editor.showIndentGuide is false', async function () {
        let line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe('  ')
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe(false)
        editor.setGrammar(coffeeEditor.getGrammar())
        await nextViewUpdatePromise()

        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe('  ')
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe(false)
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe(false)
      })

      it('removes the "indent-guide" class when editor.showIndentGuide to false', async function () {
        let line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))

        expect(line1LeafNodes[0].textContent).toBe('  ')
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe(true)
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe(false)
        atom.config.set('editor.showIndentGuide', false, {
          scopeSelector: '.source.js'
        })
        await nextViewUpdatePromise()

        line1LeafNodes = getLeafNodes(component.lineNodeForScreenRow(1))
        expect(line1LeafNodes[0].textContent).toBe('  ')
        expect(line1LeafNodes[0].classList.contains('indent-guide')).toBe(false)
        expect(line1LeafNodes[1].classList.contains('indent-guide')).toBe(false)
      })
    })
  })

  describe('autoscroll', function () {
    beforeEach(async function () {
      editor.setVerticalScrollMargin(2)
      editor.setHorizontalScrollMargin(2)
      component.setLineHeight('10px')
      component.setFontSize(17)
      component.measureDimensions()
      await nextViewUpdatePromise()

      wrapperNode.setWidth(55)
      wrapperNode.setHeight(55)
      component.measureDimensions()
      await nextViewUpdatePromise()

      component.presenter.setHorizontalScrollbarHeight(0)
      component.presenter.setVerticalScrollbarWidth(0)
      await nextViewUpdatePromise()
    })

    describe('when selecting buffer ranges', function () {
      it('autoscrolls the selection if it is last unless the "autoscroll" option is false', async function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setSelectedBufferRange([[5, 6], [6, 8]])
        await nextViewUpdatePromise()

        let right = wrapperNode.pixelPositionForBufferPosition([6, 8 + editor.getHorizontalScrollMargin()]).left
        expect(wrapperNode.getScrollBottom()).toBe((7 + editor.getVerticalScrollMargin()) * 10)
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
        editor.setSelectedBufferRange([[0, 0], [0, 0]])
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBe(0)
        editor.setSelectedBufferRange([[6, 6], [6, 8]])
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe((7 + editor.getVerticalScrollMargin()) * 10)
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
      })
    })

    describe('when adding selections for buffer ranges', function () {
      it('autoscrolls to the added selection if needed', async function () {
        editor.addSelectionForBufferRange([[8, 10], [8, 15]])
        await nextViewUpdatePromise()

        let right = wrapperNode.pixelPositionForBufferPosition([8, 15]).left
        expect(wrapperNode.getScrollBottom()).toBe((9 * 10) + (2 * 10))
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right + 2 * 10, 0)
      })
    })

    describe('when selecting lines containing cursors', function () {
      it('autoscrolls to the selection', async function () {
        editor.setCursorScreenPosition([5, 6])
        await nextViewUpdatePromise()

        wrapperNode.scrollToTop()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.selectLinesContainingCursors()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe((7 + editor.getVerticalScrollMargin()) * 10)
      })
    })

    describe('when inserting text', function () {
      describe('when there are multiple empty selections on different lines', function () {
        it('autoscrolls to the last cursor', async function () {
          editor.setCursorScreenPosition([1, 2], {
            autoscroll: false
          })
          await nextViewUpdatePromise()

          editor.addCursorAtScreenPosition([10, 4], {
            autoscroll: false
          })
          await nextViewUpdatePromise()

          expect(wrapperNode.getScrollTop()).toBe(0)
          editor.insertText('a')
          await nextViewUpdatePromise()

          expect(wrapperNode.getScrollTop()).toBe(75)
        })
      })
    })

    describe('when scrolled to cursor position', function () {
      it('scrolls the last cursor into view, centering around the cursor if possible and the "center" option is not false', async function () {
        editor.setCursorScreenPosition([8, 8], {
          autoscroll: false
        })
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollLeft()).toBe(0)
        editor.scrollToCursorPosition()
        await nextViewUpdatePromise()

        let right = wrapperNode.pixelPositionForScreenPosition([8, 9 + editor.getHorizontalScrollMargin()]).left
        expect(wrapperNode.getScrollTop()).toBe((8.8 * 10) - 30)
        expect(wrapperNode.getScrollBottom()).toBe((8.3 * 10) + 30)
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
        wrapperNode.setScrollTop(0)
        editor.scrollToCursorPosition({
          center: false
        })
        expect(wrapperNode.getScrollTop()).toBe((7.8 - editor.getVerticalScrollMargin()) * 10)
        expect(wrapperNode.getScrollBottom()).toBe((9.3 + editor.getVerticalScrollMargin()) * 10)
      })
    })

    describe('moving cursors', function () {
      it('scrolls down when the last cursor gets closer than ::verticalScrollMargin to the bottom of the editor', async function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        expect(wrapperNode.getScrollBottom()).toBe(5.5 * 10)
        editor.setCursorScreenPosition([2, 0])
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe(5.5 * 10)
        editor.moveDown()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe(6 * 10)
        editor.moveDown()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe(7 * 10)
      })

      it('scrolls up when the last cursor gets closer than ::verticalScrollMargin to the top of the editor', async function () {
        editor.setCursorScreenPosition([11, 0])
        await nextViewUpdatePromise()

        wrapperNode.setScrollBottom(wrapperNode.getScrollHeight())
        await nextViewUpdatePromise()

        editor.moveUp()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe(wrapperNode.getScrollHeight())
        editor.moveUp()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(7 * 10)
        editor.moveUp()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(6 * 10)
      })

      it('scrolls right when the last cursor gets closer than ::horizontalScrollMargin to the right of the editor', async function () {
        expect(wrapperNode.getScrollLeft()).toBe(0)
        expect(wrapperNode.getScrollRight()).toBe(5.5 * 10)
        editor.setCursorScreenPosition([0, 2])
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollRight()).toBe(5.5 * 10)
        editor.moveRight()
        await nextViewUpdatePromise()

        let margin = component.presenter.getHorizontalScrollMarginInPixels()
        let right = wrapperNode.pixelPositionForScreenPosition([0, 4]).left + margin
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
        editor.moveRight()
        await nextViewUpdatePromise()

        right = wrapperNode.pixelPositionForScreenPosition([0, 5]).left + margin
        expect(wrapperNode.getScrollRight()).toBeCloseTo(right, 0)
      })

      it('scrolls left when the last cursor gets closer than ::horizontalScrollMargin to the left of the editor', async function () {
        wrapperNode.setScrollRight(wrapperNode.getScrollWidth())
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollRight()).toBe(wrapperNode.getScrollWidth())
        editor.setCursorScreenPosition([6, 62], {
          autoscroll: false
        })
        await nextViewUpdatePromise()

        editor.moveLeft()
        await nextViewUpdatePromise()

        let margin = component.presenter.getHorizontalScrollMarginInPixels()
        let left = wrapperNode.pixelPositionForScreenPosition([6, 61]).left - margin
        expect(wrapperNode.getScrollLeft()).toBeCloseTo(left, 0)
        editor.moveLeft()
        await nextViewUpdatePromise()

        left = wrapperNode.pixelPositionForScreenPosition([6, 60]).left - margin
        expect(wrapperNode.getScrollLeft()).toBeCloseTo(left, 0)
      })

      it('scrolls down when inserting lines makes the document longer than the editor\'s height', async function () {
        editor.setCursorScreenPosition([13, Infinity])
        editor.insertNewline()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe(14 * 10)
        editor.insertNewline()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollBottom()).toBe(15 * 10)
      })

      it('autoscrolls to the cursor when it moves due to undo', async function () {
        editor.insertText('abc')
        wrapperNode.setScrollTop(Infinity)
        await nextViewUpdatePromise()

        editor.undo()
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
      })

      it('does not scroll when the cursor moves into the visible area', async function () {
        editor.setCursorBufferPosition([0, 0])
        await nextViewUpdatePromise()

        wrapperNode.setScrollTop(40)
        await nextViewUpdatePromise()

        editor.setCursorBufferPosition([6, 0])
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(40)
      })

      it('honors the autoscroll option on cursor and selection manipulation methods', async function () {
        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addCursorAtScreenPosition([11, 11], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addCursorAtBufferPosition([11, 11], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setCursorScreenPosition([11, 11], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setCursorBufferPosition([11, 11], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addSelectionForBufferRange([[11, 11], [11, 11]], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addSelectionForScreenRange([[11, 11], [11, 12]], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setSelectedBufferRange([[11, 0], [11, 1]], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.setSelectedScreenRange([[11, 0], [11, 6]], {autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.clearSelections({autoscroll: false})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.addSelectionForScreenRange([[0, 0], [0, 4]])
        await nextViewUpdatePromise()

        editor.getCursors()[0].setScreenPosition([11, 11], {autoscroll: true})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        editor.getCursors()[0].setBufferPosition([0, 0], {autoscroll: true})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
        editor.getSelections()[0].setScreenRange([[11, 0], [11, 4]], {autoscroll: true})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBeGreaterThan(0)
        editor.getSelections()[0].setBufferRange([[0, 0], [0, 4]], {autoscroll: true})
        await nextViewUpdatePromise()

        expect(wrapperNode.getScrollTop()).toBe(0)
      })
    })
  })

  describe('::getVisibleRowRange()', function () {
    beforeEach(async function () {
      wrapperNode.style.height = lineHeightInPixels * 8 + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()
    })

    it('returns the first and the last visible rows', async function () {
      component.setScrollTop(0)
      await nextViewUpdatePromise()
      expect(component.getVisibleRowRange()).toEqual([0, 9])
    })

    it('ends at last buffer row even if there\'s more space available', async function () {
      wrapperNode.style.height = lineHeightInPixels * 13 + 'px'
      component.measureDimensions()
      await nextViewUpdatePromise()

      component.setScrollTop(60)
      await nextViewUpdatePromise()

      expect(component.getVisibleRowRange()).toEqual([0, 13])
    })
  })

  describe('::pixelPositionForScreenPosition()', () => {
    it('returns the correct horizontal position, even if it is on a row that has not yet been rendered (regression)', () => {
      editor.setTextInBufferRange([[5, 0], [6, 0]], 'hello world\n')
      expect(wrapperNode.pixelPositionForScreenPosition([5, Infinity]).left).toBeGreaterThan(0)
    })
  })

  describe('middle mouse paste on Linux', function () {
    let originalPlatform

    beforeEach(function () {
      originalPlatform = process.platform
      Object.defineProperty(process, 'platform', {
        value: 'linux'
      })
    })

    afterEach(function () {
      Object.defineProperty(process, 'platform', {
        value: originalPlatform
      })
    })

    it('pastes the previously selected text at the clicked location', async function () {
      let clipboardWrittenTo = false
      spyOn(require('electron').ipcRenderer, 'send').andCallFake(function (eventName, selectedText) {
        if (eventName === 'write-text-to-selection-clipboard') {
          require('../src/safe-clipboard').writeText(selectedText, 'selection')
          clipboardWrittenTo = true
        }
      })
      atom.clipboard.write('')
      component.trackSelectionClipboard()
      editor.setSelectedBufferRange([[1, 6], [1, 10]])

      await conditionPromise(function () {
        return clipboardWrittenTo
      })

      componentNode.querySelector('.scroll-view').dispatchEvent(buildMouseEvent('mousedown', clientCoordinatesForScreenPosition([10, 0]), {
        button: 1
      }))
      componentNode.querySelector('.scroll-view').dispatchEvent(buildMouseEvent('mouseup', clientCoordinatesForScreenPosition([10, 0]), {
        which: 2
      }))
      expect(atom.clipboard.read()).toBe('sort')
      expect(editor.lineTextForBufferRow(10)).toBe('sort')
    })
  })

  function buildMouseEvent (type, ...propertiesObjects) {
    let properties = extend({
      bubbles: true,
      cancelable: true
    }, ...propertiesObjects)

    if (properties.detail == null) {
      properties.detail = 1
    }

    let event = new MouseEvent(type, properties)
    if (properties.which != null) {
      Object.defineProperty(event, 'which', {
        get: function () {
          return properties.which
        }
      })
    }
    if (properties.target != null) {
      Object.defineProperty(event, 'target', {
        get: function () {
          return properties.target
        }
      })
      Object.defineProperty(event, 'srcObject', {
        get: function () {
          return properties.target
        }
      })
    }
    return event
  }

  function clientCoordinatesForScreenPosition (screenPosition) {
    let clientX, clientY, positionOffset, scrollViewClientRect
    positionOffset = wrapperNode.pixelPositionForScreenPosition(screenPosition)
    scrollViewClientRect = componentNode.querySelector('.scroll-view').getBoundingClientRect()
    clientX = scrollViewClientRect.left + positionOffset.left - wrapperNode.getScrollLeft()
    clientY = scrollViewClientRect.top + positionOffset.top - wrapperNode.getScrollTop()
    return {
      clientX: clientX,
      clientY: clientY
    }
  }

  function clientCoordinatesForScreenRowInGutter (screenRow) {
    let clientX, clientY, gutterClientRect, positionOffset
    positionOffset = wrapperNode.pixelPositionForScreenPosition([screenRow, Infinity])
    gutterClientRect = componentNode.querySelector('.gutter').getBoundingClientRect()
    clientX = gutterClientRect.left + positionOffset.left - wrapperNode.getScrollLeft()
    clientY = gutterClientRect.top + positionOffset.top - wrapperNode.getScrollTop()
    return {
      clientX: clientX,
      clientY: clientY
    }
  }

  function lineAndLineNumberHaveClass (screenRow, klass) {
    return lineHasClass(screenRow, klass) && lineNumberHasClass(screenRow, klass)
  }

  function lineNumberHasClass (screenRow, klass) {
    return component.lineNumberNodeForScreenRow(screenRow).classList.contains(klass)
  }

  function lineNumberForBufferRowHasClass (bufferRow, klass) {
    let screenRow
    screenRow = editor.screenRowForBufferRow(bufferRow)
    return component.lineNumberNodeForScreenRow(screenRow).classList.contains(klass)
  }

  function lineHasClass (screenRow, klass) {
    return component.lineNodeForScreenRow(screenRow).classList.contains(klass)
  }

  function getLeafNodes (node) {
    if (node.children.length > 0) {
      return flatten(toArray(node.children).map(getLeafNodes))
    } else {
      return [node]
    }
  }

  function conditionPromise (condition)  {
    let timeoutError = new Error("Timed out waiting on condition")
    Error.captureStackTrace(timeoutError, conditionPromise)

    return new Promise(function (resolve, reject) {
      let interval = window.setInterval(function () {
        if (condition()) {
          window.clearInterval(interval)
          window.clearTimeout(timeout)
          resolve()
        }
      }, 100)
      let timeout = window.setTimeout(function () {
        window.clearInterval(interval)
        reject(timeoutError)
      }, 5000)
    })
  }

  function timeoutPromise (timeout) {
    return new Promise(function (resolve) {
      window.setTimeout(resolve, timeout)
    })
  }

  function nextAnimationFramePromise () {
    return new Promise(function (resolve) {
      window.requestAnimationFrame(resolve)
    })
  }

  function nextViewUpdatePromise () {
    let timeoutError = new Error('Timed out waiting on a view update.')
    Error.captureStackTrace(timeoutError, nextViewUpdatePromise)

    return new Promise(function (resolve, reject) {
      let nextUpdatePromise = atom.views.getNextUpdatePromise()
      nextUpdatePromise.then(function (ts) {
        window.clearTimeout(timeout)
        resolve(ts)
      })
      let timeout = window.setTimeout(function () {
        timeoutError.message += ' Frame pending? ' + atom.views.animationFrameRequest + ' Same next update promise pending? ' + (nextUpdatePromise === atom.views.nextUpdatePromise)
        reject(timeoutError)
      }, 30000)
    })
  }

  function decorationsUpdatedPromise(editor) {
    return new Promise(function (resolve) {
      let disposable = editor.onDidUpdateDecorations(function () {
        disposable.dispose()
        resolve()
      })
    })
  }
})
=======
function queryOnScreenLineElements(element) {
  return Array.from(
    element.querySelectorAll('.line:not(.dummy):not([data-off-screen])')
  );
}
>>>>>>> master
