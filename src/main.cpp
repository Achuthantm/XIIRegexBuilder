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
    bool isPII = false;
    int argOffset = 1;
    if (argc > 1 && std::string(argv[1]) == "--pii") {
        isPII = true;
        argOffset = 2;
    }

    if (argc < argOffset + 1) {
        std::cerr << "Usage: " << argv[0] << " [--pii] <regex_file> [test_strings_file] [output_dir]" << std::endl;
        return 1;
    }

    std::string regexFilename = argv[argOffset];
    std::string testFilename = (argc > argOffset + 1) ? argv[argOffset + 1] : "";
    std::string outputDir = (argc > argOffset + 2) ? argv[argOffset + 2] : "output";

    if (testFilename == "-" || testFilename == "none") {
        testFilename = "";
    }

    std::ifstream regexFile(regexFilename);
    if (!regexFile.is_open()) {
        std::cerr << "Failed to open regex file: " << regexFilename << std::endl;
        return 1;
    }

    std::string line;
    int lineNum = 0;
    int regexIdx = 0;
    std::vector<std::unique_ptr<NFA>> nfas;
    std::vector<std::string> rawRegexes;

    std::cout << "Starting XIIRegexBuilder pipeline..." << std::endl;

    while (std::getline(regexFile, line)) {
        lineNum++;
        std::string trimmedLine = trim(line);
        if (trimmedLine.empty() || trimmedLine[0] == '#') continue;

        std::cout << "Processing Regex [" << regexIdx << "]: " << trimmedLine << std::endl;

        Lexer lexer(trimmedLine, lineNum);
        try {
            std::vector<Token> tokens = lexer.tokenize();
            Parser parser(tokens);
            auto ast = parser.parse();
            auto nfa = NFABuilder::build(ast.get(), regexIdx);
            if (nfa) {
                nfas.push_back(std::move(nfa));
                rawRegexes.push_back(trimmedLine);
                regexIdx++; // Increment only on success
            }
        } catch (const std::exception& e) {
            std::cerr << "Error parsing regex: " << e.what() << std::endl;
        }
    }

    if (nfas.empty()) {
        std::cerr << "No valid regexes found. Exiting." << std::endl;
        return 1;
    }

    std::vector<std::string> testStrings;
    std::vector<std::string> expectedMatches;

    if (!testFilename.empty()) {
        std::ifstream testFile(testFilename);
        if (testFile.is_open()) {
            std::string tline;
            while (std::getline(testFile, tline)) {
                size_t last = tline.find_last_not_of("\r\n");
                std::string s = (last != std::string::npos) ? tline.substr(0, last + 1) : (tline.empty() ? "" : tline);
                
                // Skip comments and truly blank lines
                if (!s.empty() && s[0] == '#') continue;
                if (s.empty() && trim(tline).empty()) continue;

                testStrings.push_back(s);
                
                // Generate expected matches using std::regex
                std::string mask = "";
                for (const auto& re_str : rawRegexes) {
                    bool match = false;
                    try {
                        std::regex re(re_str);
                        match = std::regex_match(s, re);
                    } catch (...) {}
                    mask += (match ? "1" : "0");
                }
                std::reverse(mask.begin(), mask.end());
                expectedMatches.push_back(mask);
            }
            std::cout << "Loaded " << testStrings.size() << " test strings and generated golden matches." << std::endl;
        }
    }

    std::cout << "Generated " << nfas.size() << " NFAs. Emitting Verilog..." << std::endl;

    try {
        Emitter::emit(nfas, outputDir, testStrings, expectedMatches, isPII);
        std::cout << "Pipeline complete. Verilog files emitted to '" << outputDir << "/'" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Error during Verilog emission: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
