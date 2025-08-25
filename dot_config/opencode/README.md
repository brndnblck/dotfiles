# OpenCode Configuration

This directory contains configuration for OpenCode AI coding agent.

## Setup

### 1. Authentication Setup

OpenCode supports multiple authentication methods depending on the provider:

#### Anthropic (Recommended - Pro Account)
Use opencode's built-in authentication:
```bash
opencode auth login
```
Choose Anthropic and follow the prompts to authenticate with your Pro account.

#### OpenAI (API Key)
Set your OpenAI API key as an environment variable:
```bash
export OPENAI_API_KEY="your-openai-api-key-here"
```
Add this to your shell profile (`~/.zshrc`, `~/.bashrc`) for persistence.

#### Ollama (Local Models)
Install and start Ollama:
```bash
brew install ollama
ollama serve
```

Pull desired models:
```bash
ollama pull llama3.2
ollama pull llama3.1
ollama pull codellama
```

### 2. Provider Configuration

Authentication credentials are managed through:
- **auth.json**: Located at `~/.local/share/opencode/auth.json` (managed by chezmoi template)
- **Environment variables**: For API keys (OPENAI_API_KEY, ANTHROPIC_API_KEY)
- **Built-in auth**: For Anthropic Pro accounts via `opencode auth login`

### 3. Switching Models

Change the `model` field in `opencode.json` to use different providers:
- **Anthropic**: `anthropic/claude-sonnet-4-20250514`
- **OpenAI**: `openai/gpt-4`, `openai/o1-preview`
- **Ollama**: `ollama/llama3.2`, `ollama/codellama`

## Configuration Files

- **opencode.json**: Main configuration with model settings, formatters, and rules
- **AGENTS.md**: Global agent instructions and development environment context
- **agents/**: Directory for custom agent definitions
- **rules/**: Modular rule sets including language-specific guidelines

### Rule Organization

- `rules/languages/`: Language-specific rules (Python, JavaScript, Rust, etc.)
- `rules/security.md`: Security guidelines and best practices
- `rules/code-quality.md`: General code quality standards
- `rules/documentation.md`: Documentation requirements

## XDG Compliance

OpenCode automatically uses `~/.config/opencode` which follows XDG Base Directory specification. All configuration is managed through chezmoi for consistent setup across machines.