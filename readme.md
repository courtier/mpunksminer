# mpunksminer

- cpu support only right now, gpu coming soon
- ignore the "error: " prefix on console :p

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
	-w, --wallet <NUM>    	ETH wallet address without the "0x" prefix
	-l, --lastmined <NUM> 	Last mined punk.
	-d, --difficulty <NUM>	Difficulty target.
	-i, --increment <NUM> 	# of hashes per cpu thread.
```
