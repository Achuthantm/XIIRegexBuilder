################################
# Makefile for XIIRegexBuilder #
################################

# OS Detection
ifeq ($(OS),Windows_NT)
    EXE := .exe
    RM := del /f /q
    RMDIR := rmdir /s /q
    MKDIR = if not exist $(subst /,\,$1) mkdir $(subst /,\,$1)
    FIX_PATH = $(subst /,\,$1)
else
    EXE :=
    RM := rm -f
    RMDIR := rm -rf
    MKDIR = mkdir -p $1
    FIX_PATH = $1
endif

CC = g++
CFLAGS = -Wall -Wextra -std=c++17 -Isrc -static
BUILD_DIR = build
TARGET = $(BUILD_DIR)/regex_builder$(EXE)
TESTER = $(BUILD_DIR)/nfa_tester$(EXE)
GOLDEN = $(BUILD_DIR)/golden$(EXE)
SRCS = src/main.cpp src/lexer.cpp src/parser.cpp src/nfa.cpp src/emitter.cpp
TEST_SRCS = src/parser_tester.cpp src/lexer.cpp src/parser.cpp src/nfa.cpp
GOLDEN_SRCS = src/golden.cpp
OBJS = $(SRCS:.cpp=.o)
TEST_OBJS = $(TEST_SRCS:.cpp=.o)
GOLDEN_OBJS = $(GOLDEN_SRCS:.cpp=.o)

INPUT_DIR = inputs
