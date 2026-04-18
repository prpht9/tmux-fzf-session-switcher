# frozen_string_literal: true

require "open3"
require "timeout"

CONTAINER_NAME = "tfss-test"

Result = Struct.new(:stdout, :stderr, :success, :exit_code, keyword_init: true)

# Runs commands inside the Docker container via `docker exec`.
module DockerHelper
  HELPERS = "/opt/tfss/test/helpers"

  def docker_exec(cmd, timeout: 30)
    escaped = cmd.gsub("'", "'\\\\''")
    full = "docker exec #{CONTAINER_NAME} bash -c '#{escaped}'"
    stdout = stderr = ""
    status = nil
    Timeout.timeout(timeout) do
      stdout, stderr, status = Open3.capture3(full)
    end
    Result.new(
      stdout:    stdout.strip,
      stderr:    stderr.strip,
      success:   status.success?,
      exit_code: status.exitstatus
    )
  end

  # Run a command with tmux helpers sourced
  def docker_tmux(cmd, timeout: 30)
    docker_exec("source #{HELPERS}/tmux_helpers.sh && #{cmd}", timeout: timeout)
  end

  def setup_fixtures
    docker_exec("bash #{HELPERS}/fixture_helpers.sh")
  end

  def start_tmux
    docker_tmux("start_test_tmux")
  end

  def stop_tmux
    docker_exec("tmux kill-server 2>/dev/null; true")
  end

  # Run the fd command used by tmux-git (repo selector)
  def fd_repos(repo_path = "/root/work")
    docker_exec("fd --hidden --max-depth 4 '^.git$' '#{repo_path}' | sed -E 's@/\\.git/?$@@'")
  end

  # Run tmux-git with a direct directory argument (bypasses fzf)
  def run_tmux_git(session_dir, env: "")
    docker_exec("#{env} bash /opt/tfss/scripts/tmux-git '#{session_dir}'", timeout: 15)
  end

  # Run the session-switcher-fzf-input Ruby script
  def run_session_switcher_input
    docker_exec("ruby --disable=gems /opt/tfss/scripts/session-switcher-fzf-input")
  end

  # Run the default session launcher
  def run_session_launcher(session, session_dir)
    docker_exec("bash /opt/tfss/scripts/tfss-default-session-launcher '#{session}' '#{session_dir}'")
  end
end

RSpec.configure do |config|
  config.include DockerHelper

  config.before(:suite) do
    helper = Object.new.extend(DockerHelper)
    result = helper.setup_fixtures
    unless result.success
      warn "Fixture setup failed: #{result.stderr}"
    end
  end
end
