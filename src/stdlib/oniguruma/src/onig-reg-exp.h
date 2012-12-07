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
    OnigResult *Search(const std::string &searchString, size_t position);

  private:
    OnigRegExp(const OnigRegExp&); // Disallow copying
    OnigRegExp &operator=(const OnigRegExp&);  // Disallow copying

    std::string source_;
    regex_t* regex_;
};

#endif // ONIG_REG_EXP_H_