#ifndef NFA_H
#define NFA_H

#include <vector>
#include <set>
#include <map>
#include <memory>
#include "parser.h"

struct NFAState {
    int id;
    bool isAccept;
    // Map from character to set of destination state IDs
    std::map<unsigned char, std::set<int>> transitions;
