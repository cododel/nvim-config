local M = {}

local CACHE_VERSION = 1

local state = {
  registry = {},
  results = {},
  cache = nil,
  ran = false,
  last_report = nil,
  io = nil,
  commands_created = false,
}

local function default_cache_path()
  return vim.fn.stdpath("config") .. "/state/deps-cache.json"
end

local function ensure_io()
  if state.io then
    return state.io
  end

  M.setup({})
  return state.io
end

local function normalize_spec(spec)
  if type(spec) ~= "table" then
    error("cododel.deps.need: expected table { bin, install, ... }")
  end

  if type(spec.bin) ~= "string" or spec.bin == "" then
    error("cododel.deps.need: bin is required (non-empty string)")
  end

  -- install is the user-facing install command shown when the dep is missing.
  -- hint is accepted as a legacy alias.
  local install = spec.install or spec.hint
  if type(install) ~= "string" or vim.trim(install) == "" then
    error(
      "cododel.deps.need: install is required for '"
        .. spec.bin
        .. "' (e.g. install = \"brew install "
        .. spec.bin
        .. "\")"
    )
  end

  local id = spec.id or spec.bin
  local level = spec.level or "warn"
  if level ~= "error" and level ~= "warn" then
    level = "warn"
  end

  return {
    id = id,
    bin = spec.bin,
    level = level,
    feature = spec.feature or id,
    install = vim.trim(install),
    check = spec.check,
  }
end

function M.need(spec)
  local entry = normalize_spec(spec)
  local existing = state.registry[entry.id]
  if existing then
    -- Merge: later non-nil fields win (same id from multiple sites).
    for key, value in pairs(entry) do
      if value ~= nil then
        existing[key] = value
      end
    end
    return existing
  end

  state.registry[entry.id] = entry
  return entry
end

local function read_cache()
  local io = ensure_io()
  local path = io.cache_path
  local raw = io.read_file(path)
  if not raw or raw == "" then
    return { version = CACHE_VERSION, bins = {} }
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" or type(decoded.bins) ~= "table" then
    return { version = CACHE_VERSION, bins = {} }
  end

  decoded.version = CACHE_VERSION
  return decoded
end

local function write_cache(cache)
  local io = ensure_io()
  local path = io.cache_path
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir ~= "" then
    vim.fn.mkdir(dir, "p")
  end

  local payload = vim.json.encode({
    version = CACHE_VERSION,
    bins = cache.bins or {},
  })
  io.write_file(path, payload)
end

local function cache_hit(cache, id)
  local io = ensure_io()
  local entry = cache.bins and cache.bins[id]
  if not entry or type(entry.path) ~= "string" or entry.path == "" then
    return false, nil
  end

  if not io.fs_stat(entry.path) then
    return false, nil
  end

  return true, entry.path
end

local function probe(entry)
  local io = ensure_io()

  if type(entry.check) == "function" then
    local ok, path_or_err = entry.check()
    if ok then
      local path = type(path_or_err) == "string" and path_or_err or io.exepath(entry.bin)
      if path == "" then
        path = entry.bin
      end
      return true, path
    end
    return false, nil
  end

  if not io.executable(entry.bin) then
    return false, nil
  end

  local path = io.exepath(entry.bin)
  if path == "" then
    path = entry.bin
  end
  return true, path
end

local function ordered_ids()
  local ids = {}
  for id in pairs(state.registry) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  return ids
end

local function build_report(results)
  local missing = {}
  local ok_count = 0
  local has_error = false

  for _, id in ipairs(ordered_ids()) do
    local result = results[id]
    local entry = state.registry[id]
    if result and result.ok then
      ok_count = ok_count + 1
    else
      missing[#missing + 1] = {
        id = id,
        bin = entry.bin,
        level = entry.level,
        feature = entry.feature,
        install = entry.install,
      }
      if entry.level == "error" then
        has_error = true
      end
    end
  end

  return {
    ok_count = ok_count,
    missing = missing,
    has_error = has_error,
  }
end

local function format_report(report)
  if #report.missing == 0 then
    return "Cododel deps: all " .. report.ok_count .. " ok"
  end

  local lines = {
    string.format("Cododel deps: %d missing", #report.missing),
  }

  for _, item in ipairs(report.missing) do
    local mark = item.level == "error" and "✗" or "!"
    lines[#lines + 1] = string.format(
      "  %s %s (%s) — %s",
      mark,
      item.bin,
      item.feature,
      item.install
    )
  end

  return table.concat(lines, "\n")
end

local function notify_report(report, force)
  if #report.missing == 0 and not force then
    return
  end

  local io = ensure_io()
  local level = report.has_error and vim.log.levels.ERROR or vim.log.levels.WARN
  if #report.missing == 0 then
    level = vim.log.levels.INFO
  end
  io.notify(format_report(report), level)
end

function M.run(opts)
  opts = opts or {}
  local force = opts.force == true

  if state.ran and not force then
    return state.last_report
  end

  local cache = force and { version = CACHE_VERSION, bins = {} } or read_cache()
  if force then
    -- Keep file empty until rewrite; still allow probing everything.
    cache.bins = {}
  end

  local results = {}
  local next_bins = {}
  local io = ensure_io()
  local now = io.now()

  for _, id in ipairs(ordered_ids()) do
    local entry = state.registry[id]
    local ok = false
    local path = nil

    if not force then
      local hit, cached_path = cache_hit(cache, id)
      if hit then
        ok = true
        path = cached_path
      end
    end

    if not ok then
      ok, path = probe(entry)
    end

    results[id] = {
      ok = ok,
      path = path,
      level = entry.level,
      feature = entry.feature,
      from_cache = ok and path ~= nil and not force and select(1, cache_hit(read_cache(), id)),
    }

    -- Recompute from_cache without second read: track during hit path.
    if ok and path then
      next_bins[id] = {
        path = path,
        checked_at = now,
      }
    end
  end

  -- Accurate from_cache flag for tests/status
  local prior = force and { bins = {} } or cache
  for id, result in pairs(results) do
    if result.ok and result.path and prior.bins and prior.bins[id] and prior.bins[id].path == result.path then
      local hit = ensure_io().fs_stat(result.path)
      result.from_cache = hit ~= nil and not force
    else
      result.from_cache = false
    end
  end

  state.results = results
  state.cache = { version = CACHE_VERSION, bins = next_bins }
  write_cache(state.cache)

  local report = build_report(results)
  state.last_report = report
  state.ran = true
  notify_report(report, force)
  return report
end

function M.ensure(id)
  if type(id) ~= "string" or id == "" then
    return false
  end

  local entry = state.registry[id]
  if not entry then
    -- Unregistered id: still probe by bin name = id.
    entry = { id = id, bin = id, level = "warn", feature = id }
  end

  local result = state.results[id]
  if result then
    return result.ok == true
  end

  local cache = read_cache()
  local hit, path = cache_hit(cache, id)
  if hit then
    state.results[id] = {
      ok = true,
      path = path,
      level = entry.level,
      feature = entry.feature,
      from_cache = true,
    }
    return true
  end

  local ok, resolved = probe(entry)
  state.results[id] = {
    ok = ok,
    path = resolved,
    level = entry.level,
    feature = entry.feature,
    from_cache = false,
  }

  if ok and resolved then
    cache.bins = cache.bins or {}
    cache.bins[id] = {
      path = resolved,
      checked_at = ensure_io().now(),
    }
    write_cache(cache)
  end

  return ok
end

function M.status()
  return {
    registry = state.registry,
    results = state.results,
    last_report = state.last_report,
    ran = state.ran,
    cache_path = ensure_io().cache_path,
  }
end

function M.clear_cache()
  local io = ensure_io()
  local path = io.cache_path
  if io.fs_stat(path) then
    pcall(vim.fn.delete, path)
  end
  state.cache = { version = CACHE_VERSION, bins = {} }
  state.results = {}
  state.ran = false
  state.last_report = nil
end

function M.last_report()
  return state.last_report
end

function M._reset_for_tests()
  state.registry = {}
  state.results = {}
  state.cache = nil
  state.ran = false
  state.last_report = nil
  state.io = nil
end

local function default_read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function default_write_file(path, content)
  local f, err = io.open(path, "w")
  if not f then
    error("cododel.deps: cannot write cache: " .. tostring(err))
  end
  f:write(content)
  f:close()
end

function M.setup(options)
  options = options or {}

  state.io = {
    executable = options.executable or function(bin)
      return vim.fn.executable(bin) == 1
    end,
    exepath = options.exepath or function(bin)
      return vim.fn.exepath(bin)
    end,
    fs_stat = options.fs_stat or function(path)
      return vim.uv.fs_stat(path)
    end,
    cache_path = options.cache_path or default_cache_path(),
    notify = options.notify or vim.notify,
    now = options.now or function()
      return os.time()
    end,
    read_file = options.read_file or default_read_file,
    write_file = options.write_file or default_write_file,
  }

  if state.commands_created then
    return
  end

  state.commands_created = true

  vim.api.nvim_create_user_command("CododelDepsCheck", function(command)
    if command.bang then
      M.clear_cache()
      M.run({ force = true })
    elseif state.ran and state.last_report then
      ensure_io().notify(format_report(state.last_report), vim.log.levels.INFO)
    else
      M.run()
    end
  end, {
    bang = true,
    desc = "Show Cododel dependency status (:CododelDepsCheck! forces recheck)",
  })

  vim.api.nvim_create_user_command("CododelDepsClear", function()
    M.clear_cache()
    ensure_io().notify("Cododel deps cache cleared", vim.log.levels.INFO)
  end, {
    desc = "Clear Cododel dependency cache",
  })
end

return M
