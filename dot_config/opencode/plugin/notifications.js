export const NotificationPlugin = async ({ client, $ }) => {
  let sessionStartTime = Date.now();
  
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        const sessionDuration = Date.now() - sessionStartTime;
        if (sessionDuration > 10000) {
          await $`terminal-notifier -message "Long session completed!" -title "opencode" -sound default`
        }
      }
      if (event.type === "session.error") {
        await $`terminal-notifier -message "Session encountered an error" -title "opencode" -sound Basso`
      }
      if (event.type === "approval.required") {
        await $`terminal-notifier -message "Waiting for your approval..." -title "opencode" -sound Ping`
      }
      if (event.type === "approval.granted") {
        await $`terminal-notifier -message "Approval granted - continuing..." -title "opencode" -sound Glass`
      }
      if (event.type === "approval.denied") {
        await $`terminal-notifier -message "Request denied" -title "opencode" -sound Basso`
      }
    },
    
    "tool.execute.before": async (input) => {
      if (input.tool === "edit" || input.tool === "write") {
        await $`terminal-notifier -message "Requesting permission for ${input.tool}" -title "opencode" -sound Ping`
      }
    },
    
    "tool.execute.after": async (input, output) => {
      if (input.tool === "write" || input.tool === "edit") {
        await $`terminal-notifier -message "File ${input.tool} completed" -title "opencode" -sound Glass`
      }
      
      if (input.tool === "bash" && output.duration > 5000) {
        await $`terminal-notifier -message "Long command completed" -title "opencode" -sound Blow`
      }
    }
  }
}