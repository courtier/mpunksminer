# mpunksminer
## Warning: there are no downloads available, you will have to compile this yourself.
## Warning 2: this miner does not check if the nonce produces one of the OG punks, you must do this yourself before minting!
- cpu and gpu support
- ignore the "error: " prefix on console, those are not actually errors :p
- 5 MH/s on a "2,3 GHz Dual-Core Intel Core i5" cpu, 20 MH/s on a "Intel Iris Plus Graphics 640 1536 MB" gpu

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

- Download [Zig](https://ziglang.org/download/)
- Run the commands in [commands.md](https://github.com/courtier/mpunksminer/blob/master/commands.md)

## TODO

- Multiple devices at once
- Record processed nonces in DB
- Add option to set the starting nonce
