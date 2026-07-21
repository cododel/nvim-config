local tmp_dir = vim.fn.tempname()
vim.fn.mkdir(tmp_dir, "p")
local cache_path = tmp_dir .. "/deps-cache.json"

local present = {
  lazygit = true,
  rg = true,
}
local path_exists = {}
local executable_calls = 0
local notifications = {}
local file_store = {}

local deps = dofile(vim.fn.getcwd() .. "/lua/cododel/deps.lua")
deps._reset_for_tests()

local function setup_io()
  deps.setup({
    executable = function(name)
      executable_calls = executable_calls + 1
      return present[name] == true
    end,
    exepath = function(name)
      if present[name] then
        return "/bin/" .. name
      end
      return ""
    end,
    fs_stat = function(path)
      if path_exists[path] or file_store[path] then
        return { type = "file" }
      end
      return nil
    end,
    cache_path = cache_path,
    notify = function(msg, level)
      notifications[#notifications + 1] = { msg = msg, level = level }
    end,
    now = function()
      return 1700000000
    end,
    read_file = function(path)
      return file_store[path]
    end,
    write_file = function(path, content)
      file_store[path] = content
      path_exists[path] = true
    end,
  })
end

setup_io()

-- install is required
local ok_no_install, err_no_install = pcall(function()
  deps.need({ bin = "no-install", feature = "Broken" })
end)
assert(not ok_no_install, "need without install errors")
assert(tostring(err_no_install):find("install", 1, true), "error mentions install")

-- need registers; duplicate id merges, not duplicates
deps.need({
  id = "lazygit",
  bin = "lazygit",
  level = "error",
  feature = "Git review",
  install = "brew install lazygit",
})
deps.need({
  id = "lazygit",
  bin = "lazygit",
  feature = "Git review mode",
  install = "brew install lazygit",
})
deps.need({
  bin = "rg",
  level = "error",
  feature = "Search",
  install = "brew install ripgrep",
})
deps.need({
  bin = "missing-bin",
  level = "warn",
  feature = "Optional tool",
  install = "install me",
})

local status = deps.status()
local count = 0
for _ in pairs(status.registry) do
  count = count + 1
end
assert(count == 3, "registry has three unique ids")
assert(status.registry.lazygit.feature == "Git review mode", "duplicate need merges feature")
assert(status.registry.lazygit.install == "brew install lazygit", "install is stored")

-- run with missing → notify includes install command
notifications = {}
executable_calls = 0
local report = deps.run()
assert(report ~= nil, "run returns report")
assert(#report.missing == 1, "one missing dep")
assert(report.missing[1].bin == "missing-bin", "missing bin reported")
assert(report.missing[1].install == "install me", "missing carries install")
assert(report.missing[1].level == "warn", "missing level preserved")
assert(#notifications == 1, "notify once for missing")
assert(notifications[1].msg:find("missing-bin", 1, true), "notify mentions missing bin")
assert(notifications[1].msg:find("Optional tool", 1, true), "notify mentions feature")
assert(notifications[1].msg:find("install me", 1, true), "notify mentions install command")

local cached = file_store[cache_path]
assert(cached ~= nil, "cache written")
assert(cached:find("lazygit", 1, true), "ok bins cached")
assert(not cached:find("missing-bin", 1, true), "failed bins not cached")

-- mark cached paths as existing for hit path
path_exists["/bin/lazygit"] = true
path_exists["/bin/rg"] = true

-- second run without force is once-guard (no re-probe)
notifications = {}
executable_calls = 0
local report2 = deps.run()
assert(report2 == report, "second run returns same report without force")
assert(executable_calls == 0, "once-guard skips probes")
assert(#notifications == 0, "silent when already ran")

-- force recheck with cache hits skips executable for present cached paths
deps._reset_for_tests()
setup_io()

deps.need({
  id = "lazygit",
  bin = "lazygit",
  level = "error",
  feature = "Git review",
  install = "brew install lazygit",
})
deps.need({
  bin = "rg",
  level = "error",
  feature = "Search",
  install = "brew install ripgrep",
})
deps.need({
  bin = "missing-bin",
  level = "warn",
  feature = "Optional tool",
  install = "install me",
})

notifications = {}
executable_calls = 0
file_store[cache_path] = vim.json.encode({
  version = 1,
  bins = {
    lazygit = { path = "/bin/lazygit", checked_at = 1 },
    rg = { path = "/bin/rg", checked_at = 1 },
  },
})
path_exists["/bin/lazygit"] = true
path_exists["/bin/rg"] = true

local report3 = deps.run()
assert(#report3.missing == 1, "cache hit still reports uncached missing")
assert(executable_calls == 1, "executable only for uncached missing-bin")

-- gone path → recheck via executable
file_store[cache_path] = vim.json.encode({
  version = 1,
  bins = {
    lazygit = { path = "/bin/lazygit", checked_at = 1 },
    rg = { path = "/bin/rg", checked_at = 1 },
  },
})
path_exists["/bin/lazygit"] = false
path_exists["/bin/rg"] = true
present.lazygit = true

deps._reset_for_tests()
setup_io()
deps.need({
  id = "lazygit",
  bin = "lazygit",
  level = "error",
  feature = "Git review",
  install = "brew install lazygit",
})
deps.need({
  bin = "rg",
  level = "error",
  feature = "Search",
  install = "brew install ripgrep",
})

executable_calls = 0
local report4 = deps.run()
assert(report4.ok_count == 2, "both ok after recheck")
assert(executable_calls >= 1, "stale lazygit path triggers executable")

-- force ignores cache
deps.clear_cache()
file_store[cache_path] = nil
path_exists["/bin/lazygit"] = true
path_exists["/bin/rg"] = true
deps.need({
  id = "lazygit",
  bin = "lazygit",
  level = "error",
  feature = "Git review",
  install = "brew install lazygit",
})
deps.need({
  bin = "rg",
  level = "error",
  feature = "Search",
  install = "brew install ripgrep",
})
deps.need({
  bin = "delta",
  level = "warn",
  feature = "Pager",
  install = "brew install git-delta",
})
present.delta = false

executable_calls = 0
notifications = {}
local forced = deps.run({ force = true })
assert(#forced.missing == 1, "force run finds missing delta")
assert(forced.missing[1].bin == "delta", "force reports delta")
assert(forced.missing[1].install == "brew install git-delta", "force report includes install")
assert(executable_calls == 3, "force probes every registered bin")

-- ensure
present.lazygit = true
path_exists["/bin/lazygit"] = true
assert(deps.ensure("lazygit") == true, "ensure true for ok")
present["missing-bin"] = false
assert(deps.ensure("missing-bin") == false, "ensure false for missing")

-- level error in report
deps._reset_for_tests()
file_store = {}
path_exists = {}
present = {}
notifications = {}
setup_io()
deps.need({
  bin = "codex",
  level = "error",
  feature = "AI sidebar",
  install = "install Codex CLI",
})
local err_report = deps.run()
assert(err_report.has_error == true, "error-level missing sets has_error")
assert(notifications[1].level == vim.log.levels.ERROR, "error report uses ERROR notify level")
assert(notifications[1].msg:find("install Codex CLI", 1, true), "error report shows install")

print("deps_spec: ok")
