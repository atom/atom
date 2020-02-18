export default class IDSequence {
  constructor() {
    this.current = 0;
  }

  nextID() {
    const id = this.current;
    this.current++;
    return id;
  }
}

const seq = new IDSequence();

export function nextID() {
  return seq.nextID().toString();
}
