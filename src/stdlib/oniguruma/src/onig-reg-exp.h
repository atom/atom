#ifndef ONIG_REG_EXP_H_
#define ONIG_REG_EXP_H_

#include <string>
#include "oniguruma.h"

class OnigResult;

class OnigRegExp {
  public:
    OnigRegExp(const std::string& source);
    ~OnigRegExp();

    bool Contains(const std::string& value);
    int LocationAt(int index);
    void Search(const std::string &searchString, size_t position, OnigResult **result);

  private:
    std::string source_;
    regex_t* regex_;
};

#endif // ONIG_REG_EXP_H_