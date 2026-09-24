.pragma library

function emptyState() {
  return {
    "schemaVersion": 1,
    "generatedAt": "",
    "installed": false,
    "cliVersion": "",
    "loggedIn": false,
    "profile": "",
    "account": null,
    "counts": {},
    "recommendations": [],
    "warnings": []
  }
}

function parseState(raw) {
  var fallback = emptyState()
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return fallback
    return parsed
  } catch (error) {
    fallback.warnings = ["OmWhop returned invalid status data."]
    return fallback
  }
}

function count(state, key) {
  if (!state || !state.counts) return null
  var value = state.counts[key]
  if (value === null || value === undefined) return null
  var number = Number(value)
  return isFinite(number) ? number : null
}

function countLabel(state, key) {
  var value = count(state, key)
  if (value === null) return "—"
  return String(value) + (value === 1 ? " item" : " items")
}

function accountTitle(state) {
  if (!state) return "Whop"
  if (state.account && state.account.title) return String(state.account.title)
  if (state.loggedIn === true) return "Select a business"
  return "Whop"
}

function statusLabel(state) {
  if (!state) return "Loading"
  if (state.installed !== true) return "CLI required"
  if (state.loggedIn !== true) return "Sign in required"
  if (state.account && state.account.id) return "Connected"
  return "Choose a business"
}

function iconFor(state) {
  if (!state || state.installed !== true) return "!"
  if (state.loggedIn !== true || !state.account || !state.account.id) return "?"
  return "W"
}

function iconColor(state, foreground, urgent) {
  if (!state) return foreground
  if (state.installed !== true || state.loggedIn !== true || !state.account || !state.account.id) return urgent
  return foreground
}

function firstWarning(state) {
  if (!state || !state.warnings || state.warnings.length === 0) return ""
  return String(state.warnings[0] || "")
}

function recommendationTitle(item) {
  if (!item) return "Recommendation"
  var title = String(item.title || "").trim()
  return title !== "" ? title : "Recommendation"
}

function recommendationDescription(item) {
  if (!item) return ""
  return String(item.description || "").trim()
}

function recommendationMeta(item) {
  if (!item) return ""
  var values = []
  var priority = String(item.priority || "").trim()
  var status = String(item.status || "").trim()
  if (priority !== "") values.push(priority)
  if (status !== "") values.push(status)
  return values.join(" · ")
}
