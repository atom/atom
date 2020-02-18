import React from 'react';
import {mount} from 'enzyme';

import ContextMenuInterceptor from '../lib/context-menu-interceptor';

class SampleComponent extends React.Component {
  render() {
    return (
      <div className="parent">
        <div className="child">
          This element has content.
        </div>
      </div>
    );
  }
}

describe('ContextMenuInterceptor', function() {
  let rootElement, rootHandler, rootHandlerCalled;

  beforeEach(function() {
    rootHandlerCalled = false;
    rootHandler = event => {
      rootHandlerCalled = true;
      event.preventDefault();
      return false;
    };
    document.addEventListener('contextmenu', rootHandler);

    rootElement = document.createElement('div');
    document.body.appendChild(rootElement);
  });

  afterEach(function() {
    document.removeEventListener('contextmenu', rootHandler);
    ContextMenuInterceptor.dispose();
    rootElement.remove();
  });

  it('responds to native contextmenu events before they reach the document root', function() {
    let interceptorHandlerCalled = false;
    let rootHandlerCalledFirst = false;
    const handler = () => {
      interceptorHandlerCalled = true;
      rootHandlerCalledFirst = rootHandlerCalled;
    };

    const wrapper = mount(
      <ContextMenuInterceptor onWillShowContextMenu={handler}>
        <SampleComponent />
      </ContextMenuInterceptor>,
      {attachTo: rootElement},
    );

    const targetDOMNode = wrapper.find('.child').getDOMNode();
    const event = new MouseEvent('contextmenu', {
      bubbles: true,
      cancelable: true,
    });
    targetDOMNode.dispatchEvent(event);

    assert.isTrue(interceptorHandlerCalled);
    assert.isFalse(rootHandlerCalledFirst);
    assert.isTrue(rootHandlerCalled);
  });

  it('can prevent event propagation', function() {
    let interceptorHandlerCalled = false;
    const handler = () => {
      interceptorHandlerCalled = true;
      event.stopPropagation();
    };

    const wrapper = mount(
      <ContextMenuInterceptor onWillShowContextMenu={handler}>
        <SampleComponent />
      </ContextMenuInterceptor>,
      {attachTo: rootElement},
    );

    const targetDOMNode = wrapper.find('.child').getDOMNode();
    const event = new MouseEvent('contextmenu', {
      bubbles: true,
      cancelable: true,
    });
    targetDOMNode.dispatchEvent(event);

    assert.isTrue(interceptorHandlerCalled);
    assert.isFalse(rootHandlerCalled);
  });

  it('ignores contextmenu events from other children', function() {
    let interceptorHandlerCalled = false;
    const handler = () => {
      interceptorHandlerCalled = true;
    };

    const wrapper = mount(
      <div>
        <ContextMenuInterceptor onWillShowContextMenu={handler}>
          <SampleComponent />
        </ContextMenuInterceptor>
        <div className="unrelated">
          <div className="otherNode">
            This is another div.
          </div>
        </div>
      </div>,
      {attachTo: rootElement},
    );

    const targetDOMNode = wrapper.find('.otherNode').getDOMNode();
    const event = new MouseEvent('contextmenu', {
      bubbles: true,
      cancelable: true,
    });
    targetDOMNode.dispatchEvent(event);

    assert.isFalse(interceptorHandlerCalled);
    assert.isTrue(rootHandlerCalled);
  });

  it('cleans itself up on .dispose()', function() {
    let interceptorHandlerCalled = false;
    const handler = () => {
      interceptorHandlerCalled = true;
    };

    const wrapper = mount(
      <ContextMenuInterceptor onWillShowContextMenu={handler}>
        <SampleComponent />
      </ContextMenuInterceptor>,
      {attachTo: rootElement},
    );

    ContextMenuInterceptor.dispose();

    const targetDOMNode = wrapper.find('.child').getDOMNode();
    const event = new MouseEvent('contextmenu', {
      bubbles: true,
      cancelable: true,
    });
    targetDOMNode.dispatchEvent(event);

    assert.isFalse(interceptorHandlerCalled);
    assert.isTrue(rootHandlerCalled);
  });
});
