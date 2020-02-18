import {Emitter} from 'event-kit';

import StubItem from '../../lib/items/stub-item';

class RealItem {
  constructor() {
    this.emitter = new Emitter();
  }

  getTitle() { return 'real-title'; }
  getIconName() { return 'real-icon-name'; }
  getOne() { return 1; }
  getElement() { return 'real-element'; }

  onDidChangeTitle(cb) { return this.emitter.on('did-change-title', cb); }
  onDidChangeIcon(cb) { return this.emitter.on('did-change-icon', cb); }
  onDidDestroy(cb) { return this.emitter.on('did-destroy', cb); }

  destroy() {
    this.emitter.emit('did-destroy');
    this.emitter.dispose();
  }
}

describe('StubItem', function() {
  let stub;

  beforeEach(function() {
    stub = StubItem.create('name', {
      title: 'stub-title',
      iconName: 'stub-icon-name',
    });
  });

  afterEach(function() {
    stub.destroy();
  });

  describe('#setRealItem', function() {
    let realItem;

    beforeEach(function() {
      realItem = new RealItem();
    });

    afterEach(function() {
      realItem.destroy();
    });

    it('sets the real item', function() {
      assert.isNull(stub.getRealItem());
      stub.setRealItem(realItem);
      assert.equal(stub.getRealItem(), realItem);
    });

    it('emits a title change immediately', function() {
      const cb = sinon.stub();
      stub.onDidChangeTitle(cb);
      stub.setRealItem(realItem);
      assert.equal(cb.callCount, 1);
    });

    it('emits an icon change immediately', function() {
      const cb = sinon.stub();
      stub.onDidChangeIcon(cb);
      stub.setRealItem(realItem);
      assert.equal(cb.callCount, 1);
    });

    describe('method forwarding', function() {
      it('forwards getTitle and getIconName', function() {
        assert.equal(stub.getTitle(), 'stub-title');
        assert.equal(stub.getIconName(), 'stub-icon-name');
        stub.setRealItem(realItem);
        assert.equal(stub.getTitle(), 'real-title');
        assert.equal(stub.getIconName(), 'real-icon-name');
      });

      it('forwards random methods', function() {
        stub.setRealItem(realItem);
        assert.equal(stub.getOne(), 1);
      });

      it('does not forward getElement', function() {
        stub.setRealItem(realItem);
        assert.notEqual(stub.getElement(), realItem.getElement());
      });

      it('allows getting the stub', function() {
        assert.equal(stub._getStub().getTitle(), stub.getTitle());
      });
    });

    describe('event forwarding', function() {
      it('forwards onDidChangeTitle, onDidChangeIcon, and onDidDestroy', function() {
        const didChangeTitle = sinon.stub();
        const didChangeIcon = sinon.stub();
        const didDestroy = sinon.stub();

        stub.onDidChangeTitle(didChangeTitle);
        stub.onDidChangeIcon(didChangeIcon);
        stub.onDidDestroy(didDestroy);

        stub.setRealItem(realItem);
        didChangeTitle.reset();
        didChangeIcon.reset();

        realItem.emitter.emit('did-change-title');
        assert.equal(didChangeTitle.callCount, 1);
        realItem.emitter.emit('did-change-icon');
        assert.equal(didChangeIcon.callCount, 1);
        realItem.emitter.emit('did-destroy');
        assert.equal(didDestroy.callCount, 1);
      });
    });
  });
});
