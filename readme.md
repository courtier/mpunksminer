# mpunksminer

- cpu support only right now, gpu coming soon
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
	-w, --wallet <STR>    	ETH wallet address without the "0x" prefix
	-l, --lastmined <NUM> 	Last mined punk.
	-d, --difficulty <NUM>	Difficulty target.
	-i, --increment <NUM> 	# of hashes per cpu thread.
```

## Building

- Download Zig
- Clone the project
- Run `zig build -Drelease-fast` in the project folder
- Executable will be under zig-out/bin/

## TODO

- Add GPU support
- Record processed nonces in DB
- 2^88 nonces possible
