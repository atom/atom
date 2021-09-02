class MyClass extends OtherComponent {

  state = {
    test: 1
  }

  constructor() {
    test();
  }

  otherfunction = (a, b = {
    default: false
  }) => {
    more();
  }
}
