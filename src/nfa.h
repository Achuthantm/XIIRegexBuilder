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
    static int globalStateCounter;
    static std::unique_ptr<NFA> build(ASTNode* root, int regexIdx);

private:
    static void linearize(ASTNode* node, int& posCounter, std::map<int, std::set<unsigned char>>& posToChars, std::set<int>& dotPositions);
    static void computeNullableFirstLast(ASTNode* node);
    static void computeFollowpos(ASTNode* node, std::map<int, std::set<int>>& followpos);
};

#endif // NFA_H
