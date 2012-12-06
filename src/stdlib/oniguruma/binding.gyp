{
  "targets": [
    {
      "target_name": "onig_scanner",
      "sources": ["src/libonig.a", "src/onig-result.cc", "src/onig-reg-exp.cc", "src/onig-scanner.cc"],
      "libraries": ["../src/libonig.a"], # path is relative to the 'build' directory
    }
  ]
}
