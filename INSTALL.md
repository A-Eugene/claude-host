# Installing claude-host

These steps work for a person at a terminal and for an AI agent running shell
commands. Each step says how to check it worked. An agent should run the check
and stop at the first one that fails.

## 0. Requirements

| Needs | Check |
|---|---|
| Linux with systemd | `systemctl --version` |
| bash 4.4 or later | `bash --version` |
| tmux | `tmux -V` |
| python3 (standard library only) | `python3 --version` |
| git | `git --version` |
| Claude Code 2.1.258 or later, signed in | `claude --version` |

`restart`, `update`, `boot` and `--self` hand work to systemd, so they need it.
The rest runs without it.

## 1. Get the files

```sh
git clone https://github.com/A-Eugene/claude-host.git /tmp/claude-host
mkdir -p ~/.claude/skills
rsync -a --exclude=.git --exclude=crew.conf --exclude=sessions.state --exclude=slots.state \
  /tmp/claude-host/ ~/.claude/skills/claude-host/
chmod +x ~/.claude/skills/claude-host/bin/claude-host ~/.claude/skills/claude-host/hooks/*.sh
ln -sf ~/.claude/skills/claude-host/bin/claude-host /usr/local/bin/claude-host
```

Without root, link into `~/.local/bin` instead, and make sure it is on `PATH`.

Check: `claude-host --help` prints the command list.

The directory must be `~/.claude/skills/claude-host`. Claude Code finds the skill
there, and the hooks and the web page locate the CLI relative to it.

## 2. Write the config

```sh
claude-host setup
```

This writes `~/.claude/skills/claude-host/crew.conf` with the defaults:

| Key | Default |
|---|---|
| `WORKDIR` | your home directory |
| `MODEL` | `claude-opus-5-5` |
| `EFFORT` | `medium` |
| `PERMISSION_MODE` | `auto` |
| `AUTOCOMPACT` | `auto` |
| `TMUX_PREFIX` | `Claude` |
| `TITLE_PREFIX` | empty |

`WORKDIR` is the directory every session starts in, and it decides which
transcript store the crew reads. Set it now if your sessions should start
somewhere else:

```sh
claude-host setup --workdir /path/to/work --model claude-opus-5-5 --effort high
```

The crew refuses to change `WORKDIR` later while a session is running or saved,
because a conversation resumes only from the directory it started in.

Check: `claude-host status` prints the sessions header and "(none running)".

## 3. Register the hooks

Add both entries to the `hooks` object in `~/.claude/settings.json`. **Merge them
into the existing file. Do not replace the file**, since it holds your other
settings and hooks.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [{ "type": "command",
                    "command": "~/.claude/skills/claude-host/hooks/local-skills-guard.sh" }]
      }
    ],
    "SessionStart": [
      {
        "matcher": "clear",
        "hooks": [{ "type": "command",
                    "command": "~/.claude/skills/claude-host/bin/claude-host cleared" }]
      }
    ]
  }
}
```

- **`local-skills-guard.sh`**: every crew session starts in `WORKDIR`, so Claude
  Code never loads the skills, `CLAUDE.md` or `AGENTS.md` of a folder below it.
  The hook names them the first time a session touches that folder, and refuses
  the first write there until they have been read. It also names project hooks,
  settings, commands, agents and MCP servers, which crew sessions do not run.
  README.md's "Using it as intended" explains where each kind of configuration
  belongs.
- **`claude-host cleared`**: Claude Code's `/clear` keeps the previous
  conversation under the same name. The hook records the new conversation as
  the session's, and has the session ask before the previous one is deleted. To
  name the web page in that notice, prefix the command with
  `CREW_WEB_URL=https://crew.example.com `.

Check: `python3 -m json.tool ~/.claude/settings.json` succeeds, and both commands
appear in it. Sessions pick the hooks up when they next start.

## 4. Start sessions

```sh
claude-host new "Notes"                 # a brand new conversation
claude-host resume "trading research"   # a conversation you already have
claude-host status
claude-host boot on     # optional: bring the running set back after a reboot
```

Every start and stop updates the saved set, so `start` and `restart` bring back
what was running.

Check: `claude-host status` lists each started conversation. Attach to one with
`tmux attach -t Claude_<short id>` (`tmux ls` shows the names), and leave
with `Ctrl-b d`.

A host that ran an earlier version with numbered `Claude1`, `Claude2` …
sessions renames them with `claude-host migrate`. The sessions keep running.

## 5. The web page (optional)

The page runs every command as a button. It listens on `127.0.0.1:3115` and
needs a reverse proxy with HTTPS in front of it.

```sh
python3 ~/.claude/skills/claude-host/web/server.py set-password
cp ~/.claude/skills/claude-host/web/claude-host-web.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now claude-host-web
```

Check: `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3115/api/state`
prints `401`.

The unit resolves `%h` to root's home, so it runs as root. To run it as another
user, add `User=<name>` under `[Service]`.

For HTTPS with nginx and Let's Encrypt, replace `crew.example.com` with your host
name:

```sh
certbot certonly --nginx -d crew.example.com
sed 's/crew.example.com/<your host>/g' ~/.claude/skills/claude-host/web/nginx.conf \
  > /etc/nginx/conf.d/claude-host-web.conf
nginx -t && systemctl reload nginx
```

Use `certbot certonly`, not `certbot --nginx` alone. With a wildcard or
catch-all server block already present, `--nginx` can install the new
certificate into that block and break the sites it serves.

Check: the host name shows a password field, and a wrong password is refused.

## Updating

```sh
git -C /tmp/claude-host pull
rsync -a --exclude=.git --exclude=crew.conf --exclude=sessions.state --exclude=slots.state \
  /tmp/claude-host/ ~/.claude/skills/claude-host/
systemctl restart claude-host-web    # only if the web page is installed
```

`crew.conf` and `sessions.state` hold your settings and saved sessions. The
excludes keep them. Never copy over them.

## Rules for an AI agent doing this

- Run `claude-host start --restart`, `restart` and `stop` only when asked. Each one
  stops running sessions, and one of them may be your own.
- Never run `tmux kill-server`. It ends every tmux session on the machine,
  including the one you are running in.
- Never kill processes with `pkill -f` or `pgrep -f` patterns. The pattern can
  match your own shell.
- Merge `settings.json`. Do not overwrite it.
- Report each check's actual output, not the expected one.
