#ifndef LEXER_H
#define LEXER_H

#include <string>
#include <vector>
#include <ostream>

enum class TokenType {
    LITERAL,
    DOT,
    STAR,
    PLUS,
    QUESTION,
    PIPE,
    LPAREN,
    RPAREN,
    END_OF_INPUT
};

struct Token {
    TokenType type;
    char value; // Meaningful for LITERAL, otherwise ignored or holds the char representation
    int line;   // Useful for error reporting
    int column; // Useful for error reporting

    Token(TokenType t, char v = 0, int l = 0, int c = 0)
        : type(t), value(v), line(l), column(c) {}
};

std::string tokenTypeToString(TokenType type);

class Lexer {
public:
    explicit Lexer(const std::string& input, int lineNum = 0);
    std::vector<Token> tokenize();

private:
    std::string input;
    size_t pos;
    int line;
    int col;

    char peek() const;
    char advance();
    bool isAtEnd() const;
};

#endif // LEXER_H
