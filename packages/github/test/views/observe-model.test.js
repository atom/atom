import {Emitter} from 'event-kit';

import React from 'react';
import {mount, shallow} from 'enzyme';

import ObserveModel from '../../lib/views/observe-model';

class TestModel {
  constructor(data) {
    this.emitter = new Emitter();
    this.data = data;
  }

  update(data) {
    this.data = data;
    this.didUpdate();
  }

  getData() {
    return Promise.resolve(this.data);
  }

  didUpdate() {
    return this.emitter.emit('did-update');
  }

  onDidUpdate(cb) {
    return this.emitter.on('did-update', cb);
  }
}

class TestComponent extends React.Component {
  render() {
    return (
      <ObserveModel model={this.props.testModel} fetchData={model => model.getData()}>
        {data => (
          data ? <div>{data.one} - {data.two}</div> : <div>no data</div>
        )}
      </ObserveModel>
    );
  }
}

describe('ObserveModel', function() {
  it('watches a model, re-rendering a child function when it changes', async function() {
    const model = new TestModel({one: 1, two: 2});
    const app = <TestComponent testModel={model} />;
    const wrapper = mount(app);

    await assert.async.equal(wrapper.text(), '1 - 2');

    model.update({one: 'one', two: 'two'});
    await assert.async.equal(wrapper.text(), 'one - two');

    wrapper.setProps({testModel: null});
    await assert.async.equal(wrapper.text(), 'no data');

    const model2 = new TestModel({one: 1, two: 2});
    wrapper.setProps({testModel: model2});
    await assert.async.equal(wrapper.text(), '1 - 2');
  });

  describe('fetch parameters', function() {
    let model, fetchData, children;

    beforeEach(function() {
      model = new TestModel({one: 'a', two: 'b'});
      fetchData = async (m, a, b, c) => {
        const data = await m.getData();
        return {a, b, c, ...data};
      };
      children = sinon.spy();
    });

    it('are provided as additional arguments to the fetchData call', async function() {
      shallow(<ObserveModel model={model} fetchParams={[1, 2, 3]} fetchData={fetchData} children={children} />);

      await assert.async.isTrue(children.calledWith({a: 1, b: 2, c: 3, one: 'a', two: 'b'}));
    });

    it('trigger a re-fetch when any change referential equality', async function() {
      const wrapper = shallow(
        <ObserveModel model={model} fetchParams={[1, 2, 3]} fetchData={fetchData} children={children} />,
      );
      await assert.async.isTrue(children.calledWith({a: 1, b: 2, c: 3, one: 'a', two: 'b'}));

      wrapper.setProps({fetchParams: [1, 5, 3]});
      await assert.async.isTrue(children.calledWith({a: 1, b: 5, c: 3, one: 'a', two: 'b'}));
    });
  });
});
