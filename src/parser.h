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
    OPTIONAL,
    CHAR_CLASS
};

class ASTNode {
public:
    ASTNodeType type;
    virtual ~ASTNode() = default;

    bool nullable = false;
    std::set<int> firstpos;
    std::set<int> lastpos;

    explicit ASTNode(ASTNodeType t) : type(t) {}
};

std::string nodeTypeToString(ASTNodeType type);

class LiteralNode : public ASTNode {
public:
    char value;
    int position;
    explicit LiteralNode(char v) : ASTNode(ASTNodeType::LITERAL), value(v), position(-1) {}
};

class CharClassNode : public ASTNode {
public:
    std::set<unsigned char> characters;
    int position;
    CharClassNode() : ASTNode(ASTNodeType::CHAR_CLASS), position(-1) {}
};

class DotNode : public ASTNode {
public:
    int position;
    DotNode() : ASTNode(ASTNodeType::DOT), position(-1) {}
};

class ConcatenationNode : public ASTNode {
public:
    std::unique_ptr<ASTNode> left;
    std::unique_ptr<ASTNode> right;
    ConcatenationNode(std::unique_ptr<ASTNode> l, std::unique_ptr<ASTNode> r)
        : ASTNode(ASTNodeType::CONCATENATION), left(std::move(l)), right(std::move(r)) {}
};

class UnionNode : public ASTNode {
public:
    std::unique_ptr<ASTNode> left;
    std::unique_ptr<ASTNode> right;
    UnionNode(std::unique_ptr<ASTNode> l, std::unique_ptr<ASTNode> r)
        : ASTNode(ASTNodeType::UNION), left(std::move(l)), right(std::move(r)) {}
};

class StarNode : public ASTNode {
public:
    std::unique_ptr<ASTNode> inner;
    explicit StarNode(std::unique_ptr<ASTNode> i)
        : ASTNode(ASTNodeType::STAR), inner(std::move(i)) {}
};

class PlusNode : public ASTNode {
public:
    std::unique_ptr<ASTNode> inner;
    explicit PlusNode(std::unique_ptr<ASTNode> i)
        : ASTNode(ASTNodeType::PLUS), inner(std::move(i)) {}
};

class OptionalNode : public ASTNode {
public:
    std::unique_ptr<ASTNode> inner;
    explicit OptionalNode(std::unique_ptr<ASTNode> i)
        : ASTNode(ASTNodeType::OPTIONAL), inner(std::move(i)) {}
};

class Parser {
public:
    explicit Parser(const std::vector<Token>& tokens);
    std::unique_ptr<ASTNode> parse();

private:
    const std::vector<Token>& tokens;
    size_t pos;

    std::unique_ptr<ASTNode> parseExpression();
    std::unique_ptr<ASTNode> parseTerm();
    std::unique_ptr<ASTNode> parseFactor();
    std::unique_ptr<ASTNode> parseAtom();

    const Token& peek() const;
    const Token& advance();
    bool match(TokenType type);
    bool check(TokenType type) const;
    bool isAtEnd() const;

    void error(const std::string& message) const;
};

#endif // PARSER_H
