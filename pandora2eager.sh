#!/usr/bin/env bash
VERSION="0.3.0"
TEMP=`getopt -q -o hf:rv --long help,file_type:,rename,version -n 'pandora2eager.sh' -- "$@"`
eval set -- "$TEMP"

image_path="/mnt/archgen/tools/pandora2eager/${VERSION}"

function Helptext {
  echo "
Usage: pandora2eager.sh [OPTIONS] /path/to/input_seq_IDs_file.txt

Options:
	-f/--file_type	Specify the file type of the input files. Accepted values are: 'bam', 'fastq_pathogens'.
			Note: if this flag is not provided, raw fastq will be used to generate the table
	-r/--rename	Changes all dots (.) in the Library_ID field of the output to underscores (_).
			Some tools used in nf-core/eager will strip everything after the first dot (.)
			from the name of the input file, which can cause naming conflicts in rare cases.
	-d/--debug	Activate debug mode, it produces a file called: 'Debug_table.txt'.
	-h/--help	Show usage information.
	-v/--version	Show version information.

"
}

## Default parameter values
rename=''
file_type=''

while true ; do
  case "$1" in
    --) if [[ $2 == '' ]]; then 
          echo -e "No Input file given.\n" ; Helptext ; exit 1
        else
          fn1=$2 ; shift 2; break
        fi ;;
    -h|--help) Helptext; exit 0 ;;
    -r|--rename) rename="-r"; shift 1;;
    -v|--version) echo "Version: ${VERSION}"; exit 0;;
    -f|--file_type) file_type="-f $2"; shift 2;;
    *) echo -e "No Input file given.\n"; Helptext; exit 1;;
  esac
done

## Infer path to the input file for mounting to container
input_path=$(dirname $(readlink -f ${fn1}))
input_fn=$(basename ${fn1})
mount_arg="${input_path}:/data"

singularity run --bind ${mount_arg} ${image_path}/pandora2eager.sif /data/${input_fn} ${rename} ${file_type}
