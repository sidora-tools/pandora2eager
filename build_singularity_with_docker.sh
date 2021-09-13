rm -f pandora2eager ## Remove built image if existing
docker pull tclamnidis/singularity-in-docker:3.8.1
docker run --rm --privileged -v $(pwd):/work tclamnidis/singularity-in-docker:3.8.1 build pandora2eager pandora2eager.def
