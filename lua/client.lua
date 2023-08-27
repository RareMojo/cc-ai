-- Metadata and Constants
local authorName = "Rare Corp."
local logoArt = [[
    ___               _____            
    / _ \___ ________ / ___/__  _______ 
   / , _/ _ `/ __/ -_) /__/ _ \/ __/ _ \
  /_/|_|\_,_/_/  \__/\___/\___/_/ / .__/
                                 /_/    ]]
local productVersion = "1.0"
local productName = "CC-AI Chat Client"
local rateLimitMs = 2000 -- 2 seconds in milliseconds
local maxBufferLength = 1000 -- Limit the size of the conversation buffer
local lastRequestTime = 0
local rateLimit = 1 -- Rate limit in seconds, change as needed

-- Colors
local uiColors = {
    userNameColor = colors.gray,
    userChatColor = colors.lightBlue,
    aiNameColor = colors.gray,
    aiChatColor = colors.green,
    commandColor = colors.purple,
    errorColor = colors.red,
    systemColor = colors.yellow,
    helpColor = colors.cyan,
    logoColor = colors.purple
}

-- Configuration
local configFileName = "cc-ai_config.txt"
local config = {baseURL = "", userName = "", aiName = "", summaryThreshold = "600", apiToken = "", uiColors=uiColors}
local computerid = os.getComputerID()

-- Peripheral
local monitor = peripheral.find("monitor")

-- Buffer of conversation history
local conversationBuffer = {}
local scrollPosition = 1

-- Track if we've reached max dimensions
local reachedMaxDims = false

-- Add a variable to track cursor position
local cursorAtStartOfLine = true

-- Update and return current time
local function updateTime()
    local time = os.time()
    return textutils.formatTime(time, false)
end

-- Collect data for API
local function collectData(prompt)
    return {
        username = config.userName,
        ainame = config.aiName,
        summaryThreshold = config.summaryThreshold,
        prompt = prompt,
        gameday = os.day(),
        gametime = updateTime(),
        gameuptime = os.clock(),
        computerid = computerid or "Unknown"
    }
end

-- Validate configuration data
local function validateConfig(configData)
    -- Check baseURL
    if type(configData.baseURL) ~= "string" or configData.baseURL == "" or not configData.baseURL:match("^https?://") then
        print("Invalid baseURL.")
        return false
    end

    -- Check userName
    if type(configData.userName) ~= "string" or configData.userName == "" then
        print("Invalid userName.")
        return false
    end

    -- Check aiName
    if type(configData.aiName) ~= "string" or configData.aiName == "" then
        print("Invalid aiName.")
        return false
    end

    -- Check summaryThreshold
    local summaryThreshold = tonumber(configData.summaryThreshold)
    if summaryThreshold == nil or summaryThreshold < 0 then
        print("Invalid summaryThreshold.")
        return false
    end

    return true
end

-- Save Config to file
local function saveConfig(config)
    if validateConfig(config) then
        local configData = textutils.serializeJSON(config)
        local file = fs.open(configFileName, "w")
        file.write(configData)
        file.close()
    else
        print("Invalid configuration data.")
    end
end

-- Load Config from file
local function loadConfig()
    if fs.exists(configFileName) then
        local file = fs.open(configFileName, "r")
        local configData = file.readAll()
        file.close()
        local loadedConfig = textutils.unserializeJSON(configData)
        if validateConfig(loadedConfig) then
            config = loadedConfig
        else
            print("Invalid configuration file.")
        end
    end
end

-- Print a character to the monitor and manage line wrapping and scrolling
local function printCharToMonitor(char, x, y)
    if not monitor then
        print("Monitor not initialized.")
        return x, y
    end
    
    local width, height = monitor.getSize()
    if not width or not height then
        print("Could not retrieve monitor size.")
        return x, y
    end

    if char == "\n" then
        if cursorAtStartOfLine then
            return x, y
        end
        cursorAtStartOfLine = true
        if y < height then
            return 1, y + 1
        else
            monitor.scroll(1)
            return 1, height
        end
    else
        cursorAtStartOfLine = false
        monitor.setCursorPos(x, y)
        monitor.write(char)
        x = x + 1
        if x > width then
            if y < height then
                x = 1
                y = y + 1
            else
                monitor.scroll(1)
                x = 1
                y = height
            end
        end
        return x, y
    end
end

-- Buffer of conversation history
local conversationBuffer = {}
local scrollPosition = 1

-- Function to redraw the monitor with the conversation history
local function redrawMonitor()
    if not monitor then
        print("Monitor not initialized.")
        return
    end

    monitor.clear()
    local x, y = 1, 1
    monitor.setCursorPos(x, y)
    
    local lineCount = 0

    for i = scrollPosition, #conversationBuffer do
        local line = conversationBuffer[i]
        for _, segment in ipairs(line) do
            monitor.setTextColor(segment.color)
            for j = 1, #segment.message do
                local char = segment.message:sub(j, j)
                x, y = printCharToMonitor(char, x, y)
            end
        end
        x, y = printCharToMonitor("\n", x, y)
        lineCount = lineCount + 1

        local _, height = monitor.getSize()
        if lineCount >= height then
            scrollPosition = scrollPosition + 1
            break
        end
    end
end

-- Print message to both terminal and monitor
local function printToBoth(message, color, appendToLast)
    term.setTextColor(color)
    write(message)
    if appendToLast == nil then
        appendToLast = false
    end

    if appendToLast and #conversationBuffer > 0 then
        table.insert(conversationBuffer[#conversationBuffer], {message = message, color = color})
    else
        table.insert(conversationBuffer, {{message = message, color = color}})
    end
    redrawMonitor()
    printCharToMonitor("\n", x, y)
end

-- Print the welcome message
local function welcomeMessage()
    printToBoth(logoArt, config.uiColors.logoColor)
    printToBoth("\nWelcome to " .. productName .. " by " .. authorName .. " \n(Version " .. productVersion .. ")\n", config.uiColors.systemColor)
    printToBoth("Type /settings to change settings\n", config.uiColors.systemColor)
    printToBoth("Type /help for a list of commands\n", config.uiColors.systemColor)
    printToBoth("Type /exit to exit the program\n\n", config.uiColors.systemColor)
    printToBoth("Conversation starts here:\n", config.uiColors.aiChatColor)
end

-- Print the help message
local function printHelp()
    printToBoth("Config File:" .. configFileName .. "\n", config.uiColors.systemColor)
    printToBoth("Commands:\n", config.uiColors.systemColor)
    printToBoth("/welcome - Print the welcome message\n", config.uiColors.helpColor)
    printToBoth("/settings - Change settings\n", config.uiColors.helpColor)
    printToBoth("/token - Change the API token\n", config.uiColors.helpColor)
    printToBoth("/token reset - Reset the API token\n", config.uiColors.helpColor)
    printToBoth("/clear - Clear the chat history\n", config.uiColors.helpColor)
    printToBoth("/version - Print the version number\n", config.uiColors.helpColor)
    printToBoth("/help - Print this help message\n", config.uiColors.helpColor)
    printToBoth("/exit - Exit the program\n\n", config.uiColors.helpColor)
end

-- Read input with a prompt
local function readInput(prompt)
    term.setTextColor(colors.gray)
    write(prompt)
    
    table.insert(conversationBuffer, {{message = prompt, color = colors.gray}})
    redrawMonitor()

    local input = read()

    table.remove(conversationBuffer)
    redrawMonitor()
    
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y - 1)
    term.clearLine()
    print()
    return input
end

-- Print a message one character at a time
local function printTyping(message, color)
    if message == nil then
        return
    end
    local isFirstChar = true
    for i = 1, #message do
        local char = message:sub(i, i)
        printToBoth(char, color, not isFirstChar)
        isFirstChar = false
        sleep(0.01)
    end
    printToBoth("\n\n", color)
end

-- Send message to server and return response
local function sendMessage(prompt)
    local currentTime = os.epoch("utc")
    if currentTime - lastRequestTime < rateLimit * 1000 then
        printTyping("Rate limit exceeded. Please wait...", config.uiColors.errorColor)
        return
    end
    lastRequestTime = currentTime

    if config.baseURL == "" then
        printTyping("Error: Base URL not set.", config.uiColors.errorColor)
        return
    end
    local fullURL = config.baseURL .. "/conversation"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. config.apiToken
    }

    local collectedData = collectData()
    collectedData["prompt"] = prompt

    local body = textutils.serializeJSON(collectedData)

    local response = http.post(fullURL, body, headers)

    if response then
        local result = textutils.unserializeJSON(response.readAll())
        response.close()

        if result.summarized then
            printTyping("Summarizing response...", config.uiColors.systemColor)
            sleep(2)
        end

        return result.message
    else
        printTyping("Error: No response from server.\n", config.uiColors.errorColor)
    end
end

-- Clear the chat history
local function wipeMemory()
    if config.baseURL == "" then
        printTyping("Error: Base URL not set.", config.uiColors.errorColor)
        return
    end
    local fullURL = config.baseURL .. "/clear_conversation"
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. config.apiToken
    }

    local collectedData = collectData()

    local body = textutils.serializeJSON(collectedData)

    printTyping("Clearing memory...", config.uiColors.systemColor)
    sleep(1)

    local response = http.post(fullURL, body, headers)

    if response then
        local result = textutils.unserializeJSON(response.readAll())
        response.close()
        printTyping(result.message, config.uiColors.systemColor)
    else
        printTyping("Error: No response from server.\n", config.uiColors.errorColor)
    end
end

-- Generate a random API token
function generateApiToken(length)
    length = length or 12
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*-"
    local token = ""
    
    math.randomseed(os.time())
  
    for i = 1, length do
      local randomIndex = math.random(1, #charset)
      token = token .. string.sub(charset, randomIndex, randomIndex)
    end
  
    return token
  end

local colorOptions = {"userNameColor", "userChatColor", "aiNameColor", "aiChatColor", "commandColor", "errorColor", "systemColor", "helpColor", "logoColor"}

-- Function to handle changing colors via a command tree
local function handleColorChange()
    printToBoth("Color Settings Menu:\n", config.uiColors.systemColor)
    
    for i, option in ipairs(colorOptions) do
        printToBoth(i .. ". Change " .. option .. "\n", config.uiColors.systemColor)
    end
    printToBoth(#colorOptions + 1 .. ". Set Default Colors\n", config.uiColors.systemColor)
    printToBoth(#colorOptions + 2 .. ". Abort\n", config.uiColors.systemColor)
    
    local selectedIndex = tonumber(readInput("\nEnter the number of the color setting you'd like to change: "))
    
    if selectedIndex and selectedIndex >= 1 and selectedIndex <= #colorOptions then
        local selectedOption = colorOptions[selectedIndex]
        
        printToBoth("Available colors: white, orange, magenta, lightBlue, yellow, lime, pink, gray, lightGray, cyan, purple, blue, brown, green, red, black\n", config.uiColors.helpColor)
        
        local newColor = readInput("\nEnter the new color name: ")
        
        if colors[newColor] then
            config.uiColors[selectedOption] = colors[newColor]
            saveConfig(config)
            printToBoth("\nColor for " .. selectedOption .. " changed to " .. newColor, config.uiColors.systemColor)
        else
            printToBoth("\nInvalid color name.", config.uiColors.errorColor)
        end
    elseif selectedIndex == #colorOptions + 1 then
        config.uiColors = uiColors
        saveConfig(config)
        printToBoth("\nDefault colors set.", config.uiColors.systemColor)
    elseif selectedIndex == #colorOptions + 2 then
        printToBoth("\nColor change aborted.", config.uiColors.systemColor)
    else
        printToBoth("\nInvalid option.", config.uiColors.errorColor)
    end
end

-- Function to wipe configuration and restart
local function wipeConfigAndRestart()
    if fs.exists(configFileName) then
        fs.delete(configFileName)
    end
    printToBoth("Configuration wiped. Rebooting now...", config.uiColors.systemColor)
    os.reboot()
end

-- Function to handle changing various settings via a command tree
local function handleSettings()
    printToBoth("Settings Menu:\n", config.uiColors.systemColor)
    printToBoth("1. Change User Name\n", config.uiColors.systemColor)
    printToBoth("2. Change AI Name\n", config.uiColors.systemColor)
    printToBoth("3. Change Base URL\n", config.uiColors.systemColor)
    printToBoth("4. Change Summary Threshold\n", config.uiColors.systemColor)
    printToBoth("5. Change UI Colors\n", config.uiColors.systemColor)
    printToBoth("6. Wipe Config and Restart\n", config.uiColors.systemColor)
    printToBoth("7. Abort\n", config.uiColors.systemColor)
    
    local selectedIndex = tonumber(readInput("\nEnter the number of the option you'd like to change: "))
    
    if selectedIndex == 1 then
        config.userName = readInput("Enter your new name: \n")
        saveConfig(config)
    elseif selectedIndex == 2 then
        config.aiName = readInput("Enter the new AI name: \n")
        saveConfig(config)
    elseif selectedIndex == 3 then
        config.baseURL = readInput("Enter the new base URL: \n")
        saveConfig(config)
    elseif selectedIndex == 4 then
        config.summaryThreshold = readInput("Enter the new summary threshold: \n")
        saveConfig(config)
    elseif selectedIndex == 5 then
        handleColorChange()
    elseif selectedIndex == 6 then
        wipeConfigAndRestart()
    elseif selectedIndex == 7 then
        printToBoth("\nSettings change aborted.", config.uiColors.systemColor)
    else
        printToBoth("\nInvalid option.", config.uiColors.errorColor)
    end
end

-- Handle command input
local function handleCommand(prompt)
    local changed = false

    if prompt == "/welcome" then
        welcomeMessage()
    elseif prompt == "/settings" then
        handleSettings()
    elseif prompt == "/token" then
        printToBoth("Your API token is: " .. config.apiToken .. "\n", config.uiColors.systemColor)
        changed = true
        printToBoth("Set API token.", config.uiColors.systemColor)
    elseif prompt == "/token reset" then
        config.apiToken = generateApiToken()
        changed = true
        printToBoth("Your API token is: " .. config.apiToken .. "\n", config.uiColors.systemColor)
    elseif prompt == "/clear" then
        wipeMemory()
        welcomeMessage()
    elseif prompt == "/version" then
        printToBoth(productVersion .. "\n", config.uiColors.systemColor)
    elseif prompt == "/help" then
        printHelp()
    elseif prompt == "/exit" then
        printToBoth("Exiting...\n\n", config.uiColors.systemColor, true)
        return true
    else
        printToBoth("Invalid command.\n", config.uiColors.errorColor)
    end

    printToBoth("\n", colors.gray, true)

    if changed then
        if validateConfig(config) then
            saveConfig(config)
        else
            printToBoth("Configuration is invalid.\n", config.uiColors.errorColor)
        end
    end
end

-- Handle chat input
local function handleChat(prompt)
    printToBoth(config.aiName .. ": Thinking...", config.uiColors.aiNameColor, true)
    printToBoth("\n\n", colors.gray, true)
    local aiResponse = sendMessage(prompt)
    if aiResponse == nil then
        printToBoth("Something went wrong. Please try again.\n", config.uiColors.errorColor)
    end
    printTyping(aiResponse, config.uiColors.aiChatColor)
end

-- Handle user input
local function handleInput(prompt, config)
    term.setTextColor(config.uiColors.userNameColor)
    write(config.userName .. ": ")
    
    if prompt:sub(1, 1) == "/" then
        term.setTextColor(config.uiColors.commandColor)
    else
        term.setTextColor(config.uiColors.userChatColor)
    end
    
    print(prompt)
    
    table.insert(conversationBuffer, {{message = config.userName .. ": " .. prompt, color = term.getTextColor()}})
    redrawMonitor()
    
    printToBoth("\n", colors.gray, true)
    
    if prompt:sub(1, 1) == "/" then
        return handleCommand(prompt, config)
    else
        handleChat(prompt, config)
        return false
    end
end

-- Main Loop
local function mainLoop(config)
    while true do
        local prompt = readInput(config.userName .. ": ")
        local shouldExit = handleInput(prompt, config)
        if shouldExit then
            term.setTextColor(config.uiColors.systemColor)
            print("Goodbye! Thank you for using " .. productName .. " by " .. authorName .. "!\n")
            term.setTextColor(colors.white)
            break
        end
    end
end

-- Initialization
local function initializeClient()
    loadConfig()
    if monitor then
        print("Monitor found!")
        monitor.setTextScale(1)
        monitor.clear()
    else
        print("Monitor not found!")
    end
    loadConfig()
    if not config.userName or config.userName == "" then 
        config.userName = readInput("Enter your name: ") 
    end
    if not config.aiName or config.aiName == "" then 
        config.aiName = readInput("Enter the AI's name: ") 
    end
    if not config.baseURL or config.baseURL == "" then 
        config.baseURL = readInput("Enter the base URL: ") 
    end
    if not config.summaryThreshold or config.summaryThreshold == "" then 
        config.summaryThreshold = readInput("Enter the summary threshold: ")
    end
    if not config.apiToken or config.apiToken == "" then 
        config.apiToken = generateApiToken()
        printToBoth("Your API token is: " .. config.apiToken .. "\n", config.uiColors.systemColor)
    end
    if not config.uiColors then
        config.uiColors = uiColors
    end
    saveConfig(config)
    welcomeMessage()
    mainLoop(config)
end

-- Entry Point
initializeClient()
