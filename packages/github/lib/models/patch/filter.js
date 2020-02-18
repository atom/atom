export const MAX_PATCH_CHARS = 1024 * 1024;

export function filter(original) {
  let accumulating = false;
  let accumulated = '';
  let includedChars = 0;
  const removed = new Set();
  const pathRx = /\n?diff --git (?:a|b)\/(\S+) (?:a|b)\/(\S+)/y;

  let index = 0;
  while (index !== -1) {
    let include = true;

    const result = original.indexOf('\ndiff --git ', index);
    const nextIndex = result !== -1 ? result + 1 : -1;
    const patchEnd = nextIndex !== -1 ? nextIndex : original.length;

    // Exclude this patch if its inclusion would cause the patch to become too large.
    const patchChars = patchEnd - index + 1;
    if (includedChars + patchChars > MAX_PATCH_CHARS) {
      include = false;
    }

    if (include) {
      // Avoid copying large buffers of text around if we're including everything anyway.
      if (accumulating) {
        accumulated += original.slice(index, patchEnd);
      }
      includedChars += patchChars;
    } else {
      // If this is the first excluded patch, start by copying everything before this into "accumulated."
      if (!accumulating) {
        accumulating = true;
        accumulated = original.slice(0, index);
      }

      // Extract the removed filenames from the "diff --git" line.
      pathRx.lastIndex = index;
      const pathMatch = pathRx.exec(original);
      if (pathMatch) {
        removed.add(pathMatch[1]);
        removed.add(pathMatch[2]);
      }
    }

    index = nextIndex;
  }

  return {filtered: accumulating ? accumulated : original, removed};
}
