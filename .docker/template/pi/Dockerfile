FROM docker/sandbox-templates:shell-docker

USER root
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
 && rm -rf /var/lib/apt/lists/* && ssh-keygen -A && passwd -d agent

# sshd over `docker exec` stdio (no open port). agent has an empty password, so
# no key is needed: reaching it already requires docker socket access.
RUN printf '#!/bin/sh\nmkdir -p /run/sshd\nexec /usr/sbin/sshd -i -o UsePAM=no -o PasswordAuthentication=yes -o PermitEmptyPasswords=yes\n' \
      > /usr/local/bin/sshd-stdio && chmod 755 /usr/local/bin/sshd-stdio

RUN echo 'unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY XAI_API_KEY NEBIUS_API_KEY MISTRAL_API_KEY' >> /etc/sandbox-persistent.sh

# Node.js 24 (system-wide, no fnm)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Mount points for the shared pix volumes. Pre-creating them agent-owned makes
# fresh (root-owned) volumes inherit agent ownership on first mount.
RUN mkdir /opt/pi /home/agent/.pi && chown agent:agent /opt/pi /home/agent/.pi

USER agent
ENV PATH="/home/agent/.dotfiles/.local/bin:${PATH}"
ENV PATH="/home/.local/bin:${PATH}"

# Install pi into /opt/pi so pix can share one install across sandboxes via the
# pi-bin named volume.
RUN npm install -g --prefix /opt/pi @earendil-works/pi-coding-agent
ENV PATH="/opt/pi/bin:${PATH}"
ENV RTK_INSTALL_DIR=/opt/pi/bin

# Keep fff's LMDB dbs in the container layer, not the shared pi-agent volume:
# concurrent sandboxes opening one LMDB dir fail with "Resource temporarily
# unavailable", and frecency is per-workspace anyway.
ENV FFF_FRECENCY_DB=/home/agent/.cache/fff/frecency
ENV FFF_HISTORY_DB=/home/agent/.cache/fff/history

CMD ["pi"]
