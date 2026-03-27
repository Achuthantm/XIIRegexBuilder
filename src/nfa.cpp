#include "nfa.h"
#include <iostream>
#include <algorithm>

// Start at -1 so the first ++globalStateCounter gives 0.
int NFABuilder::globalStateCounter = -1;

void NFA::addState(int id, bool isAccept) {
    states.emplace(id, NFAState(id, isAccept));
}

void NFA::addTransition(int fromId, unsigned char c, int toId) {
    states.at(fromId).transitions[c].insert(toId);
}

bool NFA::simulate(const std::string& input) const {
    std::set<int> activeStates = {startStateId};
    
    for (unsigned char c : input) {
        std::set<int> nextStates;
        for (int stateId : activeStates) {
            auto& state = states.at(stateId);
            if (state.transitions.count(c)) {
                for (int nextId : state.transitions.at(c)) {
                    nextStates.insert(nextId);
                }
            }
        }
        activeStates = nextStates;
        if (activeStates.empty()) return false;
    }
    
    for (int stateId : activeStates) {
        if (states.at(stateId).isAccept) return true;
    }
    return false;
}

std::unique_ptr<NFA> NFABuilder::build(ASTNode* root, int regexIdx) {
    if (!root) return nullptr;

    auto nfa = std::make_unique<NFA>(regexIdx);
    
    // 1. Linearization (assign positions to symbols)
    int localPosCounter = 1;
    std::map<int, unsigned char> posToChar;
    std::set<int> dotPositions;
    linearize(root, localPosCounter, posToChar, dotPositions);
    int numPositions = localPosCounter - 1;

    // 2. Compute nullable, firstpos, lastpos
    computeNullableFirstLast(root);

    // 3. Compute followpos
    std::map<int, std::set<int>> followpos;
    for (int i = 1; i <= numPositions; ++i) {
        followpos[i] = std::set<int>();
    }
    computeFollowpos(root, followpos);

    // 4. Build NFA states and transitions
    // Glushkov states: 0 (initial) + 1..n
    // We map these to global IDs. 
    // Invariant: after each build(), globalStateCounter equals the highest global ID used.
    
    int startGlobalId = ++globalStateCounter;
    nfa->startStateId = startGlobalId;
    std::map<int, int> localToGlobal;
    localToGlobal[0] = startGlobalId;
    nfa->addState(startGlobalId, root->nullable);

    for (int i = 1; i <= numPositions; ++i) {
        localToGlobal[i] = ++globalStateCounter;
        bool isAccept = (root->lastpos.find(i) != root->lastpos.end());
        nfa->addState(localToGlobal[i], isAccept);
    }

    // Transitions from state 0
    for (int p : root->firstpos) {
        if (dotPositions.find(p) != dotPositions.end()) { // DOT
            for (int val = 32; val <= 126; ++val) {
                nfa->addTransition(localToGlobal[0], static_cast<unsigned char>(val), localToGlobal[p]);
            }
        } else {
            unsigned char c = posToChar[p];
            nfa->addTransition(localToGlobal[0], c, localToGlobal[p]);
        }
    }
