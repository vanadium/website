= yaml =
title: Croupier
layout: syncbase
toc: false
= yaml =

# Functionality

Allows users to organize and play peer-to-peer card games together.
The Syncbase schema supports general card games, and it is up to each
application to support games (e.g., Hearts, Solitaire, etc.).

## Key Behaviors
* A user (and multiple users) can restart and resume games without losing state
* A user can create and join games using the discovery API.
* A user can change their player settings in order to change their appearance
in-game.
* The game state is stored as a game log to allow different versions of the
application to communicate together.
* A user can add >1 of their devices to the game, but they are not treated as
the same player.
* Application logic (and not a central server) prevents conflicts. This reliance
means that clients must trust each other not to cheat.
* A user can watch replays of old games and share them with each other.
* Games support the ability to (locally) undo and redo due to the ease of
replaying the game log.

# Schema

## Data Types
```Go
// The GameMetadata tracks information about the game creator and status.
// Note: This is new, since the owner doesn't want other players to write to this.
type GameMetadata struct {
  type          string     // The type of the game. Can also be an enum instead of a string.
  owner         Blessing   // Game creator's Blessing string
  status        GameStatus // See below.
}

// The GameStatus informs players how to transition between game setup, play, and cleanup.
type GameStatus int
const (
  Preparing GameStatus iota
  Running
  Complete
)

// The Proposal struct is used to forge a consensus between players.
// This is important when players can make simultaneous and conflicting moves.
// Essentially, this acts as a "lock" on the game log, which is not visible to players.
type Proposal struct {
  timestamp         int     // When the proposal was created.
  command_string    string  // What ought to be run if the proposal goes through.
  player_number     int     // Original player that proposed this command.
}

// The player Settings struct contains information relevant to a user.
// This information is a mix of fixed and customizable data that is public to all players.
// The user is allowed to change their avatar, name, and color in-game.
type Settings struct {
  avatar     string     // Must point to an avatar asset bundled into the app.
  name       string     // The user's display name in-game. Usually a pseudonym.
  color      int        // An 8 digit hex-encoded integer. 0x{alpha}{red}{green}{blue}
  gameID     UUID       // Most recent game ID for this user, may be null if none or if completed.
}
```

## Organization

```
<AppGUID>/Games<GameUUID>/players/<player number>
// Tracks position of players in game
// Observing players don't write/claim a player number

Games<GameUUID>/player_settings/<Blessing> ->
// Stores collection for player <Blessing>'s settings

Games<GameUUID>/log/commands/<timestamp>-<player number>
// The command for <player number> at <timestamp>

Games<GameUUID>/log/proposals/<player number>
// the command proposal for <player number>

Games<GameUUID>Meta -> GameMetadata*

Settings<Blessing>
//Settings for the player who owns <Blessing>
```

{{# helpers.info }}
### Note
`Games<GameUUID>/log` can instead be replaced with a CRDT list. This would also allow players to write their game actions without conflicting with each other.
{{/ helpers.info }}

# Syncing and permissions

There are 3 types of collections to be shared. There are 2 types of game collections, and 1 type of settings collection.

The relevant syncgroups are
### Games<GameUUID>
Every player needs to participate in setting up the game and then playing it.
Game creator has Admin and R/W access.
All players initially have R/W access.
Observing or overflow players will become R-only on Game Start (unless they are the game creator).
Those who haven't joined will have no access after Game Start
Theoretical: If the game is shared with them, then they get R-only access.
### Games<GameUUID>Met
Only the game creator needs to write to the metadata section, since it determines the game type and game status. All players must be able to read this data.
Game creator has Admin and R/W access.
All other players have R access.
### Settings<Blessing>
Everybody should be able to read this section, but only the person who owns this should be able to write to it.
The Player who owns <Blessing> has Admin and R/W access
All other players only have R access.

Each game advertisement will advertise the collection "Games<GameUUID>" and associate it with the other collections, "Games<GameUUID>Meta" and the creator's "Settings<Blessing>".

When joining a game, players will also write down the "Settings<Blessing>" collection ID into the game state. This will allow other players to see their presence in the game.

# Conflicts
As aforementioned, conflicts are disallowed by the game's logic, so this isn't handled in the traditional Syncbase sense. In the case where the game structure allows players to make simultaneous but contradictory moves, the game's logic will shift them into using the "proposal system". Once all players agree on a proposal, that move and that move alone is executed.

The game setup phase has players that are part of the game but haven't "sat" down as well as players that have selected their player number. Since players cannot select the same "seat", we can have Syncbase handle the seating conflicts. The app will be able to determine where players are sitting from that. It will also know which players have not sat down by checking either the list of syncgroup members or the set of player setting collections written to the game.