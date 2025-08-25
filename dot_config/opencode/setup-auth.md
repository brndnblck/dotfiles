# OpenCode Authentication Setup

## Environment Variables Required

To use the templated auth.json, set these environment variables in your shell profile:

```bash
# Add to ~/.zshrc or ~/.bashrc
export OPENAI_API_KEY="your-openai-api-key"
export ANTHROPIC_API_KEY="your-anthropic-api-key"  # Optional if using auth login
```

## After Setting Environment Variables

1. Reload your shell or source the profile:
   ```bash
   source ~/.zshrc
   ```

2. Re-apply the chezmoi template:
   ```bash
   chezmoi apply ~/.local/share/opencode/auth.json
   ```

3. Verify the configuration:
   ```bash
   opencode auth list
   ```

## Provider Priorities

1. **Anthropic**: Use `opencode auth login` for Pro accounts (recommended)
2. **OpenAI**: Use environment variable `OPENAI_API_KEY`
3. **Ollama**: Automatically configured for local models

## Security Notes

- The auth.json file is managed as a private template with 600 permissions
- API keys are never stored in the git repository
- Chezmoi will prevent accidental commits of sensitive credentials