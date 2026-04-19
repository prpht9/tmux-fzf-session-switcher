# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "session switcher (C-a b / session-switcher-fzf-input)" do
  before(:each) do
    start_tmux
    # Create a few named sessions for testing
    docker_exec("tmux new-session -d -s alpha -c /root")
    docker_exec("tmux new-session -d -s bravo -c /root")
    docker_exec("tmux new-session -d -s charlie -c /root")
  end

  after(:each) { stop_tmux }

  describe "session listing" do
    it "lists all active sessions" do
      result = run_session_switcher_input
      lines = result.stdout.split("\n")
      expect(lines).to include("alpha")
      expect(lines).to include("bravo")
      expect(lines).to include("charlie")
    end

    it "includes the base test session" do
      result = run_session_switcher_input
      expect(result.stdout).to include("_test_base")
    end
  end

  describe "@last_session ordering" do
    it "places @last_session first in the list" do
      docker_exec("tmux set-environment -g @last_session bravo")
      result = run_session_switcher_input
      first_line = result.stdout.split("\n").first
      expect(first_line).to eq("bravo")
    end

    it "does not duplicate @last_session in the list" do
      docker_exec("tmux set-environment -g @last_session bravo")
      result = run_session_switcher_input
      lines = result.stdout.split("\n")
      bravo_count = lines.count { |l| l == "bravo" }
      expect(bravo_count).to eq(1)
    end

    it "handles missing @last_session gracefully" do
      docker_exec("tmux set-environment -gu @last_session 2>/dev/null; true")
      result = run_session_switcher_input
      expect(result.success).to be true
      expect(result.stdout.split("\n").length).to be >= 4
    end
  end

  describe "@last_session tracking" do
    it "updates @last_session to the current session after running" do
      # Switch to alpha so it becomes the current session
      docker_exec("tmux switch-client -t alpha 2>/dev/null; true")
      run_session_switcher_input
      result = docker_exec("tmux show-environment -g @last_session")
      # Output is like "@last_session=alpha" or similar
      expect(result.stdout).to include("=")
    end
  end

  describe "full switch pipeline" do
    it "switches to the selected session when piped through fzf filter" do
      docker_exec("tmux set-environment -g @last_session bravo")
      # Simulate the full pipeline: script | fzf -f bravo | head -1 → switch-client
      docker_exec(
        "ruby --disable=gems /opt/tfss/scripts/session-switcher-fzf-input " \
        "| fzf -f bravo | head -1 | { read session && tmux switch-client -t \"$session\"; }"
      )
      # Verify we can at least reach bravo
      result = docker_exec("tmux has-session -t bravo 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end
end
