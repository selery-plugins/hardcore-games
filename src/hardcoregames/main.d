module hardcoregames.main;

import selery.node.plugin;

import hardcoregames.world : HardcoreGamesWorld;

class HardcoreGames : NodePlugin {

	private shared NodeServer server;
	
	public this(shared NodeServer server) {
		this.server = server;
	}

	@start onStart() {
		//TODO register world template
		this.server.addWorld!HardcoreGamesWorld("hg");
	}

}
