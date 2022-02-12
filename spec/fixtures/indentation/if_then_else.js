
/** if-then-else loops */
if (true)
  foo();
else
  bar();

if (true) {
  foo();
  bar();
} else {
  foo();
}

// https://github.com/atom/atom/issues/6691
if (true)
{
  foo();
  bar();
}
else
{
  foo();
}

if (true) {
  if (yes)
    doit(); // 2
  bar();
} else if (more()) {
  foo(); // 1
}

if (true)
  foo();
else
  if (more()) { // 1
  foo(); // 1
}

if (true)
  foo();
else
  if (more()) // 1
    foo(); // 2

if (we
  ()) {
  go();
}

if (true) {
  foo();
  bar();
} else if (false) {
  more();
} else {
  foo();
}
