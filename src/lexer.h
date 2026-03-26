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
