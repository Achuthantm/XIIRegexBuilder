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

char Lexer::advance() {
    char current = input[pos++];
    col++;
    return current;
}

bool Lexer::isAtEnd() const {
    return pos >= input.length();
}

std::vector<Token> Lexer::tokenize() {
    std::vector<Token> tokens;

    while (!isAtEnd()) {
        char c = peek();
        int currentCharCol = col;

        switch (c) {
            case '.':
                tokens.emplace_back(TokenType::DOT, advance(), line, currentCharCol);
                break;
            case '*':
                tokens.emplace_back(TokenType::STAR, advance(), line, currentCharCol);
                break;
            case '+':
                tokens.emplace_back(TokenType::PLUS, advance(), line, currentCharCol);
                break;
            case '?':
                tokens.emplace_back(TokenType::QUESTION, advance(), line, currentCharCol);
                break;
            case '|':
                tokens.emplace_back(TokenType::PIPE, advance(), line, currentCharCol);
                break;
            case '(':
