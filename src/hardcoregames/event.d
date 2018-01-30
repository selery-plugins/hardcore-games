module hardcoregames.event;

import selery.event.world;
import selery.world : World;

import hardcoregames.world : HardcoreGamesWorld;

abstract class HardcoreGamesEvent : WorldEvent {

	private HardcoreGamesWorld _world;

	public this(HardcoreGamesWorld world) {
		this._world = world;
	}

	public final override pure nothrow @property @safe @nogc World world() {
		return this._world;
	}

	public final pure nothrow @property @safe @nogc HardcoreGamesWorld hardcoreGamesWorld() {
		return this._world;
	}

}
