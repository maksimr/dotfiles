FROM docker/sandbox-templates:shell-docker

USER root
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
 && rm -rf /var/lib/apt/lists/* && ssh-keygen -A && passwd -d agent

# sshd over `docker exec` stdio (no open port). agent has an empty password, so
# no key is needed: reaching it already requires docker socket access.
RUN printf '#!/bin/sh\nmkdir -p /run/sshd\nexec /usr/sbin/sshd -i -o UsePAM=no -o PasswordAuthentication=yes -o PermitEmptyPasswords=yes\n' \
      > /usr/local/bin/sshd-stdio && chmod 755 /usr/local/bin/sshd-stdio

RUN echo 'unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY XAI_API_KEY NEBIUS_API_KEY MISTRAL_API_KEY' >> /etc/sandbox-persistent.sh

USER agent
RUN curl -fsSL https://raw.githubusercontent.com/maksimr/dotfiles/main/.pi/scripts/install_pi.sh | bash

CMD ["pi"]
