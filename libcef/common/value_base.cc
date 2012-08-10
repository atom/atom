// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/common/value_base.h"


CefValueController::CefValueController()
  : owner_value_(NULL),
    owner_object_(NULL) {
}

CefValueController::~CefValueController() {
  // Everything should already have been removed.
  DCHECK(!owner_value_ && !owner_object_);
  DCHECK(reference_map_.empty());
  DCHECK(dependency_map_.empty());
}

void CefValueController::SetOwner(void* value, Object* object) {
  DCHECK(value && object);

  // Controller should already be locked.
  DCHECK(locked());

  // Owner should only be set once.
  DCHECK(!owner_value_ && !owner_object_);

  owner_value_ = value;
  owner_object_ = object;
}

void CefValueController::AddReference(void* value, Object* object) {
  DCHECK(value && object);

  // Controller should already be locked.
  DCHECK(locked());

  // Controller should currently have an owner.
  DCHECK(owner_value_);

  // Values should only be added once.
  DCHECK(reference_map_.find(value) == reference_map_.end());
  DCHECK(value != owner_value_);

  reference_map_.insert(std::make_pair(value, object));
}

void CefValueController::Remove(void* value, bool notify_object) {
  DCHECK(value);

  // Controller should already be locked.
  DCHECK(locked());

  // Controller should currently have an owner.
  DCHECK(owner_value_);

  if (value == owner_value_) {
    // Should never notify when removing the owner object.
    DCHECK(!notify_object);

    owner_value_ = NULL;
    owner_object_ = NULL;

    // Remove all references.
    if (reference_map_.size() > 0) {
      ReferenceMap::iterator it = reference_map_.begin();
      for (; it != reference_map_.end(); ++it)
        it->second->OnControlRemoved();
      reference_map_.clear();
    }

    // Remove all dependencies.
    dependency_map_.clear();
  } else {
    ReferenceMap::iterator it = reference_map_.find(value);
    if (it != reference_map_.end()) {
      // Remove the reference.
      if (notify_object)
        it->second->OnControlRemoved();
      reference_map_.erase(it);
    }
  }
}

CefValueController::Object* CefValueController::Get(void* value) {
  DCHECK(value);

  // Controller should already be locked.
  DCHECK(locked());

  if (value == owner_value_) {
    return owner_object_;
  } else {
    ReferenceMap::iterator it = reference_map_.find(value);
    if (it != reference_map_.end())
      return it->second;
    return NULL;
  }
}

void CefValueController::AddDependency(void* parent, void* child) {
  DCHECK(parent && child && parent != child);

  // Controller should already be locked.
  DCHECK(locked());

  DependencyMap::iterator it = dependency_map_.find(parent);
  if (it == dependency_map_.end()) {
    // New set.
    DependencySet set;
    set.insert(child);
    dependency_map_.insert(std::make_pair(parent, set));
  } else if (it->second.find(child) == it->second.end()) {
    // Update existing set.
    it->second.insert(child);
  }
}

void CefValueController::RemoveDependencies(void* value) {
  DCHECK(value);

  // Controller should already be locked.
  DCHECK(locked());

  if (dependency_map_.empty())
    return;

  DependencyMap::iterator it_dependency = dependency_map_.find(value);
  if (it_dependency == dependency_map_.end())
    return;

  // Start with the set of dependencies for the current value.
  DependencySet remove_set = it_dependency->second;
  dependency_map_.erase(it_dependency);

  DependencySet::iterator it_value;
  ReferenceMap::iterator it_reference;

  while (remove_set.size() > 0) {
    it_value = remove_set.begin();
    value = *it_value;
    remove_set.erase(it_value);

    // Does the current value have dependencies?
    it_dependency = dependency_map_.find(value);
    if (it_dependency != dependency_map_.end()) {
      // Append the dependency set to the remove set.
      remove_set.insert(it_dependency->second.begin(),
                        it_dependency->second.end());
      dependency_map_.erase(it_dependency);
    }

    // Does the current value have a reference?
    it_reference = reference_map_.find(value);
    if (it_reference != reference_map_.end()) {
      // Remove the reference.
      it_reference->second->OnControlRemoved();
      reference_map_.erase(it_reference);
    }
  }
}

void CefValueController::TakeFrom(CefValueController* other) {
  DCHECK(other);

  // Both controllers should already be locked.
  DCHECK(locked());
  DCHECK(other->locked());

  if (!other->reference_map_.empty()) {
    // Transfer references from the other to this.
    ReferenceMap::iterator it = other->reference_map_.begin();
    for (; it != other->reference_map_.end(); ++it) {
      // References should only be added once.
      DCHECK(reference_map_.find(it->first) == reference_map_.end());
      reference_map_.insert(std::make_pair(it->first, it->second));
    }
    other->reference_map_.empty();
  }

  if (!other->dependency_map_.empty()) {
    // Transfer dependencies from the other to this.
    DependencyMap::iterator it_other = other->dependency_map_.begin();
    for (; it_other != other->dependency_map_.end(); ++it_other) {
      DependencyMap::iterator it_me = dependency_map_.find(it_other->first);
      if (it_me == dependency_map_.end()) {
        // All children are new.
        dependency_map_.insert(
            std::make_pair(it_other->first, it_other->second));
      } else {
        // Evaluate each child.
        DependencySet::iterator it_other_set = it_other->second.begin();
        for (; it_other_set != it_other->second.end(); ++it_other_set) {
          if (it_me->second.find(*it_other_set) == it_me->second.end())
            it_me->second.insert(*it_other_set);
        }
      }
    }
  }
}
