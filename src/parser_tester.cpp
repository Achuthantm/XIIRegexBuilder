#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>
#include "lexer.h"
#include "parser.h"
#include "nfa.h"

std::string trim(const std::string &str)
{
    size_t first = str.find_first_not_of(" \t\r\n");
    if (first == std::string::npos)
        return "";
    size_t last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, (last - first + 1));
}

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
        std::cerr << "Usage: " << argv[0] << " <regex_file> [test_strings_file]" << std::endl;
        return 1;
    }

    std::string regexFilename = argv[1];
    std::ifstream regexFile(regexFilename);
    if (!regexFile.is_open())
    {
        std::cerr << "Failed to open " << regexFilename << std::endl;
        return 1;
    }

    // Optional: Test strings for validation
    std::string testFilename = (argc > 2) ? argv[2] : "";
    std::vector<std::string> testStrings;
    if (!testFilename.empty())
    {
        std::ifstream testFile(testFilename);
        if (testFile.is_open())
        {
            std::string testLine;
            while (std::getline(testFile, testLine))
            {
                std::string trimmed = trim(testLine);
                if (trimmed.empty() || trimmed[0] == '#')
                    continue;
                testStrings.push_back(trimmed);
            }
        }
    }

    std::string line;
    int lineNum = 0;
    int regexIdx = 0;
    std::vector<std::unique_ptr<NFA>> nfas;
    std::vector<std::string> originalRegexes;

    // Core Pipeline: Regex -> Tokens -> AST -> NFA
    while (std::getline(regexFile, line))
    {
        lineNum++;
        std::string trimmedLine = trim(line);
        if (trimmedLine.empty() || trimmedLine[0] == '#')
            continue;

        originalRegexes.push_back(trimmedLine);
        Lexer lexer(trimmedLine, lineNum);
        try
        {
            std::vector<Token> tokens = lexer.tokenize();
            Parser parser(tokens);
            auto ast = parser.parse();

            // Glushkov NFA construction
            auto nfa = NFABuilder::build(ast.get(), regexIdx++);
            if (nfa)
            {
                nfas.push_back(std::move(nfa));
            }
        }
        catch (const std::exception &e)
        {
            std::cerr << "Error processing regex '" << trimmedLine << "': " << e.what() << std::endl;
        }
    }

    std::cout << "Successfully built " << nfas.size() << " NFAs." << std::endl;

    // Optional Validation: NFA Simulation
    if (!testStrings.empty())
    {
        std::cout << "\n--- NFA Simulation Results ---" << std::endl;
        for (const auto &testStr : testStrings)
        {
            std::cout << "String: \"" << testStr << "\"" << std::endl;
            for (size_t i = 0; i < nfas.size(); ++i)
            {
                bool matches = nfas[i]->simulate(testStr);
                std::cout << "  Regex [" << i << "] (" << originalRegexes[i] << "): "
                          << (matches ? "MATCH" : "NO MATCH") << std::endl;
            }
            std::cout << std::endl;
        }
    }

    // Future: Stage 3 -  Verilog Emitter
    // if (!nfas.empty()) {
    //     Emitter emitter(nfas);
    //     emitter.emit("output/");
    // }

    return 0;
}
