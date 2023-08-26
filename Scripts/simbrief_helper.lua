-- Simbrief helper Enh
-- Olivier Butler Aug - 2023
-- based on Simbrief helper by Alexander Garzon
-- Description: It gets your OFP data from simbrief (after you generate your flight plan) using your username (API call), in order to display
-- variables like flight level, block fuel, payload, zfw, destination altitude, metar, etc..
-- Manage, load and save The field of view angle per aircraft
-- Zinbo B738 only : upload the OFP in the FMC
-- Version:
local vVersion = "2.2"
-- local vVersion = "2.1"
-- local vVersion = "2.0"
-- local vVersion = "1.8"
-- local vVersion = "1.7"
-- local vVersion = "1.6"
-- local vVersion = "1.5"

DataRef("planeFOV", "sim/graphics/view/field_of_view_deg", "writable")
dataref("acf_tailnum", "sim/aircraft/view/acf_tailnum", "writable")
dataref("ground_speed", "sim/flightmodel/position/groundspeed")

local isZibo = (acf_tailnum == "ZB738")

-- Modules
local xml2lua = require("xml2lua")

-- Variables
local socket = require "socket"
local http = require "socket.http"
local ltn12 = require "ltn12"
local LIP = require("LIP");

local SettingsFile = "simbrief_helper.ini"
local SimbriefXMLFile = "simbrief.xml"
local FMSFolder = SYSTEM_DIRECTORY .. "Output" .. DIRECTORY_SEPARATOR .. "FMS plans" .. DIRECTORY_SEPARATOR
local FMSFilesuffix = "01"
local sbUser = ""
local avwxToken = ""
local upload2FMC = false

local DataOfp = nil
local Settings = {}

local fetchOFPCLick = false
local fetchMETARCLick = false

local FovScriptName = "fov_keeper"
local FovSettingsFile = SCRIPT_DIRECTORY .. FovScriptName .. "_" .. string.gsub(AIRCRAFT_FILENAME, ".acf", "") .. ".ini"

local gitVersionCheckUrl =
    "http://inerrant-sixes.000webhostapp.com/checkversion.php?q=simbriefHelperEnh/contents/version.ini"
local forumUrl = "https://forums.x-plane.org/index.php?/files/file/86783-simbrief-helper-enh/"
local gitAcceptHeader = "application/vnd.github.raw"
local gitVersionStatus = ""

function logMsg_SBe(message)
    if message == nil then
        message = "NIL"
    end
    logMsg("Simbrief Helper: " .. message)
end

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg_SBe("imgui not supported by your FlyWithLua version")
    return
end
logMsg_SBe("Starting v" .. vVersion)

function format_thousand(v)
    local s = string.format("%6d", math.floor(v))
    local pos = string.len(s) % 3
    if pos == 0 then
        pos = 3
    end
    return string.sub(s, 1, pos) .. string.gsub(string.sub(s, pos + 1), "(...)", " %1")
end

local fmcKeyQueue = {}
local fmcQueueLocked = false
local fmcKeyWait = 0
function lockFmcBuffer(status)
    fmcQueueLocked = status
end

function pushKeyToFMC()
    if fmcKeyWait > 0 then
        fmcKeyWait = fmcKeyWait - 1
        return
    end
    if fmcQueueLocked == false then
        if #fmcKeyQueue ~= 0 then
            local b = table.remove(fmcKeyQueue, 1)
            if b == '_WAIT_' then
                fmcKeyWait = 20
                logMsg_SBe(b)
                return
            end
            command_once(b)
            logMsg_SBe(b)
        end
    end
end

function pushKeyToBuffer(startKey, inputString, endKey)
    if isZibo then
        inputString = string.upper(inputString)

        if startKey ~= "" then
            table.insert(fmcKeyQueue, "laminar/B738/button/fmc1_" .. startKey)
        end

        local c = ""
        if inputString ~= "" then
            for i = 1, string.len(inputString), 1 do
                c = string.sub(inputString, i, i)
                if c == "/" then
                    c = "slash"
                end
                if c == "-" then
                    c = "minus"
                end
                if c == "." then
                    c = "period"
                end
                if c == " " then
                    c = "SP"
                end
                table.insert(fmcKeyQueue, "laminar/B738/button/fmc1_" .. c)
            end
        end

        if endKey ~= "" then
            table.insert(fmcKeyQueue, "laminar/B738/button/fmc1_" .. endKey)
            table.insert(fmcKeyQueue, "_WAIT_")
        end
    else
        logMsg_SBe("Zibo B737 not detected : not computing the FMC")
    end
end

function loadFov()
    local f = io.open(FovSettingsFile, "r")
    if f ~= nil then
        io.input(f)
        local newPov = tonumber(io.read())
        logMsg_SBe("new Pov read " .. newPov .. " from " .. FovSettingsFile)
        planeFOV = newPov
        io.close(f)
    else
        saveFov()
    end
end

function saveFov()
    local f = io.open(FovSettingsFile, "w")
    io.output(f)
    io.write(tostring(planeFOV))
    logMsg_SBe("Pov written " .. tostring(planeFOV) .. " to " .. FovSettingsFile)
    io.close(f)
end

function readSettings()
    logMsg_SBe("readSettings")
    local f = io.open(SCRIPT_DIRECTORY .. SettingsFile, "r")
    if f == nil then
        Settings['simbrief'] = {}
    else
        io.close(f)
        Settings = LIP.load(SCRIPT_DIRECTORY .. SettingsFile);
    end

    if Settings.simbrief.username ~= nil then
        sbUser = Settings.simbrief.username
    end
    if Settings.simbrief.avwxtoken ~= nil then
        avwxToken = Settings.simbrief.avwxtoken
    end
    if Settings.simbrief.upload2FMC ~= nil then
        upload2FMC = Settings.simbrief.upload2FMC
    end

end

function saveSettings(newSettings)
    logMsg_SBe("saveSettings")
    LIP.save(SCRIPT_DIRECTORY .. SettingsFile, newSettings);
end

function fetchMetar(airport)
    package.loaded["xmlhandler.tree"] = nil
    local handler = require("xmlhandler.tree")

    local body = {}
    logMsg_SBe("fetchMetar")
    -- do return end -- stop
    if avwxToken == "" then
        logMsg_SBe("fetchMetar AVWX token has been configured")
        return false
    end
    -- It would be nice to have a try-cath here
    local webRespose, webStatus = http.request {
        url = "https://avwx.rest/api/metar/" .. airport .. "?reporting=false&format=xml&filter=raw",
        headers = {
            ["Authorization"] = "Token " .. avwxToken
        },
        sink = ltn12.sink.table(body)
    }

    webRespose = table.concat(body)

    if webStatus ~= 200 then
        logMsg_SBe("AVWX API is not responding OK")
        return false
    end

    local parser = xml2lua.parser(handler)
    parser:parse(webRespose)

    logMsg_SBe("METAR fetched of " .. airport .. " : " .. handler.root.AVWX.raw[1])
    return handler.root.AVWX.raw[1]
end

function IsNewScriptVersion()
    local body = {}
    -- It would be nice to have a try-cath here
    local webRespose, webStatus = http.request {
        url = gitVersionCheckUrl,
        headers = {
            ["Accept"] = gitAcceptHeader
        },
        sink = ltn12.sink.table(body)
    }

    webRespose = table.concat(body)
    webRespose = webRespose:gsub("^%s*(.-)%s*$", "%1")
    logMsg_SBe("IsNewScriptVersion GitHub response is " .. webRespose .. " " .. webStatus)
    if webStatus ~= 200 then
        logMsg_SBe("IsNewScriptVersion GitHub is not responding, returning empty string to avoid misunderstandung")
        return ""
    end

    if webRespose ~= vVersion then
        return "A new version of SimBrief Help Enh is available " .. webRespose .. " !\nCheck on " .. forumUrl
    end

    return ""
end

function fetchOFPXMLData()
    -- do return end -- stop
    if sbUser == nil or sbUser == "" then
        logMsg_SBe("fetchOFPXMLData: No simbrief username has been configured")
        return false
    end
    local url = "http://www.simbrief.com/api/xml.fetcher.php?username=" .. sbUser
    -- It would be nice to have a try-cath here
    logMsg_SBe("Querying " .. url)
    local webRespose, webStatus = http.request(url)

    if webStatus ~= 200 then
        logMsg_SBe("Simbrief API is not responding OK")
        return false
    end

    local f = io.open(SCRIPT_DIRECTORY .. SimbriefXMLFile, "w")
    f:write(webRespose)
    f:close()

    logMsg_SBe("Simbrief XML data downloaded at " .. os.time())

    return true
end

function readXML()
    logMsg_SBe("readXML")
    -- New XML parser
    package.loaded["xmlhandler.tree"] = nil
    local handler = require("xmlhandler.tree")
    local xfile = xml2lua.loadFile(SCRIPT_DIRECTORY .. SimbriefXMLFile)
    local parser = xml2lua.parser(handler)
    parser:parse(xfile)

    DataOfp = {}
    DataOfp["Status"] = handler.root.OFP.fetch.status

    if DataOfp["Status"] ~= "Success" then
        logMsg_SBe("XML status is not success")
        return false
    end

    DataOfp["FlightNumber"] = handler.root.OFP.general.flight_number

    DataOfp["Origin"] = handler.root.OFP.origin.icao_code
    DataOfp["OriginIATA"] = handler.root.OFP.origin.iata_code
    DataOfp["Origlevation"] = handler.root.OFP.origin.elevation
    DataOfp["OrigName"] = handler.root.OFP.origin.name
    DataOfp["OrigRwy"] = handler.root.OFP.origin.plan_rwy
    DataOfp["OrigMetar"] = handler.root.OFP.weather.orig_metar

    DataOfp["Destination"] = handler.root.OFP.destination.icao_code
    DataOfp["DestinationIATA"] = handler.root.OFP.destination.iata_code
    DataOfp["DestElevation"] = handler.root.OFP.destination.elevation
    DataOfp["DestName"] = handler.root.OFP.destination.name
    DataOfp["DestRwy"] = handler.root.OFP.destination.plan_rwy
    DataOfp["DestMetar"] = handler.root.OFP.weather.dest_metar

    DataOfp["Cpt"] = handler.root.OFP.crew.cpt
    DataOfp["Callsign"] = handler.root.OFP.atc.callsign
    DataOfp["Aircraft"] = handler.root.OFP.aircraft.name
    DataOfp["AircraftICAO"] = handler.root.OFP.aircraft.icao_code
    DataOfp["Units"] = handler.root.OFP.params.units
    DataOfp["Distance"] = handler.root.OFP.general.route_distance
    DataOfp["Ete"] = handler.root.OFP.times.est_time_enroute
    DataOfp["Route"] = handler.root.OFP.general.route
    DataOfp["Level"] = handler.root.OFP.general.initial_altitude
    DataOfp["RampFuel"] = (math.ceil(handler.root.OFP.fuel.plan_ramp / 100) * 100 + 100)
    DataOfp["TripFuel"] = (math.ceil(handler.root.OFP.fuel.enroute_burn / 100) * 100 + 100)
    DataOfp["MinTakeoff"] = handler.root.OFP.fuel.min_takeoff
    DataOfp["ReserveFuel"] = handler.root.OFP.fuel.reserve
    DataOfp["AlternateFuel"] = handler.root.OFP.fuel.alternate_burn
    DataOfp["Cargo"] = handler.root.OFP.weights.cargo
    DataOfp["Pax"] = handler.root.OFP.weights.pax_count
    DataOfp["Payload"] = handler.root.OFP.weights.payload
    DataOfp["Zfw"] = (handler.root.OFP.weights.est_zfw / 1000)
    DataOfp["CostIndex"] = handler.root.OFP.general.costindex
    DataOfp["OFPLayout"] = handler.root.OFP.params.ofp_layout

    -- find TOC
    local iTOC = 1
    while handler.root.OFP.navlog.fix[iTOC].ident ~= "TOC" do
        iTOC = iTOC + 1
    end

    DataOfp["CrzWindDir"] = handler.root.OFP.navlog.fix[iTOC].wind_dir
    DataOfp["CrzWindSpd"] = handler.root.OFP.navlog.fix[iTOC].wind_spd
    DataOfp["CrzTemp"] = handler.root.OFP.navlog.fix[iTOC].oat
    DataOfp["CrzTempDev"] = handler.root.OFP.navlog.fix[iTOC].oat_isa_dev

    DataOfp["OfpAge"] = os.time() - handler.root.OFP.params.time_generated
    logMsg_SBe("OfpAge is " .. DataOfp["OfpAge"])

    local OutputFilename = DataOfp["Origin"] .. DataOfp["Destination"]

    if avwxToken ~= "" then
        DataOfp["OrigMetar"] = fetchMetar(DataOfp["Origin"])
        DataOfp["DestMetar"] = fetchMetar(DataOfp["Destination"])
    end

    -- xp11/12 link
    DataOfp["xpe_in"] = handler.root.OFP.fms_downloads.directory .. handler.root.OFP.fms_downloads.xpe.link
    DataOfp["xpe_out"] = FMSFolder .. OutputFilename .. FMSFilesuffix .. ".fms"

    -- copying xml to xp fms
    local OutputFMSXMLpath = FMSFolder .. OutputFilename .. FMSFilesuffix .. ".xml"
    local f = io.open(OutputFMSXMLpath, "w")
    f:write(xfile)
    f:close()
    logMsg_SBe("Simbrief XML data copied to " .. OutputFMSXMLpath)

    -- export to xp fms
    export_to_fms(DataOfp, "xpe", "xp11/12")

    return true
end

function export_to_fms(DataOfp, key, export_name)

    -- It would be nice to have a try-cath here
    local webRespose, webStatus = http.request(DataOfp[key .. "_in"])

    if webStatus ~= 200 then
        logMsg_SBe("Downloading Fligh plan : Simbrief API is not responding OK")
        return false
    else
        logMsg_SBe("Flight plan for " .. export_name .. " downloaded from " .. DataOfp[key .. "_in"])
    end

    local f = io.open(DataOfp[key .. "_out"], "w")
    f:write(webRespose)
    f:close()

    logMsg_SBe("Flight plan for " .. export_name .. " copied to  " .. DataOfp[key .. "_out"])
    return true
end

function timeConvert(seconds, sep)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return "no data";
    else
        hours = string.format("%2.f", math.floor(seconds / 3600));
        mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)));
        return hours .. sep .. mins
    end
end

function uploadToZiboFMC()
    logMsg_SBe("uploadToZiboFMC")
    lockFmcBuffer(true)
    pushKeyToBuffer("rte", DataOfp["Origin"] .. DataOfp["Destination"] .. FMSFilesuffix, "2L")
    pushKeyToBuffer("", DataOfp["OrigRwy"], "3L")
    pushKeyToBuffer("", DataOfp["FlightNumber"], "2R")
    pushKeyToBuffer("init_ref", "", "6L")
    pushKeyToBuffer("3L", "", "")
    pushKeyToBuffer("", string.format("%1.1f", DataOfp["RampFuel"] / 1000), "2L")
    pushKeyToBuffer("", string.format("%1.1f", DataOfp["Zfw"]), "3L")
    pushKeyToBuffer("", string.format("%1.1f", (DataOfp["ReserveFuel"] + DataOfp["AlternateFuel"]) / 1000), "4L")
    pushKeyToBuffer("", string.format("%1d", DataOfp["CostIndex"]), "5L")
    pushKeyToBuffer("", string.format("%1.0f", DataOfp["Level"] / 100), "1R")
    pushKeyToBuffer("", string.format("%03d/%03d", DataOfp["CrzWindDir"], DataOfp["CrzWindSpd"]), "2R")
    pushKeyToBuffer("", string.format("%dC", DataOfp["CrzTempDev"]), "3R")
    lockFmcBuffer(false)
end

function fetchOFP()
    logMsg_SBe("fetchOFP")
    if fetchOFPXMLData() then
        readXML()
        if ground_speed < 5 then
            if isZibo and upload2FMC and DataOfp["AircraftICAO"] == 'B738' then
                uploadToZiboFMC()
            else
                logMsg_SBe("Aircraft is not Zibo B738 or OPF is targeting " .. DataOfp["AircraftICAO"] ..
                               " , FMC not updated")
            end
        else
            logMsg_SBe("Aircraft not on the ground, FMC not updated")
        end
    end
end

function displayOFP(DataOfp)
    imgui.TextUnformatted(DataOfp["Status"])

    if gitVersionStatus ~= "" then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00BFFF)
        imgui.TextUnformatted(gitVersionStatus)
        imgui.PopStyleColor()
    end

    imgui.TextUnformatted("                                                  ")
    -- if OFP older than 2 hours
    if DataOfp["OfpAge"] > 2 * 60 * 60 then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF0000FF)
        imgui.TextUnformatted("Warning, this OFP is older than 2 hours")
        imgui.TextUnformatted("                                                  ")
        imgui.PopStyleColor()
    end

    imgui.TextUnformatted(string.format("FMS CO ROUTE:       %s%s%s / %s%s%s", DataOfp["Origin"],
        DataOfp["Destination"], FMSFilesuffix, DataOfp["OriginIATA"], DataOfp["DestinationIATA"], FMSFilesuffix))

    if DataOfp["OFPLayout"] ~= "LIDO" then
        imgui.SameLine()
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00BFFF)
        imgui.TextUnformatted(string.format(
            " (OFP Layout: %s, (LIDO layout is prefered), FMC's UPLINK DATA (Wind forecasts) will not be available)",
            DataOfp["OFPLayout"]))
        imgui.PopStyleColor()
    end

    imgui.TextUnformatted(string.format("Aircraft:           %s", DataOfp["Aircraft"]))
    imgui.TextUnformatted(string.format("Airports:           %s - %s", DataOfp["OrigName"], DataOfp["DestName"]))
    imgui.TextUnformatted(string.format("Route:              %s/%s %s %s/%s", DataOfp["Origin"], DataOfp["OrigRwy"],
        DataOfp["Route"], DataOfp["Destination"], DataOfp["DestRwy"]))
    imgui.TextUnformatted(string.format("Distance:           %d nm", DataOfp["Distance"]))
    imgui.SameLine()
    imgui.TextUnformatted(string.format("ETE: %s", timeConvert(DataOfp["Ete"], "h")))
    imgui.TextUnformatted(string.format("Cruise Altitude:   %s ft", format_thousand(DataOfp["Level"])))
    imgui.TextUnformatted(string.format("Elevations:         %s (%d ft) - %s (%d ft)", DataOfp["Origin"],
        DataOfp["Origlevation"], DataOfp["Destination"], DataOfp["DestElevation"]))

    imgui.TextUnformatted("                                                  ")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFF00)
    imgui.TextUnformatted(string.format("Block Fuel:        %s %s", format_thousand(DataOfp["RampFuel"]),
        DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Takeoff Fuel:      %s %s", format_thousand(DataOfp["MinTakeoff"]),
        DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Trip  Fuel:        %s %s", format_thousand(DataOfp["TripFuel"]),
        DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Reserve Fuel:      %s %s", format_thousand(DataOfp["ReserveFuel"]),
        DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Alternate Fuel:    %s %s", format_thousand(DataOfp["AlternateFuel"]),
        DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Res+Alt Fuel:      %s %s",
        format_thousand(DataOfp["ReserveFuel"] + DataOfp["AlternateFuel"]), DataOfp["Units"]))
    imgui.PopStyleColor()

    imgui.TextUnformatted("                                                  ")
    imgui.TextUnformatted(string.format("Pax:                %6d", DataOfp["Pax"]))
    imgui.TextUnformatted(string.format("Cargo:             %s %s", format_thousand(DataOfp["Cargo"]), DataOfp["Units"]))
    imgui.TextUnformatted(string.format("Payload:           %s %s", format_thousand(DataOfp["Payload"]),
        DataOfp["Units"]))
    imgui.TextUnformatted(string.format("ZFW:                %6.1f", DataOfp["Zfw"]))
    imgui.TextUnformatted(string.format("Cost Index:         %6d", DataOfp["CostIndex"]))

    imgui.TextUnformatted("                                                  ")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00FF00)
    imgui.TextUnformatted(string.format("TOC Wind:          %03d/%03d", DataOfp["CrzWindDir"], DataOfp["CrzWindSpd"]))
    imgui.TextUnformatted(string.format("TOC Temp:              %3d °C", DataOfp["CrzTemp"]))
    imgui.TextUnformatted(string.format("TOC ISA Dev:           %3d °C", DataOfp["CrzTempDev"]))
    imgui.PopStyleColor()

    imgui.TextUnformatted("                                                  ")
    imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00BFFF)
    imgui.TextUnformatted(string.format("%s", DataOfp["OrigMetar"]))
    imgui.TextUnformatted(string.format("%s", DataOfp["DestMetar"]))
    if avwxToken == "" then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF0000FF)
        imgui.TextUnformatted("(AVWX is not configured: updated METARs not available)")
        imgui.PopStyleColor()
    end
    imgui.PopStyleColor()

end

function sb_on_build(sb_wnd, x, y)

    if fetchOFPCLick then
        fetchOFP()
        fetchOFPCLick = false
    end

    if fetchMETARCLick then
        DataOfp["OrigMetar"] = fetchMetar(DataOfp["Origin"])
        DataOfp["DestMetar"] = fetchMetar(DataOfp["Destination"])
        fetchMETARCLick = false
    end

    if Settings.simbrief.fontsize == true then
        imgui.SetWindowFontScale(1.2)
    else
        imgui.SetWindowFontScale(1)
    end

    -- Settings Tree
    if imgui.TreeNode("Settings") then
        -- INPUT
        local changed, userNew = imgui.InputText("Simbrief Username", sbUser, 255)

        if changed then
            sbUser = userNew
            Settings.simbrief.username = userNew
            if Settings.simbrief.username ~= nil and Settings.simbrief.username ~= "" then
                saveSettings(Settings)
            end
        end

        local awxchanged, awxnew = imgui.InputText(
            "Avwx Token ( to enable Refresh Metar feature, see https://account.avwx.rest/getting-started )", avwxToken,
            255, imgui.constant.InputTextFlags.ReadOnly)
        if awxchanged then
            avwxToken = awxnew
            Settings.simbrief.avwxtoken = awxnew
            saveSettings(Settings)
        end

        local fontChanged, fontNewVal = imgui.Checkbox("Use bigger font size", Settings.simbrief.fontsize)
        if fontChanged then
            Settings.simbrief.fontsize = fontNewVal
            saveSettings(Settings)
        end

        local uploadChanged, upload2FMCNew = imgui.Checkbox("Program the FMC automaticaly (Zibo B737 only)",
            Settings.simbrief.upload2FMC)
        if uploadChanged then
            upload2FMC = upload2FMCNew
            Settings.simbrief.upload2FMC = upload2FMC
            saveSettings(Settings)
        end

        if imgui.Button("-") then
            planeFOV = math.floor(planeFOV - 1)
            saveFov()
        end
        imgui.SameLine()
        imgui.TextUnformatted(string.format(" %s ", planeFOV))
        imgui.SameLine()
        if imgui.Button("+") then
            planeFOV = math.floor(planeFOV + 1)
            saveFov()
        end
        imgui.SameLine()
        imgui.TextUnformatted(string.format("Current Fov for  %s ", PLANE_ICAO))
        imgui.TreePop()
    end

    -- blank line
    imgui.TextUnformatted(" ")

    -- BUTTON fetch OFP
    if Settings.simbrief.username == nil or Settings.simbrief.username == "" then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF0000FF)
        imgui.TextUnformatted("Simbrief Username not defined ! Fetch OFP button not available")
        imgui.PopStyleColor()
    else
        if imgui.Button("Fetch OFP") then
            fetchOFPCLick = true
            DataOfp = nil
        end
    end

    -- fetching OFP in progress
    if fetchOFPCLick == true and DataOfp == nil then
        imgui.SameLine()
        imgui.TextUnformatted(" Fetching OFP")
    end

    -- display OFP iof exits
    if DataOfp ~= nil then
        -- Metar button if OFP exists
        if Settings.simbrief.avwxtoken ~= nil and Settings.simbrief.avwxtoken ~= "" then
            imgui.SameLine()
            imgui.TextUnformatted(" / ")
            imgui.SameLine()
            if imgui.Button("Refresh Metar") then
                fetchMETARCLick = true
                DataOfp["OrigMetar"] = "Fetching Origin's METAR"
                DataOfp["DestMetar"] = "Fetching Destination's METAR"
            end
        end
        displayOFP(DataOfp)
    end

end

-- Open and close window from Lua menu

sb_wnd = nil

function sb_show_wnd()
    readSettings() -- It should read only once
    sb_wnd = float_wnd_create(700, 700, 1, true)
    -- float_wnd_set_imgui_font(sb_wnd, 2)
    local newVersion = ""
    if gitVersionStatus ~= "" then
        newVersion = "Update available"
    end
    float_wnd_set_title(sb_wnd, "Simbrief Helper Enh ( v" .. vVersion .. " ) " .. newVersion)
    float_wnd_set_imgui_builder(sb_wnd, "sb_on_build")
    float_wnd_set_onclose(sb_wnd, "sb_hide_wnd")
end

function sb_hide_wnd()
    if sb_wnd then
        float_wnd_destroy(sb_wnd)
    end
end

sb_show_only_once = 0
sb_hide_only_once = 0

function toggle_simbrief_helper_interface()
    sb_show_window = not sb_show_window
    if sb_show_window then
        if sb_show_only_once == 0 then
            sb_show_wnd()
            sb_show_only_once = 1
            sb_hide_only_once = 0
        end
    else
        if sb_hide_only_once == 0 then
            sb_hide_wnd()
            sb_hide_only_once = 1
            sb_show_only_once = 0
        end
    end
end

gitVersionStatus = IsNewScriptVersion()

add_macro("Simbrief Helper Enh", "sb_show_wnd()", "sb_hide_wnd()", "deactivate")
create_command("FlyWithLua/SimbriefHelper/show_toggle", "open/close Simbrief Helper Enh",
    "toggle_simbrief_helper_interface()", "", "")
if isZibo then
    do_every_frame("pushKeyToFMC()")
end
loadFov()
