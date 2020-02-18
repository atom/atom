import {firstImplementer} from '../lib/helpers';

class A {
  one() { return 'a-one'; }
  two() { return 'a-two'; }
}

class B {
  two() { return 'b-two'; }
  three() { return 'b-three'; }
}

describe('firstImplementer', function() {
  const a = new A();
  const b = new B();

  it('calls methods from the first target that has the method', function() {
    const target = firstImplementer(a, b);
    assert.equal(target.one, a.one);
    assert.equal(target.two, a.two);
    assert.equal(target.three, b.three);
  });

  it('reports a combined prototype', function() {
    const target = firstImplementer(a, b);
    const proto = Object.getPrototypeOf(target);
    const obj = Object.create(proto);
    assert.equal(obj.one(), 'a-one');
    assert.equal(obj.two(), 'a-two');
    assert.equal(obj.three(), 'b-three');
  });

  it('sets properties that exist on an implementer on that implementer, and ones that do not on the target', function() {
    const target = firstImplementer(a, b);
    target.one = () => 'new-one';
    assert.equal(a.one(), 'new-one');
    target.three = () => 'new-three';
    assert.notOk(a.three);
    assert.equal(b.three(), 'new-three');
    target.four = () => 'four! ah ah ah';
    assert.notOk(a.four);
    assert.notOk(b.four);
    assert.equal(target.four(), 'four! ah ah ah');
  });

  it('correctly reports getOwnPropertyDescriptor', function() {
    const target = firstImplementer(a, b);
    const descOne = Object.getOwnPropertyDescriptor(target, 'one');
    assert.equal(descOne.value, a.one);
    const descThree = Object.getOwnPropertyDescriptor(target, 'three');
    assert.equal(descThree.value, b.three);
    const descTarget = Object.getOwnPropertyDescriptor(target, '__implementations');
    assert.deepEqual(descTarget.value, [a, b]);
  });

  it('provides an accessor for all implementers', function() {
    const target = firstImplementer(a, b);
    assert.deepEqual(target.getImplementers(), [a, b]);
  });
});
