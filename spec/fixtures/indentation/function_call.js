foo({
    sd,
    sdf
  },
  4
);

foo( 2, {
    sd,
    sdf
  },
  4
);

foo( 2,
  {
    sd,
    sdf
  });

foo( 2, {
  sd,
  sdf
});

foo(2,
  4);

foo({
  symetric_opening_and_closing_scopes: 'indent me at 1'
});

foo(myWrapper(mysecondWrapper({
  a: 1 // should be at 1
})));
