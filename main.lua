--STABLE
local M = {}

-- Get selected files
local get_files = ya.sync(function()
	if not cx or not cx.active then
		return {}
	end

	local files = {}
	if cx.active.selected and #cx.active.selected > 0 then
		for _, url in pairs(cx.active.selected) do
			files[#files + 1] = tostring(url)
		end
	elseif cx.active.current and cx.active.current.hovered then
		files[1] = tostring(cx.active.current.hovered.url)
	end

	return files
end)

-- Get hovered file
local get_hovered_file = ya.sync(function()
	if cx and cx.active and cx.active.current and cx.active.current.hovered then
		return tostring(cx.active.current.hovered.url)
	end
	return nil
end)

-- Entry point
function M:entry(job)
	local action = job.args and job.args[1]

	if action == "add" then
		return self:add()
	elseif action == "filter" then
		return self:filter()
	elseif action == "remove" then
		return self:remove()
	elseif action == "list" then
		return self:list()
	elseif action == "common" then
		return self:common()
	else
		ya.notify({
			title = "TMSU",
			content = "Unknown action: " .. tostring(action),
			timeout = 3,
			level = "error",
		})
	end
end

-- Add tags
function M:add()
	local files = get_files()

	if not files or #files == 0 then
		return ya.notify({ title = "TMSU", content = "No files selected", timeout = 3, level = "warning" })
	end

	-- FIXED: Handle both value and event
	local value, event = ya.input({
		title = "Add tags",
		placeholder = "tag1 tag2 tag3",
		position = { "top-center", y = 3, w = 40 }, -- Note: 'position' is often preferred over 'pos' in newer versions
	})

	if event ~= 1 or not value or value == "" then
		return
	end

	local tags = {}
	for tag in value:gmatch("%S+") do
		tags[#tags + 1] = tag
	end

	for _, file in ipairs(files) do
		local cmd = Command("tmsu"):arg("tag"):arg(file)

		for _, tag in ipairs(tags) do
			cmd:arg(tag)
		end

		local status = cmd:spawn():wait()

		if not status or not status.success then
			return ya.notify({ title = "TMSU", content = "Failed tagging: " .. file, timeout = 5, level = "error" })
		end
	end

	ya.notify({ title = "TMSU", content = "Tags added", timeout = 3 })
end

-- Remove tags
function M:remove()
	local files = get_files()

	if not files or #files == 0 then
		return ya.notify({ title = "TMSU", content = "No files selected", timeout = 3, level = "warning" })
	end

	local value, event = ya.input({
		title = "Remove tags",
		placeholder = "tag1 tag2",
		position = { "top-center", y = 3, w = 40 },
	})

	if event ~= 1 or not value or value == "" then
		return
	end

	local tags = {}
	for tag in value:gmatch("%S+") do
		tags[#tags + 1] = tag
	end

	for _, file in ipairs(files) do
		local cmd = Command("tmsu"):arg("untag"):arg(file)

		for _, tag in ipairs(tags) do
			cmd:arg(tag)
		end

		local status = cmd:spawn():wait()

		if not status or not status.success then
			return ya.notify({ title = "TMSU", content = "Failed removing tags", timeout = 5, level = "error" })
		end
	end

	ya.notify({ title = "TMSU", content = "Tags removed", timeout = 3 })
end

-- Filter files by tags
function M:filter()
	local value, event = ya.input({
		title = "TMSU tag filter",
		placeholder = "Enter tags (e.g. art alien)",
		position = { "top-center", y = 3, w = 50 },
	})

	-- If cancelled, clear filter
	if event ~= 1 then
		return
	end

	local cmd = Command("tmsu"):arg("files")
	for tag in value:gmatch("%S+") do
		cmd:arg(tag)
	end

	local output = cmd:stdout(Command.PIPED):spawn():wait_with_output()

	if not output or not output.status.success or output.stdout == "" then
		return ya.notify({ title = "TMSU", content = "No files found", timeout = 3, level = "warn" })
	end

	local filenames, others = {}, {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local clean = line:gsub("^%./", "")
		if clean:find("/") then
			table.insert(others, line)
		else
			table.insert(filenames, clean)
		end
	end

	if #filenames > 0 then
		local patterns = {}
		for _, f in ipairs(filenames) do
			local escaped = f:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "\\%1")
			table.insert(patterns, "^" .. escaped .. "$")
		end
		local pattern = table.concat(patterns, "|")

		ya.emit("filter_do", { pattern, smart = false })
		ya.notify({
			title = "TMSU Filter",
			content = "Showing " .. #filenames .. " matching files",
			timeout = 2,
		})
	end
	if #others > 0 then
		ya.notify({
			title = "Found " .. #others .. " files in others directories",
			content = table.concat(others, "\n"),
			timeout = 5,
		})
	end
end

-- List tags
function M:list()
	local files = get_files()
	if not files or #files == 0 then
		return
	end

	local unique_tags = {}
	local found_any = false

	for _, file in ipairs(files) do
		local output = Command("tmsu"):arg("tags"):arg(file):stdout(Command.PIPED):spawn():wait_with_output()

		if output and output.status.success then
			local tags_str = output.stdout:match(".*:(.*)") or ""
			for tag in tags_str:gmatch("%S+") do
				unique_tags[tag] = true
				found_any = true
			end
		end
	end

	if not found_any then
		return ya.notify({ title = "TMSU", content = "NO TAGS FOUND", timeout = 5, level = "warn" })
	end

	-- Collect keys and notify
	local result = {}
	for tag, _ in pairs(unique_tags) do
		ya.notify({
			title = "",
			content = tag,
			timeout = 3,
		})
	end
end

function M:common()
	local files = get_files()
	if not files or #files == 0 then
		return
	end

	-- If only one file, behave exactly like 'list'
	if #files == 1 then
		return self:list()
	end

	local counts = {}
	local file_count = #files
	local found_at_least_one_tag = false

	for _, file in ipairs(files) do
		local output = Command("tmsu"):arg("tags"):arg(file):stdout(Command.PIPED):spawn():wait_with_output()

		if output and output.status.success then
			local tags_str = output.stdout:match(".*:(.*)") or ""
			local seen_in_file = {}
			for tag in tags_str:gmatch("%S+") do
				if not seen_in_file[tag] then
					counts[tag] = (counts[tag] or 0) + 1
					seen_in_file[tag] = true
					found_at_least_one_tag = true
				end
			end
		end
	end

	local has_common = false
	for tag, count in pairs(counts) do
		if count == file_count then
			has_common = true
			ya.notify({
				title = "Common tags",
				content = tag,
				timeout = 5,
			})
		end
	end

	-- If we searched multiple files but found no commonality
	if not has_common then
		ya.notify({
			title = "TMSU",
			content = "NO common tags",
			timeout = 3,
			level = "warn",
		})
	end
end

return M
