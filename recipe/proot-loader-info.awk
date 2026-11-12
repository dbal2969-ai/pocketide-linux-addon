function hex_value(text, position, digit, result) {
    sub(/^0[xX]/, "", text)
    result = 0
    for (position = 1; position <= length(text); position++) {
        digit = index("0123456789abcdef", tolower(substr(text, position, 1))) - 1
        if (digit < 0) return -1
        result = result * 16 + digit
    }
    return result
}

$NF == "_start" {
    start_address = hex_value($2)
    have_start = 1
}

$NF == "pokedata_workaround" {
    workaround_address = hex_value($2)
    have_workaround = 1
}

END {
    if (!have_start || !have_workaround || start_address < 0 || workaround_address < 0) {
        print "Could not find valid loader symbols" > "/dev/stderr"
        exit 1
    }
    print "#include <unistd.h>"
    print "const ssize_t offset_to_pokedata_workaround=" (workaround_address - start_address) ";"
}