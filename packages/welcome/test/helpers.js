/** @babel */

export function conditionPromise(predicate) {
  return new Promise(resolve => {
    setInterval(() => {
      if (predicate()) resolve();
    }, 100);
  });
}
