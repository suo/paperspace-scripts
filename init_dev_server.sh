#!/bin/bash
set -euxo pipefail

# install et
sudo apt-get install --yes software-properties-common
sudo add-apt-repository --yes ppa:jgmath2000/et
sudo apt-get update
sudo apt-get install --yes et
sudo systemctl status et

# install ccache
tmp_dir=$(mktemp --directory)
pushd "$tmp_dir"

wget "https://github.com/mozilla/sccache/releases/download/v0.3.0/sccache-v0.3.0-x86_64-unknown-linux-musl.tar.gz"
tar --extract --file "sccache-v0.3.0-x86_64-unknown-linux-musl.tar.gz" --strip-components=1

chmod +x sccache
sudo mv sccache /usr/local/bin

# configure sccache for distributed build
mkdir -p ~/.config/sccache
cat << EOF > ~/.config/sccache/config
[dist]
# The URL used to connect to the scheduler (should use https, given an ideal
# setup of a HTTPS server in front of the scheduler)
scheduler_url = "http://10.225.63.3:10600"
# Used for mapping local toolchains to remote cross-compile toolchains. Empty in
# this example where the client and build server are both Linux.
toolchains = []
# Size of the local toolchain cache, in bytes (5GB here, 10GB if unspecified).
toolchain_cache_size = 5368709120

[dist.auth]
type = "token"
# This should match the client_auth section of the scheduler config.
token = "my client token"
EOF

cat << EOF >> ~/.bashrc

# Use sccache with CMake
export CMAKE_C_COMPILER_LAUNCHER=sccache
export CMAKE_CXX_COMPILER_LAUNCHER=sccache
# Set a higher MAX_JOBS. The default setting only sets parallelism based on the
# number of cores locally, but with sccache-dist we have access to many more.
MAX_JOBS=48
EOF

popd
rm -rf "$tmp_dir/*"

# install latest compiler
# Update clang-related binaries to point to the right version.
function install_clang {
    local version=$1
    local priority=$2
    curl https://apt.llvm.org/llvm.sh | sudo bash -s -- $1 all


    sudo update-alternatives \
        --verbose \
        --install /usr/bin/llvm-config       llvm-config      /usr/bin/llvm-config-${version} ${priority} \
        --slave   /usr/bin/llvm-ar           llvm-ar          /usr/bin/llvm-ar-${version} \
        --slave   /usr/bin/llvm-as           llvm-as          /usr/bin/llvm-as-${version} \
        --slave   /usr/bin/llvm-bcanalyzer   llvm-bcanalyzer  /usr/bin/llvm-bcanalyzer-${version} \
        --slave   /usr/bin/llvm-cov          llvm-cov         /usr/bin/llvm-cov-${version} \
        --slave   /usr/bin/llvm-diff         llvm-diff        /usr/bin/llvm-diff-${version} \
        --slave   /usr/bin/llvm-dis          llvm-dis         /usr/bin/llvm-dis-${version} \
        --slave   /usr/bin/llvm-dwarfdump    llvm-dwarfdump   /usr/bin/llvm-dwarfdump-${version} \
        --slave   /usr/bin/llvm-extract      llvm-extract     /usr/bin/llvm-extract-${version} \
        --slave   /usr/bin/llvm-link         llvm-link        /usr/bin/llvm-link-${version} \
        --slave   /usr/bin/llvm-mc           llvm-mc          /usr/bin/llvm-mc-${version} \
        --slave   /usr/bin/llvm-nm           llvm-nm          /usr/bin/llvm-nm-${version} \
        --slave   /usr/bin/llvm-objdump      llvm-objdump     /usr/bin/llvm-objdump-${version} \
        --slave   /usr/bin/llvm-ranlib       llvm-ranlib      /usr/bin/llvm-ranlib-${version} \
        --slave   /usr/bin/llvm-readobj      llvm-readobj     /usr/bin/llvm-readobj-${version} \
        --slave   /usr/bin/llvm-rtdyld       llvm-rtdyld      /usr/bin/llvm-rtdyld-${version} \
        --slave   /usr/bin/llvm-size         llvm-size        /usr/bin/llvm-size-${version} \
        --slave   /usr/bin/llvm-stress       llvm-stress      /usr/bin/llvm-stress-${version} \
        --slave   /usr/bin/llvm-symbolizer   llvm-symbolizer  /usr/bin/llvm-symbolizer-${version} \
        --slave   /usr/bin/llvm-tblgen       llvm-tblgen      /usr/bin/llvm-tblgen-${version} \
        --slave   /usr/bin/llvm-objcopy      llvm-objcopy     /usr/bin/llvm-objcopy-${version} \
        --slave   /usr/bin/llvm-strip	     llvm-strip       /usr/bin/llvm-strip-${version}

    sudo update-alternatives \
        --install /usr/bin/clang                 clang                 /usr/bin/clang-${version} ${priority} \
        --slave   /usr/bin/clang++               clang++               /usr/bin/clang++-${version}  \
        --slave   /usr/bin/asan_symbolize        asan_symbolize        /usr/bin/asan_symbolize-${version} \
        --slave   /usr/bin/c-index-test          c-index-test          /usr/bin/c-index-test-${version} \
        --slave   /usr/bin/clang-check           clang-check           /usr/bin/clang-check-${version} \
        --slave   /usr/bin/clang-cl              clang-cl              /usr/bin/clang-cl-${version} \
        --slave   /usr/bin/clang-cpp             clang-cpp             /usr/bin/clang-cpp-${version} \
        --slave   /usr/bin/clang-format          clang-format          /usr/bin/clang-format-${version} \
        --slave   /usr/bin/clang-format-diff     clang-format-diff     /usr/bin/clang-format-diff-${version} \
        --slave   /usr/bin/clang-include-fixer   clang-include-fixer   /usr/bin/clang-include-fixer-${version} \
        --slave   /usr/bin/clang-offload-bundler clang-offload-bundler /usr/bin/clang-offload-bundler-${version} \
        --slave   /usr/bin/clang-query           clang-query           /usr/bin/clang-query-${version} \
        --slave   /usr/bin/clang-rename          clang-rename          /usr/bin/clang-rename-${version} \
        --slave   /usr/bin/clang-reorder-fields  clang-reorder-fields  /usr/bin/clang-reorder-fields-${version} \
        --slave   /usr/bin/clang-tidy            clang-tidy            /usr/bin/clang-tidy-${version} \
        --slave   /usr/bin/lldb                  lldb                  /usr/bin/lldb-${version} \
        --slave   /usr/bin/lldb-server           lldb-server           /usr/bin/lldb-server-${version}

}
install_clang 14 100

# also update the generic cc/c++ 
sudo update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100
sudo update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 100

# install conda
mkdir ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm ~/miniconda3/miniconda.sh

# configure conda
eval "$(~/miniconda3/bin/conda shell.bash hook)"  # activate conda in this shell
conda init
conda config --set auto_activate_base false

conda create --yes --name dev python==3.8
conda activate dev
conda install --yes astunparse numpy ninja pyyaml setuptools cmake cffi typing_extensions future six requests dataclasses mkl mkl-include

cat << EOF >> ~/.bashrc

# initialize a default conda environment with all the PyTorch dependencies
conda activate dev
EOF

# set up pytorch
mkdir ~/code
pushd ~/code
git clone https://github.com/pytorch/pytorch.git
pushd pytorch
git submodule update --init --recursive --jobs 0
popd; popd

# TODO install magmda-cuda
# TODO install cuda

