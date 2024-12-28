package main

import "core:strings"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

DATABASE_FILENAME :: "data/database.json"


Database :: struct {
    gameInit: GameData,
    storedSession: GameData,
}

Enemy :: struct {
    id: string,
    health: int,
    position: rl.Vector3
}

Player :: struct {
    health: int,
    position: rl.Vector3,
    attack: int,
}


init_data :: proc() -> Database {
    path := strings.concatenate({"./", DATABASE_FILENAME})

    default_data := Database {} // should default zero everything
    fmt.printfln("database: %v", default_data)

    json_data, err := json.marshal(default_data, {pretty = true})
    if err != nil {
        fmt.eprintfln("Unable to marshal JSON: %v", err)
        os.exit(1)
    }

    fmt.printfln("writing %s", path)
    werr := os.write_entire_file_or_err(path, json_data)
    if werr != nil {
        fmt.eprintfln("unable to write file: %v", werr)
        os.exit(1)
    }

    fmt.println("Done")
    return default_data
}

load_database_or_err :: proc() -> (Database, os.Error) {
    data, ok := os.read_entire_file_from_filename_or_err(DATABASE_FILENAME)
    if ok != nil {
        fmt.eprintfln("Failed to load the file: %v", ok)
        return Database{}, ok
    }
    fmt.println("Success in loading file!")

    db_ctx: Database
    if json.unmarshal(data, &db_ctx) == nil {
        fmt.println("Success in unmarshaling the data!")
    } else {
        fmt.eprintln("Failed to unmarshal JSON")
    }

    fmt.println("Returning db_context now...")
    return db_ctx, nil
}


save_database_or_err :: proc(ctx: Database) -> os.Error {
    json_data, err := json.marshal(ctx, {pretty = true})
    if err != nil {
        fmt.eprintfln("Unable to marshal JSON: %v", err)
        return nil
    }

    fmt.printfln("writing %s", DATABASE_FILENAME)
    werr := os.write_entire_file_or_err(DATABASE_FILENAME, json_data)
    if werr != nil {
        fmt.eprintfln("unable to write file: %v", werr)
        return werr
    }

    fmt.println("Done")
    return nil
}
