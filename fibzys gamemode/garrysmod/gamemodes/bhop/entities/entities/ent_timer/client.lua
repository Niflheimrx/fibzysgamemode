﻿local bhop_showzones = CreateClientConVar("bhop_showzones", 1, true, false, "Toggle visibility of bhop zones")
local bhop_wireframe = CreateClientConVar("bhop_wireframe", 1, true, false, "Toggle wireframe or solid zones")
local bhop_thickness = CreateClientConVar("bhop_thickness", 2, true, false, "Change zone thickness")
local bhop_flatzones = CreateClientConVar("bhop_flatzones", 0, true, false, "Change to flat zones")
local bhop_rainbowzones = CreateClientConVar("bhop_rainbowzones", 0, true, false, "Change to rainbow zones")
local Iv = IsValid

local Zone = {
    MStart = 0, MEnd = 1,
    BStart = 2, BEnd = 3,
    FS = 5, AC = 4,
    BAC = 7, NAC = 6,
    SStart = 8, SEnd = 9,
    Restart = 10, Velocity = 11,
    HELPER = 130
}

function ENT:UpdateZoneData()
    local min, max = self:GetCollisionBounds()
    local pos = self:GetPos()

    self.ZoneData = {
        set1 = {
            Vector(min.x, min.y, min.z), Vector(min.x, max.y, min.z), 
            Vector(max.x, max.y, min.z), Vector(max.x, min.y, min.z)
        },
        set2 = {
            Vector(min.x, min.y, max.z), Vector(min.x, max.y, max.z), 
            Vector(max.x, max.y, max.z), Vector(max.x, min.y, max.z)
        },
        min = min,
        max = max,
        pos = pos
    }

    self:SetRenderBounds(min, max)
end

function ENT:Initialize()
    self:UpdateZoneData()

    local min, max = self:GetCollisionBounds()
    self:SetRenderBounds(min, max)

    self.initialized = true
end

function ENT:Draw()
    if not bhop_showzones:GetBool() then return end

    self:UpdateZoneData()

    local zoneType = self:GetNWInt("zonetype")
    local selectedZoneTheme = Settings:GetValue('selected.zones') or 'zones.kawaii'
    local zoneTheme, zoneThemeId = Theme:GetPreference("Zones", selectedZoneTheme)
    local themeColors = zoneTheme["Colours"] or {}

    local DrawArea = {
        [Zone.MStart] = themeColors["Start Zone Colour"] or Color(0, 255, 0, 255),
        [Zone.MEnd] = themeColors["End Zone Colour"] or Color(255, 0, 0, 255),
        [Zone.BStart] = themeColors["Bonus Start Colour"] or Color(0, 80, 255, 255),
        [Zone.BEnd] = themeColors["Bonus End Colour"] or Color(0, 80, 255, 100),
        [Zone.FS] = Color(0, 80, 255, 100),
        [Zone.AC] = themeColors["Anti-Cheat Colour"] or Color(153, 0, 153, 100),
        [Zone.BAC] = Color(0, 0, 153, 100),
        [Zone.NAC] = Color(140, 140, 140, 100),
        [Zone.SStart] = Color(255, 128, 0, 100),
        [Zone.SEnd] = Color(255, 128, 128, 100),
        [Zone.Restart] = Color(128, 0, 255, 100),
        [Zone.Velocity] = Color(255, 0, 128, 100),
        [Zone.HELPER] = DynamicColors.PanelColor or Color(255, 0, 128, 100)
    }

    if bhop_rainbowzones:GetBool() then
        Col = HSVToColor(RealTime() * 40 % 360, 1, 1)
    else
        Col = DrawArea[zoneType]
    end

    if not Col then return end

    local isWireframe = bhop_wireframe:GetBool()
    local GetPos = self:GetPos()
    local rm, rma = self:GetCollisionBounds()
    
    local min, max = isWireframe and self.ZoneData.min or (GetPos + rm), isWireframe and self.ZoneData.max or (GetPos + rma)

    if table.HasValue({Zone.AC, Zone.BAC, Zone.NAC}, zoneType) then
        local acConVar = GetConVar("bhop_anticheats"):GetInt()
        if acConVar == 1 then
            render.DrawBox(GetPos, Angle(0, 0, 0), rm, rma, Col)
        else
            return
        end
    else
        UTIL:DrawZoneTypes(min, max, Col, not isWireframe, self.ZoneData.pos, bhop_thickness:GetInt(), bhop_flatzones:GetBool())
    end
end