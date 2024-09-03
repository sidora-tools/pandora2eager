#!/bin/bash

echo "
Usage: pandora2eager.sif /path/to/input_seq_IDs_file.txt [-r/--rename].

Options:
	-f/--file_type		Specify the file type of the input files. Accepted values are: 'bam', 'fastq_pathogens'.
				Note: if this flag is not provided, raw fastq will be used to generate the table
	-r/--rename		Changes all dots (.) in the Library_ID field of the output to underscores (_).
				Some tools used in nf-core/eager will strip everything after the first dot (.)
				from the name of the input file, which can cause naming conflicts in rare cases.
	-d/--debug		Activate debug mode, it produces a file called: 'Debug_table.txt'.
	-s/--add_ss_suffix	Adds the suffix '_ss' to the Sample_ID and Library_ID field of the output for single-stranded libraries.
	-h/--help		Show usage information.
	-v/--version		Show version information.

"