#ifndef ONIG_REG_EXP_H_
#define ONIG_REG_EXP_H_

#include <string>
#include "oniguruma.h"

class OnigResult;

class OnigRegExp {
  public:
    OnigRegExp(std::string source);
    ~OnigRegExp();

    bool Contains(std::string value);
    int LocationAt(int index);
    void Search(std::string &searchString, int position, OnigResult **result);

  private:
    std::string source_;
    regex_t *regex_;
};

#endif // ONIG_REG_EXP_H_