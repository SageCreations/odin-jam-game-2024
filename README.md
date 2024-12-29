If no binary/executable is supplied then you can use one of the build_release scripts for your specific platform.

I wasn't able to build on Windows personally, no idea what was going on there, LNK1169 error.

the game will not run if the .bin is not in this structure:
```
<game folder>
|- data/
|    |- data.json
|- resources/
|    |- sounds/
|- escape.bin
```

If for whatever reason there is no data.json within the folder, the game should automatically generate one but 
needs the data directory in place todo so.