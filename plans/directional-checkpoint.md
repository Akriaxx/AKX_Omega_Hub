# Plan: Directional Checkpoint Texts & Position Fix

## Goal
- Implement directional text (Entry/Exit) for checkpoints.
- Allow configurable display position for banners.

## Tasks

### 1. Data Schema Update (`Modules/ZoneGate/Core.lua`)
- [ ] Add `forwardName` and `backwardName` fields to the `subZone` table definition in `ZG:CreateSubZone`.
- [ ] Update `ZG:CloneSubZone` to copy these new fields.
- [ ] Update `ZG:PackState` and `ApplyStateLine` (network serialization) to include these fields in the `SUB` protocol message.

### 2. UI Update (`Modules/ZoneGate/UI_Panel.lua`)
- [ ] Add `sfForwardNameEB` and `sfBackwardNameEB` editboxes to the sub-zone form (Placement tab).
- [ ] Add logic to `RefreshSubZoneForm` to populate and save these fields.
- [ ] Add a Y-offset slider for banner placement in the theme or zone settings.

### 3. Logic Update (`Modules/ZoneGate/Core.lua`)
- [ ] Update `ZG:ResolveBannerText` to take `direction` ("forward" | "backward") and return appropriate names.
- [ ] Update `ZG:TriggerCrossing` to call `ResolveBannerText` with the correct direction.

### 4. Position Fix
- [ ] Modify `banner:ShowBanner` and `UI_Banner.lua` placement settings to allow `ZG.DefaultTheme.yOffset` and use it in `SetPoint`.

## Risks/Dependencies
- Serialization (`PackState`): Must maintain compatibility for other players (chunked state transmission). Adding fields needs care.
