#ifndef ONIG_RESULT_H_
#define ONIG_RESULT_H_

#include <string>
#include "oniguruma.h"

class OnigRegExp;

class OnigResult {
  public:
    OnigResult();
    OnigResult(OnigRegion *region, std::string &searchString);
    ~OnigResult();

    int Count();
    int LocationAt(int index);
    int LengthAt(int index);

    std::string searchString_;
    OnigRegion *region_;
};

#endif // ONIG_RESULT_H_