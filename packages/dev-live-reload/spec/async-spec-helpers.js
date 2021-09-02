/** @babel */

export async function conditionPromise(
  condition,
  description = 'anonymous condition'
) {
  const startTime = Date.now();

  while (true) {
    await timeoutPromise(100);

    if (await condition()) {
      return;
    }

    if (Date.now() - startTime > 5000) {
      throw new Error('Timed out waiting on ' + description);
    }
  }
}

export function timeoutPromise(timeout) {
  return new Promise(function(resolve) {
    global.setTimeout(resolve, timeout);
  });
}
