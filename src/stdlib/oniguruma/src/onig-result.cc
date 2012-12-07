#include <string>
#include <iostream>

#include "oniguruma.h"
#include "onig-reg-exp.h"
#include "onig-result.h"

OnigResult::OnigResult(OnigRegion* region, const std::string& searchString) : searchString_(searchString) {
  region_ = region;
}

OnigResult::~OnigResult() {
  onig_region_free(region_, 1);
}

int OnigResult::Count() {
  return region_->num_regs;
}

int OnigResult::LocationAt(int index) {
  return *(region_->beg + index);
}

int OnigResult::LengthAt(int index) {
  return *(region_->end + index) - *(region_->beg + index);
}
