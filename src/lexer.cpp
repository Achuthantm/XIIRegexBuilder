#include "lexer.h"
#include <stdexcept>

std::string tokenTypeToString(TokenType type) {
    switch (type) {
        case TokenType::LITERAL:   return "LITERAL";
        case TokenType::DOT:       return "DOT";
        case TokenType::STAR:      return "STAR";
        case TokenType::PLUS:      return "PLUS";
        case TokenType::QUESTION:  return "QUESTION";
        case TokenType::PIPE:      return "PIPE";
        case TokenType::LPAREN:    return "LPAREN";
        case TokenType::RPAREN:    return "RPAREN";
        case TokenType::END_OF_INPUT: return "END_OF_INPUT";
        default:                   return "UNKNOWN";
    }
}

Lexer::Lexer(const std::string& input, int lineNum)
    : input(input), pos(0), line(lineNum), col(1) {}

char Lexer::peek() const {
    if (isAtEnd()) return '\0';
    return input[pos];
}

