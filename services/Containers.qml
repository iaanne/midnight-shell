pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Polls the container engine (Podman or Docker) and splits containers into two
// groups for the dashboard "Containers" tab: running ("on") and everything
// else ("idle").
//
// The engine CLI is used instead of the REST API so the tab works with both
// rootless and system containers without extra socket configuration.
//
// Engines are detected at startup. The check is verbose on purpose: some
// systems alias one command to another, so the version output is matched
// ("Docker" for docker, "podman" for podman) instead of trusting the command
// name alone.
Singleton {
    id: root

    readonly property string allEngines: "docker podman"
    property var engines: []
    property string activeEngine: ""
    property int refreshInterval: 5000
    property var containers: []
    property var running: []
    property var idle: []
    property bool loading: false
    property string errorMessage: ""
    property var lastUpdated: null
    property string stderrText: ""
    property bool actionRunning: false
    property string actionVerb: ""
    property string actionId: ""
    property string actionError: ""
    property string actionStderr: ""

    // Detect engine CLIs and verify them with their version output.
    function detectEngines(): void {
        engines = [];
        activeEngine = "";
        detectProc.running = true;
    }

    function setActiveEngine(engine: string): void {
        if (!engines.includes(engine) || activeEngine === engine)
            return;
        activeEngine = engine;
        containers = [];
        running = [];
        idle = [];
        errorMessage = "";
        lastUpdated = null;
        refresh();
    }

    function refresh(): void {
        if (!activeEngine || proc.running || detectProc.running)
            return;
        root.loading = true;
        root.stderrText = "";
        proc.command = [activeEngine, "ps", "-a", "--format", "json"];
        proc.running = true;
    }

    // Starts a stopped container.
    function startContainer(id: string): void {
        root.runAction("start", id);
    }

    // Stops a running container.
    function stopContainer(id: string): void {
        root.runAction("stop", id);
    }

    // Resumes a paused container.
    function unpauseContainer(id: string): void {
        root.runAction("unpause", id);
    }

    function runAction(verb: string, id: string): void {
        if (actionProc.running || !id || !activeEngine)
            return;
        root.actionVerb = verb;
        root.actionId = id;
        root.actionError = "";
        root.actionStderr = "";
        root.actionRunning = true;
        actionProc.command = [activeEngine, verb, id];
        actionProc.running = true;
    }

    function handleOutput(text: string): void {
        const next = [];
        try {
            const parsed = JSON.parse(text);
            const list = Array.isArray(parsed) ? parsed : [];
            for (const item of list) {
                const state = String(item.State || "").toLowerCase();
                next.push({
                    id: String(item.Id || ""),
                    name: root.firstName(item.Names),
                    image: String(item.Image || ""),
                    state: state,
                    status: String(item.Status || root.titleCase(state)),
                    ports: root.formatPorts(item.Ports),
                    running: state === "running",
                    exitCode: typeof item.ExitCode === "number" ? item.ExitCode : -1,
                    created: Number(item.Created) || 0
                });
            }
            // Newest first; fall back to name for equal creation times.
            next.sort((a, b) => (b.created - a.created) || a.name.localeCompare(b.name));
            root.errorMessage = "";
        } catch (e) {
            root.errorMessage = String(e);
        }
        root.containers = next;
        root.running = next.filter(container => container.running);
        root.idle = next.filter(container => !container.running);
        root.lastUpdated = new Date();
        root.loading = false;
    }

    function firstName(names: var): string {
        if (Array.isArray(names) && names.length > 0)
            return String(names[0]);
        return "";
    }

    function titleCase(value: string): string {
        if (!value)
            return "";
        return value.charAt(0).toUpperCase() + value.slice(1);
    }

    function formatPorts(ports: var): string {
        if (!Array.isArray(ports) || ports.length === 0)
            return "";
        const parts = [];
        for (const port of ports) {
            const container = Number(port.container_port) || 0;
            if (container <= 0)
                continue;
            const host = Number(port.host_port) || 0;
            const range = Math.max(1, Number(port.range) || 1);
            const protocol = String(port.protocol || "tcp");
            const inner = range > 1 ? `${container}-${container + range - 1}` : String(container);
            parts.push(host > 0 && host !== container ? `${host}:${inner}/${protocol}` : `${inner}/${protocol}`);
        }
        return parts.join(", ");
    }

    Process {
        id: detectProc

        // Print the version of every engine found on PATH; the caller filters
        // by content so a wrapper script or alias cannot fake the engine.
        command: ["sh", "-c", "for c in " + allEngines + "; do command -v \"$c\" >/dev/null 2>&1 || continue; \"$c\" --version 2>/dev/null | head -n1; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const lines = text.trim().split("\n").filter(line => line.length > 0);
                for (const engine of allEngines.split(" ")) {
                    if (lines.some(line => line.toLowerCase().includes(engine)))
                        found.push(engine);
                }
                root.engines = found;
                root.activeEngine = found.length > 0 ? found[0] : "";
                if (root.activeEngine)
                    root.refresh();
            }
        }
    }

    Process {
        id: proc

        command: []

        stdout: StdioCollector {
            onStreamFinished: root.handleOutput(text)
        }

        stderr: StdioCollector {
            onStreamFinished: root.stderrText = text
        }

        onRunningChanged: {
            if (!running)
                root.loading = false;
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode !== 0) {
                const detail = root.stderrText.trim();
                root.errorMessage = detail || `${root.activeEngine} exited with code ${exitCode}`;
                root.containers = [];
                root.running = [];
                root.idle = [];
                root.lastUpdated = new Date();
            }
            root.loading = false;
        }
    }

    Process {
        id: actionProc

        command: []

        stderr: StdioCollector {
            onStreamFinished: root.actionStderr = text
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.actionRunning = false;
            if (exitCode !== 0)
                root.actionError = root.actionStderr.trim() || `${root.activeEngine} ${root.actionVerb} exited with code ${exitCode}`;
            root.actionVerb = "";
            root.actionId = "";
            root.refresh();
        }
    }
}
