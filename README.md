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
	-r/--rename	Changes all dots (.) in the Library_ID field of the output to underscores (_).
			Some tools used in nf-core/eager will strip everything after the first dot (.)
			from the name of the input file, which can cause naming conflicts in rare cases.
	-h/--help	Usage information.
	-v/--version	Version information.


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

usage: Rscript query_pandora_for_data.R /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials [-r/--rename].

Options:
	 -r/--rename	Changes all dots (.) in the Library_ID field of the output to underscores (_).
			Some tools used in nf-core/eager will strip everything after the first dot (.)
			from the name of the input file, which can cause naming conflicts in rare cases.

```



You can then run `pandora2eager.R` as shown below:
```bash
Rscript pandora2eager.R /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials
```

Including `-r` or `--rename` at the end of your command will change all dots in the 
Library_ID field of the output to underscores.

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
