# pandora2eager
Gather information from Pandora and format it for use with [nf-core/eager](https://nf-co.re/eager).

# Quickstart

To run `pandora2eager.R` you will need an input file containing a list of Pandora sequencing IDs you
wish to include in your eager run. An example file with 5 sequencing IDs can be seen below.
```bash
$ cat input_seq_IDs_file.txt
ABC001.A0101.TF1.1
ABC001.A0101.SG1.1
ABC001.A0101.SG1.2
ABC001.A0102.TF1.1
ABC002.A0101.TF1.1
```

> ⚠️ These IDs are made-up and do not correspond to any valid entries in Pandora.

## Running the pandora2eager Singularity container

At EVA, a container is available that takes care of all dependencies needed for running `pandora2eager.R`.
You will find all past and current versions of the container and a required wrapper script for using it 
at `/mnt/archgen/tools/pandora2eager/`. Usage information for the wrapper script `pandora2eager.sh` is 
provided below:

```

Usage: pandora2eager.sh [OPTIONS] /path/to/input_seq_IDs_file.txt

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

```

When using the container, there is no need to provide a credentials file, as those are already included in the container.

## Running without a container
`pandora2eager.R` uses the `sidora.core` R package. You can find installation instructions for `sidora.core`
[here](https://github.com/sidora-tools/sidora.core). 

Accessing Pandora requires the correct `.credentials`. Contact Stephan Schiffels, James Fellows Yates, 
or Clemens Schmid to obtain them. You also have to be in the institute's subnet.

You can get usage information and a descripition of optional arguments by running `pandora2eager.R`
without specifying any arguments.
```
Usage: ./exec/pandora2eager.R [options] /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials


Options:
        -h, --help
                Show this help message and exit

        -r, --rename
                Changes all dots (.) in the Library_ID field of the output to underscores (_).
                        Some tools used in nf-core/eager will strip everything after the first dot (.)
                        from the name of the input file, which can cause naming conflicts in rare cases.


        -d, --debug
                Activate debug mode, it produces a file called: Debug_table.txt

        -f FILE_TYPE, --file_type=FILE_TYPE
                Specify the file type of the input files. Accepted values are: "bam", "fastq_pathogens". 
                        Note: if this flag is not provided, raw fastq will be used to generate the table

        -s, --add_ss_suffix
                Adds the suffix '_ss' to the Sample_ID and Library_ID field of the output for single-stranded libraries.

```



You can then run `pandora2eager.R` as shown below:
```bash
Rscript pandora2eager.R /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials
```

Including `-r` or `--rename` at the end of your command will change all dots in the 
Library_ID field of the output to underscores.

By default pandora2eager.R will output the raw fastq files. However, you can change this behaviour by adding the `-f` 
or `--file_type` flag and specifying the allowed options: `bam` or `fastq_pathogens`.
The `bam` mode will produce a table containing as input for eager the ouput BAM file from the Autorun pipelines for Human.
The `fastq_pathogens` mode will produce a table containing as input for eager the output fastq containing mapped reads to
the multi-FASTA reference from the Pathogen prescreening pipelines. 

# Building the pandora2eager Singularity container
`p2e_singularity.def` contains build instructions for a singularity image containing all the 
dependencies for running `pandora2eager.R` installed. To build this container you can use the
following instructions. You will need to provide a valid `.credentials` file yourself.

## Linux
First use `git clone` to download this repository, then `cd` into the repository directory.
Copy your valid `.credentials` file into the repository directory and run
```bash
singularity build pandora2eager.sif p2e_singularity.def
```

## OSX
First use `git clone` to download this repository, then `cd` into the repository directory.</br>
Copy your valid `.credentials` file into the repository directory.</br>
With docker installed, run:
```bash
bash build_singularity_with_docker.sh
```
