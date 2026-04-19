# Homebrew Tap for Gavel

[Gavel](https://github.com/JaysonRawlins/claude-gavel) is a native macOS
menu bar daemon for Claude Code session monitoring and approval.

## Install

```bash
brew tap JaysonRawlins/gavel
brew install gavel
brew services start gavel
```

## Upgrade

```bash
brew upgrade gavel
brew services restart gavel
```

## Uninstall

```bash
gavel-uninstall-hooks
brew services stop gavel
brew uninstall gavel
brew untap JaysonRawlins/gavel
```

## What gets installed

| Component | Location |
|---|---|
| gavel daemon | /opt/homebrew/bin/gavel |
| gavel-hook CLI | /opt/homebrew/bin/gavel-hook |
| Hook shims | ~/.claude/gavel/hooks/ |
| Session context | ~/.claude/gavel/session-context.md |
| Rules | ~/.claude/gavel/rules.json (created on first run) |
| Log | ~/.claude/gavel/gavel.log |
