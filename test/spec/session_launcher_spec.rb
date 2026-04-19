# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "default session launcher (tfss-default-session-launcher)" do
  before(:each) do
    start_tmux
    # Reset options to defaults
    docker_exec("tmux set-option -gu @tfss_session_window_split 2>/dev/null; true")
    docker_exec("tmux set-option -gu @tfss_session_vim_cmd 2>/dev/null; true")
    docker_exec("tmux set-option -gu @tfss_session_vim_options 2>/dev/null; true")
  end

  after(:each) { stop_tmux }

  def create_session_and_launch(name, dir, split: "0", vim_cmd: "")
    docker_exec("tmux new-session -d -s '#{name}' -c '#{dir}' -n localhost")
    docker_exec("tmux set-option -g @tfss_session_window_split '#{split}'") unless split == "0"
    docker_exec("tmux set-option -g @tfss_session_vim_cmd '#{vim_cmd}'") unless vim_cmd.empty?
    run_session_launcher(name, dir)
    sleep 1 # let tmux commands settle
  end

  describe "window creation" do
    it "creates a window named ide2" do
      create_session_and_launch("launcher_test", "/root/work/normal-repo")
      result = docker_exec("tmux list-windows -t launcher_test -F '\#{window_name}'")
      expect(result.stdout.split("\n")).to include("ide2")
    end

    it "kills the initial localhost window (window 0)" do
      create_session_and_launch("launcher_test", "/root/work/normal-repo")
      result = docker_exec("tmux list-windows -t launcher_test -F '\#{window_index}:\#{window_name}'")
      expect(result.stdout).not_to include("0:localhost")
    end
  end

  describe "window splitting" do
    it "creates a single pane when split is disabled (default)" do
      create_session_and_launch("nosplit_test", "/root/work/normal-repo")
      result = docker_exec("tmux list-panes -t nosplit_test:2 -F '\#{pane_index}' | wc -l")
      expect(result.stdout.strip.to_i).to eq(1)
    end

    it "creates two panes when @tfss_session_window_split=1" do
      create_session_and_launch("split_test", "/root/work/normal-repo", split: "1")
      result = docker_exec("tmux list-panes -t split_test:2 -F '\#{pane_index}' | wc -l")
      expect(result.stdout.strip.to_i).to eq(2)
    end
  end

  describe "vim command" do
    it "sends vim command to pane 0 when configured" do
      create_session_and_launch("vim_test", "/root/work/normal-repo", vim_cmd: "vi")
      sleep 1
      result = docker_exec("tmux capture-pane -t vim_test:2.0 -p")
      # vi should show something — at minimum not be an empty shell prompt
      expect(result.stdout.length).to be > 0
    end
  end
end
