#ifndef PARSER_H
#define PARSER_H

#include <memory>
#include <vector>
#include <set>
#include "lexer.h"

enum class ASTNodeType {
    LITERAL,
    DOT,
    CONCATENATION,
    UNION,
    STAR,
    PLUS,
    OPTIONAL
};

class ASTNode {
public:
    ASTNodeType type;
    virtual ~ASTNode() = default;

    // The following fields are populated by the NFA builder (Stage 2), NOT the parser.
    bool nullable = false;
    std::set<int> firstpos;
    std::set<int> lastpos;

    explicit ASTNode(ASTNodeType t) : type(t) {}
};

std::string nodeTypeToString(ASTNodeType type);

class LiteralNode : public ASTNode {
public:
