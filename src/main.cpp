#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <memory>
#include <regex>
#include <algorithm>
#include "lexer.h"
#include "parser.h"
#include "nfa.h"
#include "emitter.h"

std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, (last - first + 1));
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <regex_file> [test_strings_file] [output_dir]" << std::endl;
        return 1;
    }

    std::string regexFilename = argv[1];
    std::string testFilename = (argc > 2) ? argv[2] : "";
    std::string outputDir = (argc > 3) ? argv[3] : "output";

    if (testFilename == "-" || testFilename == "none") {
        testFilename = "";
    }

    std::ifstream regexFile(regexFilename);
    if (!regexFile.is_open()) {
        std::cerr << "Failed to open regex file: " << regexFilename << std::endl;
        return 1;
    }

