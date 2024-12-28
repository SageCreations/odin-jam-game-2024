package main


add_health :: proc (player: ^Player) {
    if player.health < 100 {
        if player.health + 50 >= 100 {
            player.health = 100
        } else {
            player.health += 50
        }
    }
}