#include "parser.h"
#include <stdexcept>

std::string nodeTypeToString(ASTNodeType type) {
    switch (type) {
        case ASTNodeType::LITERAL:       return "LITERAL";
        case ASTNodeType::DOT:           return "DOT";
        case ASTNodeType::CONCATENATION: return "CONCATENATION";
        case ASTNodeType::UNION:         return "UNION";
        case ASTNodeType::STAR:          return "STAR";
        case ASTNodeType::PLUS:          return "PLUS";
        case ASTNodeType::OPTIONAL:      return "OPTIONAL";
        default:                         return "UNKNOWN";
    }
}

Parser::Parser(const std::vector<Token>& tokens) : tokens(tokens), pos(0) {}

std::unique_ptr<ASTNode> Parser::parse() {
    auto root = parseExpression();
    if (!isAtEnd() && peek().type != TokenType::END_OF_INPUT) {
        error("Unexpected token at end of expression: " + tokenTypeToString(peek().type));
    }
    return root;
}

// Expression -> Term ( '|' Term )*
std::unique_ptr<ASTNode> Parser::parseExpression() {
    if (check(TokenType::PIPE)) {
        error("Empty alternation branch (missing left side)");
    }
    auto left = parseTerm();

    while (match(TokenType::PIPE)) {
        if (isAtEnd() || peek().type == TokenType::RPAREN || peek().type == TokenType::PIPE || peek().type == TokenType::END_OF_INPUT) {
            error("Empty alternation branch");
        }
        auto right = parseTerm();
        left = std::make_unique<UnionNode>(std::move(left), std::move(right));
    }

    return left;
