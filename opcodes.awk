BEGIN {
    count = 0
    opcode_count = 0;
    opcode_index = -1
    RS = ORS = "\r\n";

    printf("uint16_t vm1_opcode_addr = 0xfe;\n");
}

/ opc_[a-z]+:/ {
    addr[count]=$2;
    label[count]=substr($3, 1, length($3) - 1);
    #mask[count]=substr($4, 1, length($4) - 1);
    #printf("0x%s %s\n", addr[count], label[count]);
    count += 1;
}

#/ vm1_opcode:/ {
#    printf("uint16_t vm1_opcode_addr = 0x%s;\n", $2);
#}

/ vm1_exec:/ {
    printf("uint16_t vm1_exec_addr = 0x%s;\n", $2);
}

/ rxdrv_csr:/ {
    printf("uint16_t rxdrv_csr_addr = 0x%s;\n", $2);
}


/ test_opcode_table:/ {
    opcode_index = 0;
}

/.dw [0-7]+q/ {
    if (opcode_index >= 0) {
        #printf("[%s] %s\n", $8, $0);
        if ($8 == "TERMINAT") {
            opcode_index = -1;
        }
        else {
            opcode_code[opcode_index] = "0" substr($6, 1, length($6) - 1);
            opcode_name[opcode_index] = tolower($8);
            opcode_mask[opcode_index] = $9 == "" ? "0177777" : $9;
            #printf("opcode: %d %s %s mask=%s\n", opcode_index, opcode_code[opcode_index], opcode_name[opcode_index], opcode_mask[opcode_index]);
            opcode_index += 1;
            opcode_count += 1;
        }
    }
}

/ regfile:/ {
    printf("uint16_t vm1_regfile_addr = 0x%s;\n", $2);
}

#/r[0-7]:\s*.dw/ {
#    a = $2;
#    num = substr($5, 2, length($5) - 1);
#    printf("register r%s @%s\n", num, a);
#}

END {
    printf("#pragma once\n");
    printf("uint16_t opc_addrs[%d] = {\n    ", count);
    for (i = 0; i < count; ++i) {
        printf("0x%s,", addr[i]);
    }
    printf("\n    };\n");

    printf("const char * opc_labels[%d] = {\n    ", count);
    for (i = 0; i < count; ++i) {
        printf("\"%s\",", label[i]);
    }
    printf("\n    };\n");

    printf("uint16_t opc_codes[%d] = {\n    ", opcode_count);
    for (i = 0; i < opcode_count; ++i) {
        printf("%s,", opcode_code[i]);
    }
    printf("};\n");

    printf("uint16_t opc_masks[%d] = {\n    ", opcode_count);
    for (i = 0; i < opcode_count; ++i) {
        printf("%s,", opcode_mask[i]);
    }
    printf("};\n");

    printf("const char * opc_names[%d] = {\n    ", opcode_count);
    for (i = 0; i < opcode_count; ++i) {
        printf("\"%s\",", opcode_name[i]);
    }
    printf("};\n");
}
