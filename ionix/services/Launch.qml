pragma Singleton

// Starting applications so they outlive the shell.
//
// execDetached already double-forks, so a launched app is not our child — but
// that is not what kills it. The shell runs as ionix-quickshell.service, and
// systemd stops a unit by killing its whole cgroup (KillMode=control-group),
// which every process we ever started is still in, detached or not. So a QML
// crash (Restart=on-failure), a `systemctl --user restart` or a theme reload
// that restarts the unit took every app opened from the bar down with it.
//
// Under a unit, each launch goes through `systemd-run --user --scope`, which
// moves itself into a fresh scope in app-graphical.slice (where uwsm puts apps
// too) and then execs the command, so the app keeps our environment and cwd but
// no longer belongs to us. Run any other way (`qs -c ionix` from a terminal, an
// exec-once), there is no unit cgroup to escape and execDetached is enough.

import QtQuick
import Quickshell

Singleton {
    id: root

    // systemd sets INVOCATION_ID for every unit it starts, and nothing else does.
    readonly property bool inUnit: (Quickshell.env("INVOCATION_ID") ?? "") !== ""

    /**
     * Start `command` (an argv list) detached from the shell, in `workingDirectory` if given.
     * `name` labels the scope (`app-ionix-<name>-<random>.scope`); it defaults to the command's basename.
     */
    function run(command, workingDirectory, name) {
        if (!command || command.length === 0)
            return;
        const argv = Array.from(command);
        const context = {
            command: root.inUnit ? root.scoped(argv, name) : argv
        };
        if (workingDirectory)
            context.workingDirectory = workingDirectory;
        Quickshell.execDetached(context);
    }

    /**
     * Start a desktop entry, or one of its actions, the way `execute()` would, but through `run`.
     */
    function entry(entry, action) {
        if (!entry)
            return;
        root.run((action ?? entry).command, entry.workingDirectory, entry.id);
    }

    function scoped(argv, name) {
        // "-" separates the fields of an XDG app unit name, so it goes along with
        // anything a unit name can't hold. The random tail keeps two launches of
        // the same app from colliding, which would make systemd-run refuse the second.
        const id = (name || argv[0].split("/").pop()).replace(/[^A-Za-z0-9:_.]/g, "_");
        const suffix = `${Date.now().toString(16)}${Math.floor(Math.random() * 0x10000).toString(16)}`;
        return ["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app-graphical.slice", `--unit=app-ionix-${id}-${suffix}.scope`, `--description=${name || argv[0]}`, "--"].concat(argv);
    }
}
