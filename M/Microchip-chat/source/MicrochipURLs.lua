-- Microchip-chat 0.8.4: clickable web URLs and Ctrl+C copy window.
-- Vanilla WoW 1.12 / Lua 5.0 compatible: no clipboard API, no modern hooks.
-- Only chat *display* text is modified. Existing player/item hyperlinks and
-- all server-bound chat messages remain untouched.

MCURLs = {}

local byURL, byID, nextID = {}, {}, 0
local copyFrame, copyInput

local function isWebAddress(url)
    if type(url)~="string" or string.len(url)<4 or string.len(url)>1024 or
       string.find(url,"[|%c<>]") then
        return false
    end
    local lower=string.lower(url)
    local host
    if string.find(lower,"^https?://") then
        host=string.gsub(lower,"^https?://", "")
    else
        host=lower
    end
    local _,_,candidate=string.find(host,"^([^/%?#:]+)")
    host=candidate or ""
    if string.sub(host,1,4)=="www." then host=string.sub(host,5) end
    -- No scheme-only links, spaces, pipe/control markup, or non-domain words.
    if not string.find(host,"^[%w%-%.]+$") then return false end
    if string.find(host,"%.%.") or string.find(host,"^%.") then return false end
    local _,_,tld=string.find(host,"%.(%a+)$")
    if not tld or string.len(tld)<2 or string.len(tld)>24 then return false end
    return true
end

-- Surrounding punctuation is not part of the URL. A matched closing bracket
-- within a URL path is retained only if it has an opening counterpart.
local function splitToken(token)
    local lead=""
    local tail=""
    while string.len(token)>0 and string.find(string.sub(token,1,1),'[%(%%%[%{<>"\']') do
        lead=lead..string.sub(token,1,1)
        token=string.sub(token,2)
    end
    local changed=true
    while changed and string.len(token)>0 do
        changed=false
        local last=string.sub(token,-1)
        if string.find(last,"[%,%.%!%?%;:>\"']") then
            tail=last..tail
            token=string.sub(token,1,-2)
            changed=true
        elseif last==")" or last=="]" or last=="}" then
            local opener=(last==")" and "(") or (last=="]" and "[") or "{"
            local _,opens=string.gsub(token, "%"..opener, "")
            local _,closes=string.gsub(token, "%"..last, "")
            if closes>opens then
                tail=last..tail
                token=string.sub(token,1,-2)
                changed=true
            end
        end
    end
    return lead,token,tail
end

local function linkFor(url)
    local id=byURL[url]
    if not id then
        nextID=nextID+1
        id=tostring(nextID)
        byURL[url]=id
        byID[id]=url
    end
    return "|cff64bfff|Hmcurl:"..id.."|h"..url.."|h|r"
end

local function transformPlain(plain)
    -- Work token-by-token to avoid including ordinary punctuation in the link.
    local output=string.gsub(plain,"%S+",function(token)
        local lead,url,tail=splitToken(token)
        if isWebAddress(url) then
            return lead..linkFor(url)..tail
        end
        return token
    end)
    return output
end

function MCURLs.Linkify(message)
    if type(message)~="string" or message=="" then return message end
    -- Don't linkify within an existing WoW hyperlink, including item names
    -- containing spaces or URLs. This also preserves class-colored player links.
    local output={}
    local pos=1
    while pos<=string.len(message) do
        local start=string.find(message,"|H",pos,true)
        if not start then
            table.insert(output,transformPlain(string.sub(message,pos)))
            break
        end
        local payloadEnd=string.find(message,"|h",start+2,true)
        local labelEnd=payloadEnd and string.find(message,"|h",payloadEnd+2,true)
        if not labelEnd then
            table.insert(output,transformPlain(string.sub(message,pos)))
            break
        end
        if start>pos then
            table.insert(output,transformPlain(string.sub(message,pos,start-1)))
        end
        table.insert(output,string.sub(message,start,labelEnd+1))
        pos=labelEnd+2
    end
    return table.concat(output)
end

local function makeCopyFrame()
    if copyFrame then return end
    local frame=CreateFrame("Frame","MicrochipChatURLCopyFrame",UIParent)
    frame:SetWidth(560)
    frame:SetHeight(118)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,120)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnMouseDown",function()
        if arg1=="LeftButton" then frame:StartMoving() end
    end)
    frame:SetScript("OnMouseUp",function()
        frame:StopMovingOrSizing()
    end)
    frame:SetScript("OnHide",function()
        frame:StopMovingOrSizing()
    end)
    local bg=frame:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(0.075,0.11,0.17,0.98)

    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",17,-13)
    title:SetText("MICROCHIP-CHAT  /  COPY LINK")

    local hint=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT",frame,"TOPLEFT",17,-37)
    hint:SetText("URL selected  -  press Ctrl+C to copy, then Esc to close")

    local input=CreateFrame("EditBox","MicrochipChatURLCopyInput",frame,"InputBoxTemplate")
    input:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",20,17)
    input:SetWidth(514)
    input:SetHeight(26)
    input:SetAutoFocus(false)
    input:SetMaxLetters(1024)
    input:SetScript("OnEscapePressed",function() frame:Hide() end)
    input:SetScript("OnEnterPressed",function() input:HighlightText() end)

    local close=CreateFrame("Button",nil,frame)
    close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-9,-8)
    close:SetWidth(20)
    close:SetHeight(20)
    local label=close:CreateFontString(nil,"OVERLAY","GameFontNormal")
    label:SetAllPoints(close)
    label:SetText("X")
    close:SetScript("OnClick",function() frame:Hide() end)

    frame:Hide()
    copyFrame,copyInput=frame,input
end

function MCURLs.HandleClick(link)
    if type(link)~="string" or string.sub(link,1,6)~="mcurl:" then
        return false
    end
    local id=string.sub(link,7)
    local url=byID[id]
    if not url then return true end
    makeCopyFrame()
    copyFrame:Show()
    copyInput:SetText(url)
    copyInput:SetFocus()
    copyInput:HighlightText()
    return true
end

function MCURLs.GetURLForLink(link)
    if type(link)=="string" and string.sub(link,1,6)=="mcurl:" then
        return byID[string.sub(link,7)]
    end
end
