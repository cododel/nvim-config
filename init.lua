-- Defaults + optional overrides in config.settings (must run before lazy so
-- plugin specs register the configured AI binary with cododel.deps).
require("cododel.options")
require("config.settings")
require("config.lazy")
require("config.highlights")
require("config.keymaps")

-- After all plugin specs and keymaps registered their external deps.
require("cododel.deps").run()
