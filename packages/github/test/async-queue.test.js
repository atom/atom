import {autobind} from '../lib/helpers';
import AsyncQueue from '../lib/async-queue';

class Task {
  constructor(name, error) {
    autobind(this, 'run', 'finish');

    this.name = name;
    this.error = error;
    this.started = false;
    this.finished = false;
  }

  run() {
    this.started = true;
    this.finished = false;
    return new Promise((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }

  finish() {
    this.finished = true;
    if (this.error) {
      this.reject(new Error(this.name));
    } else {
      this.resolve(this.name);
    }
  }
}

describe('AsyncQueue', function() {
  it('runs items in parallel up to the set max', async function() {
    const queue = new AsyncQueue({parallelism: 3});

    const tasks = [
      new Task('task 1'),
      new Task('task 2', true),
      new Task('task 3'),
      new Task('task 4'),
      new Task('task 5'),
    ];
    const results = [false, false, false, false, false];
    const errors = [false, false, false, false, false];

    const p0 = queue.push(() => tasks[0].run());
    const p1 = queue.push(() => tasks[1].run());
    const p2 = queue.push(() => tasks[2].run());
    const p3 = queue.push(() => tasks[3].run());
    const p4 = queue.push(() => tasks[4].run());

    p0.then(value => { results[0] = value; }).catch(err => { errors[0] = err; });
    p1.then(value => { results[1] = value; }).catch(err => { errors[1] = err; });
    p2.then(value => { results[2] = value; }).catch(err => { errors[2] = err; });
    p3.then(value => { results[3] = value; }).catch(err => { errors[3] = err; });
    p4.then(value => { results[4] = value; }).catch(err => { errors[4] = err; });

    assert.isTrue(tasks[0].started);
    assert.isTrue(tasks[1].started);
    assert.isTrue(tasks[2].started);
    assert.isFalse(tasks[3].started);
    assert.isFalse(tasks[4].started);

    assert.isFalse(results[0]);

    tasks[0].finish();
    assert.isTrue(tasks[0].finished);
    await assert.async.equal(results[0], 'task 1');
    assert.isFalse(tasks[1].finished);
    assert.isFalse(results[1]);

    assert.isTrue(tasks[3].started);
    assert.isFalse(tasks[4].started);

    tasks[1].finish();
    assert.isTrue(tasks[1].finished);
    assert.isFalse(tasks[2].finished);
    await assert.async.equal(errors[1].message, 'task 2');

    assert.isTrue(tasks[4].started);
  });

  it('runs non-parallelizable tasks serially', async function() {
    const queue = new AsyncQueue({parallelism: 3});

    const tasks = [
      new Task('task 1'),
      new Task('task 2'),
      new Task('task 3'),
      new Task('task 4'),
      new Task('task 5'),
      new Task('task 6'),
    ];

    const p0 = queue.push(() => tasks[0].run());
    const p1 = queue.push(() => tasks[1].run());
    const p2 = queue.push(() => tasks[2].run(), {parallel: false});
    const p3 = queue.push(() => tasks[3].run(), {parallel: false});
    queue.push(() => tasks[4].run());
    queue.push(() => tasks[5].run());

    assert.isTrue(tasks[0].started);
    assert.isTrue(tasks[1].started);
    assert.isFalse(tasks[2].started); // not parallelizable!!
    assert.isFalse(tasks[3].started);
    assert.isFalse(tasks[4].started);
    assert.isFalse(tasks[5].started);

    tasks[0].finish();
    await p0;
    assert.isFalse(tasks[2].started); // still can't be started
    assert.isFalse(tasks[3].started);

    tasks[1].finish();
    await p1;
    await assert.async.isTrue(tasks[2].started);
    assert.isFalse(tasks[3].started); // still can't be started

    tasks[2].finish();
    await p2;
    await assert.async.isTrue(tasks[3].started);
    assert.isFalse(tasks[4].started); // 3 is non-parallelizable so 4 can't start

    tasks[3].finish();
    await p3;
    await assert.async.isTrue(tasks[4].started); // both can start since they are parallelizable
    assert.isTrue(tasks[5].started);
  });

  it('continues to work when tasks throw synchronous errors', async function() {
    const queue = new AsyncQueue({parallelism: 1});

    const p1 = queue.push(() => {
      throw new Error('error thrown from task 1');
    });
    const p2 = queue.push(() => {
      return new Promise(res => res(2));
    });

    try {
      await p1;
      throw new Error('expected p1 to be rejectd');
    } catch (err) {}
    assert.equal(await p2, 2);
  });
});
