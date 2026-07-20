FROM docker/sandbox-templates:shell-docker

USER root
RUN uv tool install --python 3.13 "headroom-ai[all]"
RUN npm install -g --fetch-timeout=600000 @earendil-works/pi-coding-agent
RUN echo 'unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY XAI_API_KEY NEBIUS_API_KEY MISTRAL_API_KEY' >> /etc/sandbox-persistent.sh

USER agent
RUN npm install -g --maxsockets=1 --fetch-timeout=600000 github:maksimr/udot
RUN udot use https://github.com/maksimr/dotfiles