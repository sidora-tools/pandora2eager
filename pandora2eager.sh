#!/usr/bin/env bash
VERSION="0.2.1-beta"
TEMP=`getopt -q -o hrv --long help,rename,version -n 'pandora2eager.sh' -- "$@"`
eval set -- "$TEMP"

image_path="/mnt/archgen/tools/pandora2eager/${VERSION}"

function Helptext {
  echo "
Usage: pandora2eager.sh [OPTIONS] /path/to/input_seq_IDs_file.txt

Options:
	-r/--rename	Changes all dots (.) in the Library_ID field of the output to underscores (_).
			Some tools used in nf-core/eager will strip everything after the first dot (.)
			from the name of the input file, which can cause naming conflicts in rare cases.
	-h/--help	Show usage information.
	-v/--version	Show version information.

"
}

## Default parameter values
rename=''

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
    *) echo -e "No Input file given.\n"; Helptext; exit 1;;
  esac
done

## Infer path to the input file for mounting to container
input_path=$(dirname $(readlink -f ${fn1}))
input_fn=$(basename ${fn1})
mount_arg="${input_path}:/data"

singularity run --bind ${mount_arg} ${image_path}/pandora2eager.sif /data/${input_fn} ${rename}
