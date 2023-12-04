# Docker

Docker version used: **20.10.12**
This docker builds all dependencies and prepares an environment to run the experiments.

### Build

To build the container, first, download the following files from the artifact of the paper and extract in this folder:

```sh
unzip polybench-c-4.2.1-plus-contract-3d.zip -d polybench-c-4.2.1-plus-contract-3d
unzip llvm-packing-v0.5.zip -d llvm-packing-v0.5
unzip packing-scripts.zip -d packing-scripts
```

Then, build the image:

```sh
docker build -t packing-artifact .
```
This image consumes around 20 GB to build, but the final image has around 4 GB.

### Run

To run it:

```sh
docker run -it packing-artifact bash
```

To run it and to be able to use perf:

```sh
# install perf in the host
sudo apt-get install linux-tools-common linux-tools-generic linux-tools-`uname -r`

# enable perf to run in host
sudo sh -c 'echo 1 > /proc/sys/kernel/perf_event_paranoid'
# you can test if it works by running 
# perf stat ls

docker run -it --privileged packing-artifact bash
```
