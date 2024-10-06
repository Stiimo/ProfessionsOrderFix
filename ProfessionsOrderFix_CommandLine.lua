-- Extract version from the toc file
local addonName = ...
local addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version")

-- Register the slash commands
SLASH_PROFESSIONSORDERFIX1 = "/pof"

-- Command handler function
SlashCmdList["PROFESSIONSORDERFIX"] = function(msg)
    local command = string.lower(msg)

    if command == "help" then
        ProfessionsOrderFix_ShowHelp()
    elseif command == "version" then
        ProfessionsOrderFix_ShowVersion()
    elseif command == "toggle" then
        ProfessionsOrderFix_ToggleWindow()
    else
        print("Professions Order Fix: Unknown command. Type '/pof help' for available commands.")
    end
end

-- Help function
function ProfessionsOrderFix_ShowHelp()
    print("Professions Order Fix Commands:")
    print("/pof help - Show this help message.")
    print("/pof version - Show addon version.")
    print("/pof toggle - Open or close the Professions Order Fix window.")
end

-- Info/Version function
function ProfessionsOrderFix_ShowVersion()
    print("Professions Order Fix, Version: " .. addonVersion)
end

-- Function to open/close the window
function ProfessionsOrderFix_ToggleWindow()
    if ProfessionsOrderFix_ProfessionsFrame:IsShown() then
        HideUIPanel(ProfessionsOrderFix_ProfessionsFrame)
    elseif ProfessionsOrderFix_ProfessionsFrame:IfShouldBeClosed() then
        print("Professions Order Fix window can only be openend along with Blizzard's Professions Frame on Orders Tab.")
    else
        ShowUIPanel(ProfessionsOrderFix_ProfessionsFrame)
    end
end
