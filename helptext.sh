#!/bin/bash

echo "
Usage: pandora2eager.sif /path/to/input_seq_IDs_file.txt [-r/--rename].

Options:
	-r/--rename	Changes all dots (.) in the Library_ID field of the output to underscores (_).
			Some tools used in nf-core/eager will strip everything after the first dot (.)
			from the name of the input file, which can cause naming conflicts in rare cases.

"