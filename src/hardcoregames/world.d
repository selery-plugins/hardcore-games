module hardcoregames.world;

import std.algorithm : canFind, min;
import std.datetime : dur;
import std.string : startsWith, join;

import selery.about;
import selery.command;
import selery.event.world;
import selery.lang : Translation, Translatable;
import selery.log : Format;
import selery.node.plugin;
import selery.player;
import selery.world;

enum {

	lobby = 0,
	invincibility,
	game,
	deathmatch,
	aftermath

}

class Tribute {

	Player player;

	uint[] team; // player.id

	size_t kills = 0;

	public this(Player player) {
		this.player = player;
	}

}
	
private alias Countdown = Ranged!(uint, 1, uint.max);

class HardcoreGamesWorld : World {

	private const HardcoreGamesSettings settings;

	private Tribute[uint] tributes;

	private tick_t lobbyCountdown;
	private tick_t invincibilityCountdown;
	private tick_t gameCountdown;

	public this(HardcoreGamesSettings settings=HardcoreGamesSettings.init) {
		super();
		assert(settings.requiredPlayers >= 2);
		this.settings = settings;
		this.lobbyCountdown = settings.lobbyDuration;
		this.invincibilityCountdown = settings.invincibilityDuration;
		this.gameCountdown = settings.gameDuration;
		//this.registerPermission(Gamemode.spectator, "hardcoregames:spectate");
	}

	// TASKS

	@state(lobby) @task(dur!"seconds"(1)) void lobbyTask() {
		if(--this.lobbyCountdown == 0) {
			if(this.tributes.length >= this.settings.requiredPlayers) {
				this.updateState(invincibility);
				//TODO teleport to spawn point
				//foreach(player ; this.players) player.teleport(this.spawnPoint, 0f, 0f, 0f);
			} else {
				this.broadcast(Format.yellow, Translation(Translatable("countdown.lobby.failed"), this.settings.requiredPlayers));
				this.lobbyCountdown = this.settings.lobbyDuration + 1;
				this.lobbyTask(); // updates the message
			}
		} else {
			enum t = [["", "second", "seconds"], ["minute", "minute.second", "minute.seconds"], ["minutes", "minutes.second", "minutes.seconds"]];
			immutable minutes = this.lobbyCountdown / 60;
			immutable seconds = this.lobbyCountdown % 60;
			this.broadcastTip(Translation(Translatable("countdown.game." ~ t[min(minutes, 2)][min(seconds, 2)]), minutes, seconds));
		}
	}

	@state(invincibility) @task(dur!"seconds"(1)) invincibilityTask() {
		if(--this.invincibilityCountdown == 0) {
			this.updateState(game);
		} else {
			//TODO broadcast as a tip
			this.broadcast(Translation(Translatable("countdown.invincibility.second" ~ (this.invincibilityCountdown != 1) ? "s" : ""), this.invincibilityCountdown));
		}
	}

	@state(game) @task(dur!"seconds"(1)) gameTask() {
		if(--this.gameCountdown == 0) {
			this.updateState(deathmatch);
			//TODO teleport to spawn
		} else {
			//TODO broadcast if less than a minute
		}
	}

	@state(deathmatch) @task(dur!"seconds"(5)) deathmatchTask() {
		//TODO give bad effects
	}

	@state(aftermath) @task(dur!"seconds"(10)) afterTask() {
		//TODO transfer to main world or kick if this is the main world
	}

	// COMMANDS

	@state(lobby) @command("status", Translatable("commands.status.description")) commandStatus0(WorldCommandSender sender) {
		final switch(this.currentState) {
			case lobby:
				sender.sendMessage(Translation(Translatable("status.lobby.online"), this.tributes.length, this.settings.requiredPlayers));
				break;
			case invincibility:
			case game:
			case deathmatch:
				sender.sendMessage(Translation(Translatable("status.game.tributes"), this.tributes.length));
				break;
			case aftermath:
				sender.sendMessage(Translation(Translatable("status.game.finished"), this.tributes[0].player.displayName));
				break;
		}
	}

	@state(lobby) @op @command("start", Translatable("commands.start.description")) commandStart(WorldCommandSender sender, Countdown seconds=Countdown(10)) {
		if(this.lobbyCountdown > seconds) {
			this.lobbyCountdown = seconds;
			sender.sendMessage(Format.green, Translation(Translatable("commands.start.success"), seconds));
		} else {
			sender.sendMessage(Format.red, Translation(Translatable("commands.start.failed")));
		}
	}

	@state(game) @op @command("deathmatch", Translatable("commands.deathmatch.description")) commandDeathmatch(WorldCommandSender sender, Countdown seconds=Countdown(10)) {
		//TODO reduce countdown
		//TODO send message
	}
	
	private enum TeamAction { add, remove }

	@state(invincibility, game) @command("team", Translatable("commands.team.description")) @permission("hardcoregames:team") commandTeam0(Player sender, TeamAction action, Player[] players) {
		auto tribute = this.tributes[sender.id]; // only tributes should be able to send the command
		this.updateTeam(tribute);
		if(action == TeamAction.add) {
			foreach(player ; players) {
				if(player.id !in this.tributes) sender.sendMessage(Format.red, Translation(Translatable("commands.team.notTribute"), player.displayName));
				else if(tribute.team.canFind(player.id)) sender.sendMessage(Format.red, Translation(Translatable("commands.team.add.failed"), player.displayName));
				else {
					tribute.team ~= player.id;
					sender.sendMessage(Format.green, Translation(Translatable("commands.team.add.success"), player.displayName));
				}
			}
		} else {
			foreach(player ; players) {
				if(player.id !in this.tributes) sender.sendMessage(Format.red, Translation(Translatable("commands.team.notTribute"), player.displayName));
				else {
					bool removed = false;
					foreach(i, id; tribute.team) {
						if(id == player.id) {
							tribute.team = tribute.team[0..i] ~ tribute.team[i+1..$];
							removed = true;
							break;
						}
					}
					if(removed) sender.sendMessage(Format.red, Translation(Translatable("commands.team.remove.failed"), player.displayName));
					else sender.sendMessage(Format.green, Translation(Translatable("commands.team.remove.success"), player.displayName));
				}
			}
		}
	}

	@state(invincibility, game) @command("team", Translatable("commands.team.description")) @permission("hardcoregames:team") commandTeam1(Player sender, SingleEnum!"list" list) {
		auto tribute = this.tributes[sender.id]; // only tributes should be able to send the command
		Player[] players = this.updateTeam(tribute);
		if(players.length) {
			string[] names;
			foreach(player ; players) names ~= player.displayName;
			sender.sendMessage(Translation(Translatable("commands.team.list.players"), players.length, names.join(", ")));
		} else {
			sender.sendMessage(Translation(Translatable("commands.team.list.empty")));
		}
	}
	
	@state(invincibility, game) @command("spectate", Translatable("commands.spectate.description")) @permission("hardcoregames:spectate") commandSpectate0(Player sender, Player target) {
		//TODO
	}

	// EVENTS

	@state(lobby) @event playerJoinLobby(PlayerSpawnEvent event) {
		this.tributes[event.player.id] = new Tribute(event.player);
		if(!event.player.displayName.startsWith("§")) event.player.localDisplayName = Format.gray ~ event.player.displayName;
		event.message = Format.green ~ "+ " ~ Format.reset ~ event.player.displayName;
	}

	@state(lobby) @event playerLeftLobby(PlayerDespawnEvent event) {
		this.tributes.remove(event.player.id);
		event.message = Format.red ~ "- " ~ Format.reset ~ event.player.displayName;
	}

	@state(lobby, aftermath) @event @cancel entityDamageCancel(EntityDamageEvent event) {}

	//TODO cancel drop, block breaking, block touching

	@state(invincibility) @event playerDamageCancel(EntityDamageEvent event) {
		if(cast(Player)event.entity) event.cancel();
	}

	@state(invincibility, game, deathmatch) @event playerDamage(EntityDamageEvent event) {
		auto player = cast(Player)event.entity;
		/*if(player !is null && event.fatal) {
			event.cancel();
			this.onPlayerDeath(player, event);
		}*/
	}

	@state(invincibility, game, deathmatch, aftermath) @event playerJoinGame(PlayerSpawnEvent event) {
		//TODO set as spectator
		//TODO add spectate permission
		event.player += &this.removeDamage;
		event.announce = false;
	}

	@state(invincibility, game, deathmatch) @event playerLeftGame(PlayerDespawnEvent event) {
		auto tribute = event.player.id in this.tributes;
		if(tribute) {
			this.onPlayerDeath(event.player, null);
		} else {
			// just a spectator
			event.announce = false;
		}
	}

	// GENERIC

	private Player[] updateTeam(Tribute tribute) {
		Player[] players;
		for(size_t i=0; i<tribute.team.length; i++) {
			auto t = tribute.team[i] in this.tributes;
			if(t) players ~= (*t).player;
			else tribute.team = tribute.team[0..i] ~ tribute.team[i+1..$];
		}
		return players;
	}

	private void removeDamage(EntityDamageEvent event) {
		event.cancel();
	}

	private void onPlayerDeath(Player player, EntityDamageEvent event) {
		auto tribute = this.tributes;
		this.tributes.remove(player.id); //TODO enforce to be true
		if(this.tributes.length == 1) {
			auto winner = this.tributes[0];
			winner.player.gamemode = 1;
			this.updateState(aftermath);
			//TODO broadcast winning
			//TODO change state
		} else {
			//TODO remove from other tribute's team
			if(event !is null) { // event is null when player has left
				//player.revokePermission("hardcoregames:team"); // remove possibility of using /team command
				//player.grantPermission("hardcoregames:spectate"); // add possibility of using /spectate command
				player += &this.removeDamage;
				//TODO
			}
		}
	}

}

struct HardcoreGamesSettings {

	uint lobbyDuration = 120;
	uint invincibilityDuration = 45;
	uint gameDuration = 480;

	uint requiredPlayers = 2;

}
