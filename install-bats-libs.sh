mkdir -p tests/libs

cd tests/libs

git submodule add git@github.com:bats-core/bats-core bats
git submodule add git@github.com:bats-core/bats-support bats-support
git submodule add git@github.com:bats-core/bats-assert bats-assert

# try the following three steps
git submodule update --init --recursive
git submodule update --recursive --remote
git pull --recurse-submodules