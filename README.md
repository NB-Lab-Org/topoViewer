## Overview

`TopoViewer` is a network visualization tool that converts topology data into a Cytoscape graph model, allowing you to visualize your network using [Cytoscape.js](https://js.cytoscape.org).

![Group Visualization](./docs/containerlab-topology-definition-enhancement/containerlab-topology-definition-group.png)


The project is structured with a Go-based backend that processes and visualizes network topologies, converting data (currently supporting Container Lab) into a graph model for display. The frontend is a web application built with HTML and JavaScript libraries, including Cytoscape.js for graph visualization and Xterm.js for interactive shell access in the browser. When deployed on the same host as Container Lab, the application can directly access Container Lab nodes through the browser interface.

The codebase is organized into several folders prefixed with `go_`, each serving a specific purpose:

- **go_cloudshellwrapper**: Contains the main logic for running TopoViewer, including:
  - `cmd/main.go` as the entry point for TopoViewer,
  - `cmdClab.go` for handling CLAB-specific commands,
  - `cmdNsp.go` for NSP-specific commands,
  - and the `clabHandlers` directory, which provides handlers specific to Container Lab operations.

- **go_topoengine**: Manages the core logic for processing and visualizing network topologies, from parsing topology files to generating visual representations.

- **go_xtermjs**: Integrates Xterm.js to provide terminal emulation within the TopoViewer interface, enabling direct interaction with the terminal through the web interface.

- **go_tools**: Contains various utility functions and tools essential for TopoViewer’s operations.


## Deployment

### Prerequisites

- Linux (x86_64) with Docker and [ContainerLab](https://containerlab.dev/) installed
- At least one ContainerLab topology deployed
- `unzip`, `wget`, `jq` available on the system

### Quick Install

Run the install script on the target VM:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/NB-Lab-Org/topoViewer/development/tools/get.sh)
```

This will:
1. Download the latest `dist.zip` from the repository
2. Extract binary and assets to `/opt/topoviewer/`
3. Set up the systemd service (`topoviewer.service`)
4. Create the topology switching script at `/opt/topoviewer/bin/switch-topoviewer.sh`

### Configuration

After installation, edit the config file:

```bash
vi /opt/topoviewer/config/current-topology.env
```

Set two values:
- **TOPOLOGY_PATH**: Path to your ContainerLab topology YAML file
- **ALLOWED_HOSTNAMES**: Comma-separated list of hostnames for CORS (e.g., `localhost,my.domain.com`)

Example:
```
TOPOLOGY_PATH=/root/containerlab/my-lab/my-lab.clab.yml
ALLOWED_HOSTNAMES=localhost,my-topoviewer.example.com
```

### Start the Service

```bash
systemctl start topoviewer
systemctl status topoviewer
```

TopoViewer will be available at `http://<host>:8080`.

### Switching Topologies

Use the switch script to change between deployed topologies:

```bash
# List all topologies
/opt/topoviewer/bin/switch-topoviewer.sh list

# Switch to a different topology
/opt/topoviewer/bin/switch-topoviewer.sh switch <topology-name>

# Show current topology
/opt/topoviewer/bin/switch-topoviewer.sh current
```

The topology must be deployed in ContainerLab before switching. The expected directory structure is:
```
/root/containerlab/<name>/<name>.clab.yml
```

### Logs

```bash
journalctl -u topoviewer -f
```

## Container Lab Topology Features

TopoViewer provides specialized support for Container Lab topologies, enhancing network visualization and usability. The following guides and features are tailored for Container Lab users:

### Quick Start

The **Quick Start Guide** offers step-by-step instructions for setting up and using TopoViewer with Container Lab topologies. Refer to the [Quick Start Guide](https://github.com/asadarafat/topoViewer/blob/development/docs/quickstart/quickstart.md) for details.

### Enhanced Topology Definition

TopoViewer supports [enhanced containerlab topology definitions](docs/containerlab-topology-definition-enhancement/readme.md), introducing additional features to make network visualizations more intuitive and user-friendly.

### User TaskFlow

The **User TaskFlow Guide** provides a detailed walkthrough for leveraging TopoViewer’s features with Container Lab topologies. See the [User TaskFlow Guide](https://github.com/asadarafat/topoViewer/blob/development/docs/user-taskflow/readme.md) for comprehensive instructions.
