local _, core = ...

local setmetatable = setmetatable
local tostring, format = tostring, string.format
local rawset, rawget = rawset, rawget
local L = setmetatable({}, {
	__newindex = function(self, key, value)
		rawset(self, key, value == true and key or value)
	end,
	__index = function(self, key)
		return key
	end
})
function L:F(line, ...)
	line = L[line]
	return format(line, ...)
end
core.L = L


-- common
L["Appearance"] = true
L["Configuration Mode"] = true
L["Enable"] = true
L["Font Outline"] = true
L["Font Size"] = true
L["Font"] = true
L["Height"] = true
L["Hide Title"] = true
L["Icon Size"] = true
L["Left to right"] = true
L["Lock"] = true
L["Monochrome"] = true
L["Orientation"] = true
L["Outline"] = true
L["Outlined monochrome"] = true
L["Right to left"] = true
L["Scale"] = true
L["Spacing"] = true
L["Texture"] = true
L["Thick outline"] = true
L["Thin outline"] = true
L["Update Frequency"] = true
L["Width"] = true
L["Are you sure you want to reset %s to default?"] = true
L["Enable this if you want to hide the title text when locked."] = true
L["Toggle configuration mode to allow moving frames and setting appearance options."] = true

-- raid menu
L["Raid Menu"] = true
L["Disband Group"] = true
L["Are you sure you want to disband the group?"] = true

-- auto invites
L["Auto Invites"] = true
L["Quick Invites"] = true
L["Invite guild"] = true
L["Invite everyone in your guild at the maximum level."] = true
L["Invite zone"] = true
L["Invite everyone in your guild who are in the same zone as you."] = true
L["Keyword Invites"] = true
L["Keyword"] = true
L["Anyone who whispers you this keyword will automatically and immediately be invited to your group."] = true
L["Guild Keyword"] = true
L["Any guild member who whispers you this keyword will automatically and immediately be invited to your group."] = true
L["Rank Invites"] = true
L["Clicking any of the buttons below will invite anyone of the selected rank AND HIGHER to your group. So clicking the 3rd button will invite anyone of rank 1, 2 or 3, for example. It will first post a message in either guild or officer chat and give your guild members 10 seconds to leave their groups before doing the actual invites."] = true
L["Invite all guild members of rank %s or higher."] = true
L["Sorry, the group is full."] = true
L["All max level characters will be invited to raid in 10 seconds. Please leave your groups."] = true
L["All characters in %s will be invited to raid in 10 seconds. Please leave your groups."] = true
L["All characters of rank %s or higher will be invited to raid in 10 seconds. Please leave your groups."] = true

-- paladin auras
L["Paladin Auras"] = true

-- sunder armor
L["Report"] = true

-- healers mana
L["Healers Mana"] = true

-- raid cooldown
L["Raid Cooldowns"] = true
L["Spawn Test bars"] = true
L["Class color"] = true
L["Custom color"] = true
L["Max Bars"] = true
L["Grow Upwards"] = true
L["Show"] = true
L["Only show my spells"] = true
L["Never show my spells"] = true
L["Icon"] = true
L["Duration"] = true