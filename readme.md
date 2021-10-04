# mpunksminer
## Warning: there are no downloads available, you will have to compile this yourself.
- supports only cpu right now, gpu will be supported soon
- ignore the "error: " prefix on console, those are not actually errors :p
- 5 MH/s on a "2,3 GHz Dual-Core Intel Core i5" cpu

## Running

Bare minimum options:

```
./mpunksminer --wallet 725aEF067EeE7B1eB7B06A7404b7b65afa04193B
```

All options:

```
	-h, --help            	Display help.
	-g, --gpu             	Use gpu, default is cpu.
	-t, --threads <NUM>   	Amount of threads.
	-w, --wallet <STR>    	ETH wallet address.
	-l, --lastmined <NUM> 	Last mined punk.
	-d, --difficulty <NUM>	Difficulty target.
	-i, --increment <NUM> 	# of hashes per cpu thread.
```

## Building

- Click the code button and download the project zip
- Download [Zig](https://ziglang.org/download/)
- Run `zig build -Drelease-fast` in the project folder
- Executable will be under zig-out/bin/

## TODO

- Add GPU support
- Record processed nonces in DB
- Add option to set the starting nonce
- Use 64 bit integers in some places, might give some performance boost, difficulty target is <64 bits
- 2^88 nonces possible
