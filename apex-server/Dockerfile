FROM python:3.11-slim

WORKDIR /app

# System dependencies + CLI tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js (för npm, railway cli)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh

# Railway CLI
RUN npm install -g @railway/cli

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App
COPY . .

# Storage directory (mountas som Railway Volume vid runtime)
RUN mkdir -p /app/storage

# Git config (för commits)
RUN git config --global user.email "ai@apex.dev" \
    && git config --global user.name "Apex AI"

EXPOSE 8000

ENV PORT=8000
CMD uvicorn main:app --host 0.0.0.0 --port $PORT
