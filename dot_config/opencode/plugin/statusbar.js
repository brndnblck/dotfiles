export const StatusBarPlugin = async ({ app, client, $ }) => {
  let currentStats = {
    model: null,
    provider: null,
    totalCost: 0,
    tokenCount: 0,
    requestCount: 0,
    sessionStart: Date.now()
  };

  // Get real usage data from APIs
  const getClaudeUsage = async () => {
    try {
      // Use ccusage for Claude Code usage analysis (already installed)
      const result = await $`ccusage session --json --today`;
      const usage = JSON.parse(result.stdout || '[]');
      return usage.length > 0 ? {
        cost: usage.reduce((sum, s) => sum + (s.cost || 0), 0),
        tokens: usage.reduce((sum, s) => sum + (s.input_tokens || 0) + (s.output_tokens || 0), 0)
      } : { cost: 0, tokens: 0 };
    } catch (e) {
      return { cost: 0, tokens: 0 };
    }
  };

  const getOpenAIUsage = async () => {
    try {
      const today = new Date().toISOString().split('T')[0];
      const apiKey = process.env.OPENAI_API_KEY || await $`echo $OPENAI_API_KEY`.then(r => r.stdout.trim());
      
      if (!apiKey) return { cost: 0, tokens: 0 };

      // OpenAI Usage API call
      const response = await fetch(`https://api.openai.com/v1/usage?date=${today}`, {
        headers: { 'Authorization': `Bearer ${apiKey}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        return {
          cost: data.total_usage?.reduce((sum, usage) => sum + (usage.cost || 0), 0) || 0,
          tokens: data.total_usage?.reduce((sum, usage) => sum + (usage.n_requests || 0), 0) || 0
        };
      }
    } catch (e) {
      // Fallback to estimates if API fails
    }
    return { cost: 0, tokens: 0 };
  };

  // Update status display with real usage data
  const updateStatus = async () => {
    // Get real usage data based on current provider
    let usage = { cost: 0, tokens: 0 };
    
    if (currentStats.provider === 'anthropic') {
      usage = await getClaudeUsage();
    } else if (currentStats.provider === 'openai') {
      usage = await getOpenAIUsage();
    }
    
    // Update stats with real data
    currentStats.totalCost = usage.cost;
    currentStats.tokenCount = usage.tokens;
    
    const statusLine = `📊 ${currentStats.provider || 'Unknown'} | ${currentStats.model || 'Unknown'} | Requests: ${currentStats.requestCount} | Tokens: ${currentStats.tokenCount} | Cost: $${currentStats.totalCost.toFixed(4)}`;
    
    // Write to status file
    await $`echo "${statusLine}" > ~/.config/opencode/status.txt`;
    
    // Display in terminal title
    try {
      await $`printf "\\033]0;OpenCode - ${statusLine}\\007"`;
    } catch (e) {
      // Ignore if terminal doesn't support title setting
    }
  };

  return {
    // Track model usage on tool execution
    "tool.execute.before": async (input, output) => {
      currentStats.requestCount++;
      
      // Extract model info from context if available
      if (input.context?.model) {
        currentStats.model = input.context.model;
        currentStats.provider = input.context.model.split('/')[0];
      }
    },

    "tool.execute.after": async (input, output) => {
      // Update status with real usage data
      await updateStatus();
    },

    // Reset stats on new session
    event: async ({ event }) => {
      if (event.type === "session.start") {
        currentStats = {
          model: null,
          provider: null,
          totalCost: 0,
          tokenCount: 0,
          requestCount: 0
        };
        await updateStatus();
      }

      if (event.type === "session.idle") {
        // Final status update
        await updateStatus();
        await $`terminal-notifier -message "Session completed - $${currentStats.totalCost.toFixed(4)} total cost" -title "OpenCode Status" -sound default`;
      }
    }
  };
};