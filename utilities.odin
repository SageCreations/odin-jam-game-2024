package main


add_health :: proc(player: ^Player) {
    if player.health < 100 {
        if player.health + 50 >= 100 {
            player.health = 100
        } else {
            player.health += 50
        }
    }
}

// returns true if player died, always asign isGameOver to this function to automaticaly determin if gameover in runtime
lose_health :: proc(player: ^Player) -> bool {
    player.health -= 20
    if player.health > 0 {
        return false
    } else {
        return true
    }
}

add_attack :: proc(player: ^Player) {
    player.attack += 20
}

