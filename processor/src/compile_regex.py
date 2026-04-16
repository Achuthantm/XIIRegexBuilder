import os

# Glushkov Construction for Regex CPU


class Node:
    def __init__(self, type):
        self.type = type
        self.nullable = False
        self.first = set()
        self.last = set()
        self.pos = None
        self.char = None


def get_positions(node):
    if node.type == "lit":
        return {node.pos: node.char}
    res = {}
    if hasattr(node, "left"):
        res.update(get_positions(node.left))
    if hasattr(node, "right"):
        res.update(get_positions(node.right))
    if hasattr(node, "child"):
        res.update(get_positions(node.child))
    return res


def compute_follow(node, follow):
    if node.type == "cat":
        compute_follow(node.left, follow)
        compute_follow(node.right, follow)
        for i in node.left.last:
            follow[i] |= node.right.first
    elif node.type == "or":
        compute_follow(node.left, follow)
        compute_follow(node.right, follow)
    elif node.type == "star" or node.type == "plus":
        compute_follow(node.child, follow)
        for i in node.child.last:
            follow[i] |= node.child.first
    elif node.type == "quest":
        compute_follow(node.child, follow)


def parse_regex(pattern):
    tokens = list(pattern[::-1])

    def parse_expr():
        node = parse_cat()
        while tokens and tokens[-1] == "|":
            tokens.pop()
            right = parse_cat()
            new_node = Node("or")
            new_node.left = node
            new_node.right = right
            new_node.nullable = node.nullable or right.nullable
            new_node.first = node.first | right.first
            new_node.last = node.last | right.last
            node = new_node
        return node

    def parse_cat():
        node = parse_unary()
        while tokens and tokens[-1] not in ")|":
            right = parse_unary()
            new_node = Node("cat")
            new_node.left = node
            new_node.right = right
            new_node.nullable = node.nullable and right.nullable
            new_node.first = node.first | (right.first if node.nullable else set())
            new_node.last = right.last | (node.last if right.nullable else set())
            node = new_node
        return node

    def parse_unary():
        node = parse_primary()
        while tokens and tokens[-1] in "*+?":
            op = tokens.pop()
            new_node = Node("star" if op == "*" else ("plus" if op == "+" else "quest"))
            new_node.child = node
            if op == "*":
                new_node.nullable = True
                new_node.first = node.first
                new_node.last = node.last
            elif op == "+":
                new_node.nullable = node.nullable
                new_node.first = node.first
                new_node.last = node.last
            else:  # ?
                new_node.nullable = True
                new_node.first = node.first
                new_node.last = node.last
            node = new_node
        return node

    pos_counter = [1]

    def parse_primary():
        c = tokens.pop()
        if c == "(":
            node = parse_expr()
            if tokens:
                tokens.pop()  # )
            return node
        else:
            node = Node("lit")
            node.char = c
            node.pos = pos_counter[0]
            pos_counter[0] += 1
            node.nullable = False
            node.first = {node.pos}
            node.last = {node.pos}
            return node

    return parse_expr()


def generate_rasm(root, match_id, base_pc):
    positions = get_positions(root)
    follow = {i: set() for i in positions}
    compute_follow(root, follow)

    # Map Glushkov positions to absolute PCs
    pc_map = {0: base_pc}  # Start state
    for i in range(1, len(positions) + 1):
        pc_map[i] = base_pc + i

    match_state_pc = base_pc + len(positions) + 1
    next_free_pc = match_state_pc + 1

    rasm = []

    # MATCH State (PC: match_state_pc)
    # The MATCH instruction in your HW: char=0, term=1, mid=match_id
    rasm.append(f"{match_state_pc}: MATCH({match_id})")

    # Start chain (Position 0)
    start_targets = list(root.first)
    if root.nullable:
        # If the regex matches empty string, the start state should point to match
        start_targets.append(match_state_pc)

    if not start_targets:
        rasm.append(f"{pc_map[0]}: MATCH({match_id})")
    else:

        def write_split_chain(targets, start_pc, free_pc):
            if not targets:
                return [], free_pc
            if len(targets) == 1:
                target_pc = pc_map[targets[0]] if targets[0] in pc_map else targets[0]
                return [f"{start_pc}: JMP({target_pc})"], free_pc
            elif len(targets) == 2:
                t1 = pc_map[targets[0]] if targets[0] in pc_map else targets[0]
                t2 = pc_map[targets[1]] if targets[1] in pc_map else targets[1]
                return [f"{start_pc}: SPLIT({t1}, {t2})"], free_pc
            else:
                t1 = pc_map[targets[0]] if targets[0] in pc_map else targets[0]
                lines = [f"{start_pc}: SPLIT({t1}, {free_pc})"]
                more, last = write_split_chain(targets[1:], free_pc, free_pc + 1)
                return lines + more, last

        chain, next_free_pc = write_split_chain(start_targets, pc_map[0], next_free_pc)
        rasm.extend(chain)

    # Character positions
    for i in range(1, len(positions) + 1):
        char = positions[i]
        targets = list(follow[i])
        if i in root.last:
            # If this is a terminal position, it MUST lead to the MATCH state
            targets.append(match_state_pc)

        p_any = 1 if char == "." else 0
        p_char = f"'{char}'" if char != "." else 0

        if not targets:
            rasm.append(f"{pc_map[i]}: CHAR({p_char}, 0, 0, 0, 0, {p_any})")
        elif len(targets) == 1:
            t = pc_map[targets[0]] if targets[0] in pc_map else targets[0]
            rasm.append(f"{pc_map[i]}: CHAR({p_char}, {t}, 0, 0, 0, {p_any})")
        elif len(targets) == 2:
            t1 = pc_map[targets[0]] if targets[0] in pc_map else targets[0]
            t2 = pc_map[targets[1]] if targets[1] in pc_map else targets[1]
            rasm.append(f"{pc_map[i]}: CHAR({p_char}, {t1}, {t2}, 0, 0, {p_any})")
        else:
            chain_start = next_free_pc
            rasm.append(f"{pc_map[i]}: CHAR({p_char}, {chain_start}, 0, 0, 0, {p_any})")
            chain, next_free_pc = write_split_chain(
                targets, chain_start, next_free_pc + 1
            )
            rasm.extend(chain)

    return rasm, next_free_pc


def main():
    import sys

    input_file = sys.argv[1] if len(sys.argv) > 1 else "regex.txt"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "regexes.rasm"

    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found.")
        return
    with open(input_file, "r") as f:
        # Limit to 16 regexes max
        patterns = [l.strip() for l in f if l.strip() and not l.startswith("#")][:16]

    if not patterns:
        print("No patterns found in input file.")
        return

    # Reserve space at the beginning for the "Start Chain" (SPLITs)
    # If we have N patterns, we need N-1 SPLIT instructions.
    # We will start the actual regex logic at base_pc = N (to be safe).
    num_patterns = len(patterns)
    base_pc = num_patterns

    regex_rasm_blocks = []
    regex_start_pcs = []
    current_pc = base_pc

    for i, pat in enumerate(patterns):
        try:
            root = parse_regex(pat)
            lines, next_pc = generate_rasm(root, i, current_pc)
            regex_rasm_blocks.append((f"# Regex {i}: {pat}", lines))
            regex_start_pcs.append(current_pc)  # The start state for this regex
            current_pc = next_pc
        except Exception as e:
            print(f"Error compiling '{pat}': {e}")

    full_rasm = []

    # Generate the Start Chain at PC 0
    # PC 0: SPLIT(Regex0_Start, PC 1)
    # PC 1: SPLIT(Regex1_Start, PC 2)
    # ...
    # PC N-2: SPLIT(RegexN-2_Start, RegexN-1_Start)

    if num_patterns == 1:
        full_rasm.append(f"0: JMP({regex_start_pcs[0]})")
    else:
        for i in range(num_patterns - 1):
            target_regex_pc = regex_start_pcs[i]
            next_chain_pc = i + 1 if i < num_patterns - 2 else regex_start_pcs[i + 1]
            full_rasm.append(f"{i}: SPLIT({target_regex_pc}, {next_chain_pc})")

    full_rasm.append("")
    for header, lines in regex_rasm_blocks:
        full_rasm.append(header)
        full_rasm.extend(lines)
        full_rasm.append("")

    with open(output_file, "w") as f:
        f.write("\n".join(full_rasm))
    print(
        f"Glushkov compilation successful. Generated {current_pc} instructions for {num_patterns} patterns from {input_file} to {output_file}."
    )


if __name__ == "__main__":
    main()
