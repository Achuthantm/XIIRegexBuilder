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

    explicit NFAState(int id, bool isAccept = false) : id(id), isAccept(isAccept) {}
};

class NFA {
public:
    int regexIndex;
    int startStateId;
    std::map<int, NFAState> states;

    explicit NFA(int idx) : regexIndex(idx), startStateId(-1) {}
    void addState(int id, bool isAccept = false);
    void addTransition(int fromId, unsigned char c, int toId);
    bool simulate(const std::string& input) const;
};

class NFABuilder {
public:
    // Global state counter to ensure unique IDs across all NFAs
