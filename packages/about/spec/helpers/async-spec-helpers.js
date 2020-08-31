/** @babel */

const { now } = Date;
const { setTimeout } = global;

export async function conditionPromise(condition) {
  const startTime = now();

  while (true) {
    await timeoutPromise(100);

    if (await condition()) {
      return;
    }

    if (now() - startTime > 5000) {
      throw new Error('Timed out waiting on condition');
    }
  }
}

export function timeoutPromise(timeout) {
  return new Promise(function(resolve) {
    setTimeout(resolve, timeout);
  });
}
