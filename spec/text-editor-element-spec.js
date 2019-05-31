const TextEditor = require('../src/text-editor');
const TextEditorElement = require('../src/text-editor-element');

describe('TextEditorElement', () => {
  let jasmineContent;

  beforeEach(() => {
    jasmineContent = document.body.querySelector('#jasmine-content');
    // Force scrollbars to be visible regardless of local system configuration
    const scrollbarStyle = document.createElement('style');
    scrollbarStyle.textContent =
      'atom-text-editor ::-webkit-scrollbar { -webkit-appearance: none }';
    jasmine.attachToDOM(scrollbarStyle);
  });

  function buildTextEditorElement(options = {}) {
    const element = new TextEditorElement();
    element.setUpdatedSynchronously(false);
    if (options.attach !== false) jasmine.attachToDOM(element);
    return element;
  }

  it("honors the 'mini' attribute", () => {
    jasmineContent.innerHTML = '<atom-text-editor mini>';
    const element = jasmineContent.firstChild;
    expect(element.getModel().isMini()).toBe(true);

    element.removeAttribute('mini');
    expect(element.getModel().isMini()).toBe(false);
    expect(element.getComponent().getGutterContainerWidth()).toBe(0);

    element.setAttribute('mini', '');
    expect(element.getModel().isMini()).toBe(true);
  });

  it('sets the editor to mini if the model is accessed prior to attaching the element', () => {
    const parent = document.createElement('div');
    parent.innerHTML = '<atom-text-editor mini>';
    const element = parent.firstChild;
    expect(element.getModel().isMini()).toBe(true);
  });

  it("honors the 'placeholder-text' attribute", () => {
    jasmineContent.innerHTML = "<atom-text-editor placeholder-text='testing'>";
    const element = jasmineContent.firstChild;
    expect(element.getModel().getPlaceholderText()).toBe('testing');

    element.setAttribute('placeholder-text', 'placeholder');
    expect(element.getModel().getPlaceholderText()).toBe('placeholder');

    element.removeAttribute('placeholder-text');
    expect(element.getModel().getPlaceholderText()).toBeNull();
  });

  it("only assigns 'placeholder-text' on the model if the attribute is present", () => {
    const editor = new TextEditor({ placeholderText: 'placeholder' });
    editor.getElement();
    expect(editor.getPlaceholderText()).toBe('placeholder');
  });

  it("honors the 'gutter-hidden' attribute", () => {
    jasmineContent.innerHTML = '<atom-text-editor gutter-hidden>';
    const element = jasmineContent.firstChild;
    expect(element.getModel().isLineNumberGutterVisible()).toBe(false);

    element.removeAttribute('gutter-hidden');
    expect(element.getModel().isLineNumberGutterVisible()).toBe(true);

    element.setAttribute('gutter-hidden', '');
    expect(element.getModel().isLineNumberGutterVisible()).toBe(false);
  });

  it("honors the 'readonly' attribute", async function() {
    jasmineContent.innerHTML = '<atom-text-editor readonly>';
    const element = jasmineContent.firstChild;

    expect(element.getComponent().isInputEnabled()).toBe(false);

    element.removeAttribute('readonly');
    expect(element.getComponent().isInputEnabled()).toBe(true);

    element.setAttribute('readonly', true);
    expect(element.getComponent().isInputEnabled()).toBe(false);
  });

  it('honors the text content', () => {
    jasmineContent.innerHTML = '<atom-text-editor>testing</atom-text-editor>';
    const element = jasmineContent.firstChild;
    expect(element.getModel().getText()).toBe('testing');
  });

  describe('tabIndex', () => {
    it('uses a default value of -1', () => {
      jasmineContent.innerHTML = '<atom-text-editor />';
      const element = jasmineContent.firstChild;
      expect(element.tabIndex).toBe(-1);
      expect(element.querySelector('input').tabIndex).toBe(-1);
    });

    it('uses the custom value when given', () => {
      jasmineContent.innerHTML = '<atom-text-editor tabIndex="42" />';
      const element = jasmineContent.firstChild;
      expect(element.tabIndex).toBe(-1);
      expect(element.querySelector('input').tabIndex).toBe(42);
    });
  });

  describe('when the model is assigned', () =>
    it("adds the 'mini' attribute if .isMini() returns true on the model", async () => {
      const element = buildTextEditorElement();
      element.getModel().update({ mini: true });
      await atom.views.getNextUpdatePromise();
      expect(element.hasAttribute('mini')).toBe(true);
    }));

  describe('when the editor is attached to the DOM', () =>
    it('mounts the component and unmounts when removed from the dom', () => {
      const element = buildTextEditorElement();

      const { component } = element;
      expect(component.attached).toBe(true);
      element.remove();
      expect(component.attached).toBe(false);

      jasmine.attachToDOM(element);
      expect(element.component.attached).toBe(true);
    }));

  describe('when the editor is detached from the DOM and then reattached', () => {
    it('does not render duplicate line numbers', () => {
      const editor = new TextEditor();
      editor.setText('1\n2\n3');
      const element = editor.getElement();
      jasmine.attachToDOM(element);

      const initialCount = element.querySelectorAll('.line-number').length;

      element.remove();
      jasmine.attachToDOM(element);
      expect(element.querySelectorAll('.line-number').length).toBe(
        initialCount
      );
    });

    it('does not render duplicate decorations in custom gutters', () => {
      const editor = new TextEditor();
      editor.setText('1\n2\n3');
      editor.addGutter({ name: 'test-gutter' });
      const marker = editor.markBufferRange([[0, 0], [2, 0]]);
      editor.decorateMarker(marker, {
        type: 'gutter',
        gutterName: 'test-gutter'
      });
      const element = editor.getElement();

      jasmine.attachToDOM(element);
      const initialDecorationCount = element.querySelectorAll('.decoration')
        .length;

      element.remove();
      jasmine.attachToDOM(element);
      expect(element.querySelectorAll('.decoration').length).toBe(
        initialDecorationCount
      );
    });

    it('can be re-focused using the previous `document.activeElement`', () => {
      const editorElement = buildTextEditorElement();
      editorElement.focus();

      const { activeElement } = document;

      editorElement.remove();
      jasmine.attachToDOM(editorElement);
      activeElement.focus();

      expect(editorElement.hasFocus()).toBe(true);
    });
  });

  describe('focus and blur handling', () => {
    it('proxies focus/blur events to/from the hidden input', () => {
      const element = buildTextEditorElement();
      jasmineContent.appendChild(element);

      let blurCalled = false;
      element.addEventListener('blur', () => {
        blurCalled = true;
      });

      element.focus();
      expect(blurCalled).toBe(false);
      expect(element.hasFocus()).toBe(true);
      expect(document.activeElement).toBe(element.querySelector('input'));

      document.body.focus();
      expect(blurCalled).toBe(true);
    });

    it("doesn't trigger a blur event on the editor element when focusing an already focused editor element", () => {
      let blurCalled = false;
      const element = buildTextEditorElement();
      element.addEventListener('blur', () => {
        blurCalled = true;
      });

      jasmineContent.appendChild(element);
      expect(document.activeElement).toBe(document.body);
      expect(blurCalled).toBe(false);

      element.focus();
      expect(document.activeElement).toBe(element.querySelector('input'));
      expect(blurCalled).toBe(false);

      element.focus();
      expect(document.activeElement).toBe(element.querySelector('input'));
      expect(blurCalled).toBe(false);
    });

    describe('when focused while a parent node is being attached to the DOM', () => {
      class ElementThatFocusesChild extends HTMLDivElement {
        attachedCallback() {
          this.firstChild.focus();
        }
      }

      document.registerElement('element-that-focuses-child', {
        prototype: ElementThatFocusesChild.prototype
      });

      it('proxies the focus event to the hidden input', () => {
        const element = buildTextEditorElement();
        const parentElement = document.createElement(
          'element-that-focuses-child'
        );
        parentElement.appendChild(element);
        jasmineContent.appendChild(parentElement);
        expect(document.activeElement).toBe(element.querySelector('input'));
      });
    });

    describe('if focused when invisible due to a zero height and width', () => {
      it('focuses the hidden input and does not throw an exception', () => {
        const parentElement = document.createElement('div');
        parentElement.style.position = 'absolute';
        parentElement.style.width = '0px';
        parentElement.style.height = '0px';

        const element = buildTextEditorElement({ attach: false });
        parentElement.appendChild(element);
        jasmineContent.appendChild(parentElement);

        element.focus();
        expect(document.activeElement).toBe(element.component.getHiddenInput());
      });
    });
  });

  describe('::setModel', () => {
    describe('when the element does not have an editor yet', () => {
      it('uses the supplied one', () => {
        const element = buildTextEditorElement({ attach: false });
        const editor = new TextEditor();
        element.setModel(editor);
        jasmine.attachToDOM(element);
        expect(editor.element).toBe(element);
        expect(element.getModel()).toBe(editor);
      });
    });

    describe('when the element already has an editor', () => {
      it('unbinds it and then swaps it with the supplied one', async () => {
        const element = buildTextEditorElement({ attach: true });
        const previousEditor = element.getModel();
        expect(previousEditor.element).toBe(element);

        const newEditor = new TextEditor();
        element.setModel(newEditor);
        expect(previousEditor.element).not.toBe(element);
        expect(newEditor.element).toBe(element);
        expect(element.getModel()).toBe(newEditor);
      });
    });
  });

  describe('::onDidAttach and ::onDidDetach', () =>
    it('invokes callbacks when the element is attached and detached', () => {
      const element = buildTextEditorElement({ attach: false });

      const attachedCallback = jasmine.createSpy('attachedCallback');
      const detachedCallback = jasmine.createSpy('detachedCallback');

      element.onDidAttach(attachedCallback);
      element.onDidDetach(detachedCallback);

      jasmine.attachToDOM(element);
      expect(attachedCallback).toHaveBeenCalled();
      expect(detachedCallback).not.toHaveBeenCalled();

      attachedCallback.reset();
      element.remove();

      expect(attachedCallback).not.toHaveBeenCalled();
      expect(detachedCallback).toHaveBeenCalled();
    }));

  describe('::setUpdatedSynchronously', () => {
    it('controls whether the text editor is updated synchronously', () => {
      spyOn(window, 'requestAnimationFrame').andCallFake(fn => fn());

      const element = buildTextEditorElement();

      expect(element.isUpdatedSynchronously()).toBe(false);

      element.getModel().setText('hello');
      expect(window.requestAnimationFrame).toHaveBeenCalled();

      expect(element.textContent).toContain('hello');

      window.requestAnimationFrame.reset();
      element.setUpdatedSynchronously(true);
      element.getModel().setText('goodbye');
      expect(window.requestAnimationFrame).not.toHaveBeenCalled();
      expect(element.textContent).toContain('goodbye');
    });
  });

  describe('::getDefaultCharacterWidth', () => {
    it('returns 0 before the element is attached', () => {
      const element = buildTextEditorElement({ attach: false });
      expect(element.getDefaultCharacterWidth()).toBe(0);
    });

    it('returns the width of a character in the root scope', () => {
      const element = buildTextEditorElement();
      jasmine.attachToDOM(element);
      expect(element.getDefaultCharacterWidth()).toBeGreaterThan(0);
    });
  });

  describe('::getMaxScrollTop', () =>
    it('returns the maximum scroll top that can be applied to the element', async () => {
      const editor = new TextEditor();
      editor.setText('1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16');
      const element = editor.getElement();
      element.style.lineHeight = '10px';
      element.style.width = '200px';
      jasmine.attachToDOM(element);

      const horizontalScrollbarHeight = element.component.getHorizontalScrollbarHeight();

      expect(element.getMaxScrollTop()).toBe(0);
      await editor.update({ autoHeight: false });

      element.style.height = 100 + horizontalScrollbarHeight + 'px';
      await element.getNextUpdatePromise();
      expect(element.getMaxScrollTop()).toBe(60);

      element.style.height = 120 + horizontalScrollbarHeight + 'px';
      await element.getNextUpdatePromise();
      expect(element.getMaxScrollTop()).toBe(40);

      element.style.height = 200 + horizontalScrollbarHeight + 'px';
      await element.getNextUpdatePromise();
      expect(element.getMaxScrollTop()).toBe(0);
    }));

  describe('::setScrollTop and ::setScrollLeft', () => {
    it('changes the scroll position', async () => {
      const element = buildTextEditorElement();
      element.getModel().update({ autoHeight: false });
      element.getModel().setText('lorem\nipsum\ndolor\nsit\namet');
      element.setHeight(20);
      await element.getNextUpdatePromise();
      element.setWidth(20);
      await element.getNextUpdatePromise();

      element.setScrollTop(22);
      await element.getNextUpdatePromise();
      expect(element.getScrollTop()).toBe(22);

      element.setScrollLeft(32);
      await element.getNextUpdatePromise();
      expect(element.getScrollLeft()).toBe(32);
    });
  });

  describe('on TextEditor::setMini', () =>
    it("changes the element's 'mini' attribute", async () => {
      const element = buildTextEditorElement();
      expect(element.hasAttribute('mini')).toBe(false);
      element.getModel().setMini(true);
      await element.getNextUpdatePromise();
      expect(element.hasAttribute('mini')).toBe(true);
      element.getModel().setMini(false);
      await element.getNextUpdatePromise();
      expect(element.hasAttribute('mini')).toBe(false);
    }));

  describe('::intersectsVisibleRowRange(start, end)', () => {
    it('returns true if the given row range intersects the visible row range', async () => {
      const element = buildTextEditorElement();
      const editor = element.getModel();
      const horizontalScrollbarHeight = element.component.getHorizontalScrollbarHeight();

      editor.update({ autoHeight: false });
      element.getModel().setText('x\n'.repeat(20));
      element.style.height = 120 + horizontalScrollbarHeight + 'px';
      await element.getNextUpdatePromise();

      element.setScrollTop(80);
      await element.getNextUpdatePromise();
      expect(element.getVisibleRowRange()).toEqual([4, 11]);

      expect(element.intersectsVisibleRowRange(0, 4)).toBe(false);
      expect(element.intersectsVisibleRowRange(0, 5)).toBe(true);
      expect(element.intersectsVisibleRowRange(5, 8)).toBe(true);
      expect(element.intersectsVisibleRowRange(11, 12)).toBe(false);
      expect(element.intersectsVisibleRowRange(12, 13)).toBe(false);
    });
  });

  describe('::pixelRectForScreenRange(range)', () => {
    it('returns a {top/left/width/height} object describing the rectangle between two screen positions, even if they are not on screen', async () => {
      const element = buildTextEditorElement();
      const editor = element.getModel();
      const horizontalScrollbarHeight = element.component.getHorizontalScrollbarHeight();

      editor.update({ autoHeight: false });
      element.getModel().setText('xxxxxxxxxxxxxxxxxxxxxx\n'.repeat(20));
      element.style.height = 120 + horizontalScrollbarHeight + 'px';
      await element.getNextUpdatePromise();
      element.setScrollTop(80);
      await element.getNextUpdatePromise();
      expect(element.getVisibleRowRange()).toEqual([4, 11]);

      const top = 2 * editor.getLineHeightInPixels();
      const bottom = 13 * editor.getLineHeightInPixels();
      const left = Math.round(3 * editor.getDefaultCharWidth());
      const right = Math.round(11 * editor.getDefaultCharWidth());
      expect(element.pixelRectForScreenRange([[2, 3], [13, 11]])).toEqual({
        top,
        left,
        height: bottom + editor.getLineHeightInPixels() - top,
        width: right - left
      });
    });
  });

  describe('events', () => {
    let element = null;

    beforeEach(async () => {
      element = buildTextEditorElement();
      element.getModel().update({ autoHeight: false });
      element.getModel().setText('lorem\nipsum\ndolor\nsit\namet');
      element.setHeight(20);
      await element.getNextUpdatePromise();
      element.setWidth(20);
      await element.getNextUpdatePromise();
    });

    describe('::onDidChangeScrollTop(callback)', () =>
      it('triggers even when subscribing before attaching the element', () => {
        const positions = [];
        const subscription1 = element.onDidChangeScrollTop(p =>
          positions.push(p)
        );
        element.onDidChangeScrollTop(p => positions.push(p));

        positions.length = 0;
        element.setScrollTop(10);
        expect(positions).toEqual([10, 10]);

        element.remove();
        jasmine.attachToDOM(element);

        positions.length = 0;
        element.setScrollTop(20);
        expect(positions).toEqual([20, 20]);

        subscription1.dispose();

        positions.length = 0;
        element.setScrollTop(30);
        expect(positions).toEqual([30]);
      }));

    describe('::onDidChangeScrollLeft(callback)', () =>
      it('triggers even when subscribing before attaching the element', () => {
        const positions = [];
        const subscription1 = element.onDidChangeScrollLeft(p =>
          positions.push(p)
        );
        element.onDidChangeScrollLeft(p => positions.push(p));

        positions.length = 0;
        element.setScrollLeft(10);
        expect(positions).toEqual([10, 10]);

        element.remove();
        jasmine.attachToDOM(element);

        positions.length = 0;
        element.setScrollLeft(20);
        expect(positions).toEqual([20, 20]);

        subscription1.dispose();

        positions.length = 0;
        element.setScrollLeft(30);
        expect(positions).toEqual([30]);
      }));
  });
});
