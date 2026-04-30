class Gavel < Formula
  desc "Native macOS approval daemon for Claude Code session monitoring"
  homepage "https://github.com/JaysonRawlins/claude-gavel"
  url "https://github.com/JaysonRawlins/claude-gavel/releases/download/v1.2.1/gavel-v1.2.1-macos-arm64.tar.gz"
  sha256 "7c0131d3b8fd27b06d94c8d7198208d9c1dcfb8cb3b4fd3c1246a4589e35705b"
  license "MIT"
  version "1.2.1"

  depends_on :macos

  def install
    bin.install "gavel"
    bin.install "gavel-hook"
    bin.install "scripts/gavel-setup"
    bin.install "scripts/gavel-uninstall-hooks"
    (share/"gavel/hooks").install Dir["hooks/*.sh"]
    (share/"gavel/defaults").install "defaults/session-context.md"
  end

  def post_install
    # Homebrew sandboxes post_install — can't write to ~/
    # Setup is handled by gavel-setup script that the user runs
  end

  service do
    run [opt_bin/"gavel"]
    keep_alive true
    process_type :interactive
    log_path "#{Dir.home}/.claude/gavel/gavel.log"
    error_log_path "#{Dir.home}/.claude/gavel/gavel.log"
  end

  def caveats
    <<~EOS
      Run setup to register hooks with Claude Code:
        gavel-setup

      Then start gavel:
        brew services start gavel

      To stop gavel:
        brew services stop gavel

      To unregister hooks before uninstalling:
        gavel-uninstall-hooks
    EOS
  end

  test do
    assert_predicate bin/"gavel", :executable?
    assert_predicate bin/"gavel-hook", :executable?
  end

  def migrate_from_manual_install
    old_label = "com.gavel.daemon"
    old_plist = Pathname.new("#{Dir.home}/Library/LaunchAgents/#{old_label}.plist")

    if old_plist.exist?
      quiet_system "launchctl", "bootout", "gui/#{Process.uid}/#{old_label}"
      old_plist.delete
      opoo "Migrated from manual install: removed old #{old_label} LaunchAgent"
    end

    old_bin = Pathname.new("#{Dir.home}/.claude/gavel/bin")
    if old_bin.directory?
      (old_bin/"gavel").delete if (old_bin/"gavel").exist?
      (old_bin/"gavel-hook").delete if (old_bin/"gavel-hook").exist?
      old_bin.rmdir if old_bin.children.empty?
    end
  end

  def setup_user_config
    gavel_dir = Pathname.new("#{Dir.home}/.claude/gavel")
    hooks_dir = gavel_dir/"hooks"
    gavel_dir.mkpath
    gavel_dir.chmod(0755) if gavel_dir.exist?
    hooks_dir.mkpath

    (share/"gavel/hooks").children.each do |hook|
      target = hooks_dir/hook.basename
      target.write(hook.read)
      target.chmod(0755)
    end

    context_file = gavel_dir/"session-context.md"
    unless context_file.exist?
      context_file.write((share/"gavel/defaults/session-context.md").read)
    end
  end

  def register_hooks_in_settings
    require "json"
    settings_path = Pathname.new("#{Dir.home}/.claude/settings.json")
    settings_path.dirname.mkpath

    if settings_path.exist?
      begin
        cfg = JSON.parse(settings_path.read)
      rescue JSON::ParserError
        opoo "Could not parse #{settings_path}; skipping hook registration"
        return
      end
    else
      cfg = {}
    end

    hooks_dir = "#{Dir.home}/.claude/gavel/hooks"
    hooks = cfg["hooks"] ||= {}

    gavel_hooks = {
      "PreToolUse" => [{
        "hooks" => [{ "type" => "command", "command" => "#{hooks_dir}/pre_tool_use.sh", "timeout" => 86400 }],
      }],
      "PermissionRequest" => [{
        "hooks" => [{ "type" => "command", "command" => "#{hooks_dir}/permission_request.sh", "timeout" => 86400 }],
      }],
      "PostToolUse" => [{
        "hooks" => [{ "type" => "command", "command" => "#{hooks_dir}/post_tool_use.sh", "async" => true }],
      }],
      "SessionStart" => [{
        "hooks" => [{ "type" => "command", "command" => "#{hooks_dir}/session_start.sh" }],
      }],
      "Stop" => [{
        "hooks" => [{ "type" => "command", "command" => "#{hooks_dir}/stop.sh", "async" => true }],
      }],
    }

    changed = false
    gavel_hooks.each do |event, entries|
      existing = hooks[event] || []
      has_gavel = existing.any? do |entry|
        (entry["hooks"] || []).any? { |h| (h["command"] || "").include?("gavel") }
      end
      unless has_gavel
        hooks[event] = existing + entries
        changed = true
      end
    end

    if changed
      settings_path.write(JSON.pretty_generate(cfg))
      ohai "Registered gavel hooks in #{settings_path}"
    end
  end
end
