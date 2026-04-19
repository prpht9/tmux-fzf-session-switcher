FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y -qq \
  tmux \
  git \
  ruby \
  expect \
  curl \
  bc \
  && rm -rf /var/lib/apt/lists/*

# Install fd and fzf from GitHub releases (apt versions are too old)
RUN ARCH=$(dpkg --print-architecture) && \
  FD_VERSION=$(curl -s https://api.github.com/repos/sharkdp/fd/releases/latest \
    | grep tag_name | cut -d '"' -f4 | tr -d 'v') && \
  curl -Lo /tmp/fd.deb \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-musl_${FD_VERSION}_${ARCH}.deb" && \
  dpkg -i /tmp/fd.deb && rm -f /tmp/fd.deb

RUN ARCH=$(dpkg --print-architecture) && \
  FZF_VERSION=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest \
    | grep tag_name | cut -d '"' -f4 | tr -d 'v') && \
  curl -Lo /tmp/fzf.tar.gz \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH}.tar.gz" && \
  tar -xzf /tmp/fzf.tar.gz -C /usr/local/bin && \
  rm -f /tmp/fzf.tar.gz

# Git config for fixture creation
RUN git config --global user.email "test@test.com" && \
  git config --global user.name "Test User" && \
  git config --global init.defaultBranch main

# tmux config — project will be bind-mounted at /opt/tfss at runtime
RUN printf '%s\n' \
  'set -g prefix C-a' \
  'unbind C-b' \
  'bind C-a send-prefix' \
  'set -g default-terminal "screen-256color"' \
  'set -g @tfss_repo_path "/root/work"' \
  'run-shell /opt/tfss/tmux-fzf-session-switcher.tmux' \
  > /root/.tmux.conf

RUN mkdir -p /root/work

CMD ["sleep", "infinity"]
