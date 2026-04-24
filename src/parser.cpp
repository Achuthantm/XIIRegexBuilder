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
        case ASTNodeType::CHAR_CLASS:    return "CHAR_CLASS";
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
    if (check(TokenType::PIPE)) error("Empty alternation branch");
    auto left = parseTerm();
    while (match(TokenType::PIPE)) {
        auto right = parseTerm();
        left = std::make_unique<UnionNode>(std::move(left), std::move(right));
    }
    return left;
}

// Term -> Factor+
std::unique_ptr<ASTNode> Parser::parseTerm() {
    auto node = parseFactor();

    while (!isAtEnd() && 
           peek().type != TokenType::PIPE && 
           peek().type != TokenType::RPAREN && 
           peek().type != TokenType::END_OF_INPUT) {
        auto next = parseFactor();
        node = std::make_unique<ConcatenationNode>(std::move(node), std::move(next));
    }

    return node;
}

// Factor -> Atom ( '*' | '+' | '?' )?
std::unique_ptr<ASTNode> Parser::parseFactor() {
    auto node = parseAtom();

    if (match(TokenType::STAR)) {
        node = std::make_unique<StarNode>(std::move(node));
    } else if (match(TokenType::PLUS)) {
        node = std::make_unique<PlusNode>(std::move(node));
    } else if (match(TokenType::QUESTION)) {
        node = std::make_unique<OptionalNode>(std::move(node));
    }

    return node;
}

// Atom -> LITERAL | DOT | '(' Expression ')'
std::unique_ptr<ASTNode> Parser::parseAtom() {
    if (match(TokenType::LITERAL)) {
        return std::make_unique<LiteralNode>(tokens[pos - 1].value);
    }

    if (match(TokenType::DOT)) {
        return std::make_unique<DotNode>();
    }

    if (match(TokenType::LPAREN)) {
        auto node = parseExpression();
        if (!match(TokenType::RPAREN)) error("Unmatched parenthesis");
        return node;
    }

    if (match(TokenType::LBRACKET)) {
        auto node = std::make_unique<CharClassNode>();
        while (!check(TokenType::RBRACKET) && !isAtEnd()) {
            if (peek().type == TokenType::END_OF_INPUT) error("Unterminated char class");
            char start = advance().value;
            if (peek().value == '-' && pos + 1 < tokens.size() && 
                (tokens[pos+1].type == TokenType::LITERAL || tokens[pos+1].type == TokenType::DOT)) {
                advance(); // consume '-'
                char end = advance().value;
                for (int c = start; c <= end; ++c) node->characters.insert(static_cast<unsigned char>(c));
            } else {
                node->characters.insert(static_cast<unsigned char>(start));
            }
        }
        if (!match(TokenType::RBRACKET)) error("Expected ']' after char class");
        return node;
    }

    if (peek().type == TokenType::STAR || peek().type == TokenType::PLUS || peek().type == TokenType::QUESTION) {
        error("Quantifier applied to nothing");
    }

    error("Unexpected token: " + tokenTypeToString(peek().type));
    return nullptr;
}

const Token& Parser::peek() const {
    return tokens[pos];
}

const Token& Parser::advance() {
    if (!isAtEnd()) pos++;
    return tokens[pos - 1];
}

bool Parser::match(TokenType type) {
    if (check(type)) {
        advance();
        return true;
    }
    return false;
}

bool Parser::check(TokenType type) const {
    if (isAtEnd()) return false;
    return peek().type == type;
}

bool Parser::isAtEnd() const {
    return pos >= tokens.size() || tokens[pos].type == TokenType::END_OF_INPUT;
}

void Parser::error(const std::string& message) const {
    const Token& t = peek();
    throw std::runtime_error(message + " at line " + std::to_string(t.line) + ", column " + std::to_string(t.column));
}
