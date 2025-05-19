#!/bin/bash

# tex2pdf -i 'E=mc^2' -o outfile_from_input -d tests/out -v
# tex2pdf -i 'E=mc^2' -s 12 -o outfile_from_input_s12 -d tests/out -v
# tex2pdf -i 'E=mc^2' -s 36 -o outfile_from_input_s36 -d tests/out -v

# tex2pdf -f tests/testfile1.txt -d tests/outtest1 -o outimg1 -s 12 -v
# tex2pdf -f tests/testfile2.txt -d tests/outtest2 -o outimg2 -s 12 -v
# tex2pdf -f tests/testfile3.txt -d tests/outtest3 -o outimg3 -s 12 -v
tex2pdf -f tests/testfile4.txt -d tests/outtest4 -o outimg4 -s 12 -v
tex2pdf -f tests/testfile5.txt -d tests/outtest5 -o outimg5 -s 12 -v
