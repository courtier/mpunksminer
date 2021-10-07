```
git clone --recursive https://github.com/courtier/mpunksminer.git
cd mpunksminer
git submodule update --recursive --remote
zig build -Drelease-fast
mv ./zig-out/bin/mpunksminer ./mpunksminer
```
