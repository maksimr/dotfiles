FROM docker/sandbox-templates:shell-docker

USER root
RUN echo 'unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY XAI_API_KEY NEBIUS_API_KEY MISTRAL_API_KEY' >> /etc/sandbox-persistent.sh

USER agent
RUN curl -sL https://raw.githubusercontent.com/maksimr/dotfiles/main/.local/bin/udot | bash -s -- use https://github.com/maksimr/dotfiles --only .pi --only .local/bin
RUN ~/.pi/scripts/install_pi.sh