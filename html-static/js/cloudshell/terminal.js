(function() {
	// Function to get query parameters
	var urlParam = function(name, w) {
		w = w || window;
		var rx = new RegExp('[\&|\?]' + name + '=([^\&\#]+)'),
			val = w.location.search.match(rx);
		return !val ? '' : val[1];
	};

	// Retrieve the RouterID query parameter
	var routerId = urlParam('RouterID');
	console.log("routerId:", routerId);

	document.title = `TopoViewer::${urlParam('RouterName')}`;


	// Initialize the terminal with the desired options
	var terminal = new Terminal({
		screenKeys: true,
		useStyle: true,
		cursorBlink: true,
		fullscreenWin: true,
		maximizeWin: true,
		screenReaderMode: true,
		cols: 128,
	});

	// Open the terminal in the specified HTML element
	terminal.open(document.getElementById("terminal"));

	// Determine the WebSocket protocol based on the page's protocol
	var protocol = (location.protocol === "https:") ? "wss://" : "ws://";
	var url = protocol + location.host + "/xterm.js";
	var ws = new WebSocket(url);

	console.log(ws);

	// Load necessary addons
	var attachAddon = new AttachAddon.AttachAddon(ws);
	var fitAddon = new FitAddon.FitAddon();
	var webLinksAddon = new WebLinksAddon.WebLinksAddon();
	var unicode11Addon = new Unicode11Addon.Unicode11Addon();
	var serializeAddon = new SerializeAddon.SerializeAddon();

	terminal.loadAddon(fitAddon);
	terminal.loadAddon(webLinksAddon);
	terminal.loadAddon(unicode11Addon);
	terminal.loadAddon(serializeAddon);

	// Define WebSocket event handlers
	ws.onclose = function(event) {
		console.log(event);
		terminal.write('\r\n\nconnection has been terminated from the server-side (hit refresh to restart)\n');
	};

	ws.onopen = function() {
		terminal.loadAddon(attachAddon);
		terminal._initialized = true;
		terminal.focus();
		setTimeout(function() {
			fitAddon.fit();
		});
		setTimeout(function() {
			var routerName = urlParam('RouterName');
			var nodeKind = urlParam('Kind');
			// Normalize the vrnetlab "vr-" prefix so vr-paloalto_panos /
			// vr-pan resolve the same as paloalto_panos — matches the
			// management-IP table's credential mapping in dev.js.
			var baseKind = String(nodeKind).replace(/^vr-/, "");
			var command;
			if (nodeKind === "linux") {
				// Linux endpoints have no sshd; use docker exec into the
				// containerlab-managed container. RouterName is already
				// the long container name (clab-<lab>-<node>) since the
				// frontend reads it from the node's `longname` field.
				command = "docker exec -it " + routerName + " sh";
			} else if (baseKind === "paloalto_panos" || baseKind === "pan") {
				// PAN-OS can't take the shared `netbrain` SSH user that
				// validate_netbrain_discovery provisions on other vendors
				// (it only sets the SNMP community there). Log in as the
				// built-in admin instead — the user types the Admin@123
				// password at the interactive prompt.
				command = "ssh -q -o StrictHostKeyChecking=no admin@" + routerName;
			} else {
				command = "ssh -q -o StrictHostKeyChecking=no netbrain@" + routerName;
			}
			console.log(command);
			ws.send(command + "\n");
		}, 100);



		terminal.onResize(function(event) {
			var rows = event.rows;
			var cols = event.cols;
			var size = JSON.stringify({
				cols: cols,
				rows: rows + 1
			});
			var send = new TextEncoder().encode("\x01" + size);
			console.log('resizing to', size);


			ws.send(send);
			fitAddon.fit(); // this code indeedd
		});

		terminal.onTitleChange(function(event) {
			console.log(event);
		});

		// Fit the terminal to the window size when the window is resized
		window.onresize = function() {
			fitAddon.fit();
		};
	};
})();