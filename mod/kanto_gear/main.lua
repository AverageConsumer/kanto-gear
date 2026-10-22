return function(mod)
  local session = {}
  local function install(name, ...)
    local path = name .. ".lua"
    return assert(load(mod:read(path), "@kanto_gear/" .. path))()(...)
  end
  local core = install("core/init", install)
  local Area, CHOICE_QUIET, HEADER, HEIGHT, MAP_EXIT = core.Area, core.CHOICE_QUIET, core.HEADER, core.HEIGHT, core.MAP_EXIT
  local MAP_HIDDEN, MAP_ITEM, RADAR_RED, THEME, WIDTH = core.MAP_HIDDEN, core.MAP_ITEM, core.RADAR_RED, core.THEME, core.WIDTH
  local addEncounters, battleChoice, bottomOwnsBattleUI, box, button = core.addEncounters, core.battleChoice, core.bottomOwnsBattleUI, core.box, core.button
  local carouselSubpage, categorizedBag, caughtWild, centered, checklistPages = core.carouselSubpage, core.categorizedBag, core.caughtWild, core.centered, core.checklistPages
  local choiceReady, clockText, color, expBar, fit = core.choiceReady, core.clockText, core.color, core.expBar, core.fit
  local glyphList, hasUnlockedTool, hpBar, inside, inverted = core.glyphList, core.hasUnlockedTool, core.hpBar, core.inside, core.inverted
  local localMapGrid, localMapLayout, localMapMode, methodLines, moveGridLayout = core.localMapGrid, core.localMapLayout, core.localMapMode, core.methodLines, core.moveGridLayout
  local moveSlotAt, namingCell, oneShotTrainerStatus, outline, pageSwipeAllowed = core.moveSlotAt, core.namingCell, core.oneShotTrainerStatus, core.outline, core.pageSwipeAllowed
  local pagedIndex, partySlotAt, pcListKind, prepareBattleSnapshot, progressRatio = core.pagedIndex, core.partySlotAt, core.pcListKind, core.prepareBattleSnapshot, core.progressRatio
  local render, savedSteps, screenContract, text, textPrompt = core.render, core.savedSteps, core.screenContract, core.text, core.textPrompt
  local textTouch, usePalette = core.textTouch, core.usePalette
  local Discovery, RADAR_FRAMES, SettingsInfo, compactSteps = install("runtime/options",
    THEME, mod)
  local EngineFont, PaletteFX, PokemonSprites, assist, bottomBattleHud, bottomOnHandheld, compat, currentBattleUIMode, customBattleLayout, displayPreference, displayRuntime, fullBottomBattleUI, hgssRuntime, inlineDisplay = install("runtime/bootstrap",
    Area, Discovery, HEIGHT, SettingsInfo, THEME, WIDTH,
    box, color, fit, glyphList, mod, render,
    session, text)
  if not render.G then return end
  displayRuntime.session = session
  install("runtime/feedback",
    Discovery, THEME, compat, currentBattleUIMode, displayRuntime, hgssRuntime,
    mod, session)
  install("runtime/compatibility",
    THEME, color, compat, displayRuntime, mod, render,
    session)
  local companionMoveGrid, hasDisplay, invalidateLocalMap, refreshTheme = install("runtime/display_theme",
    HEIGHT, PaletteFX, THEME, WIDTH, bottomOwnsBattleUI, compat,
    customBattleLayout, displayRuntime, hgssRuntime, inlineDisplay, inverted, mod,
    moveGridLayout, render, session, usePalette)
  local reloadSteps = install("runtime/home_layout",
    THEME, compat, displayRuntime, mod, savedSteps, session)
  local pageNames, refreshTools = install("runtime/field_tools",
    THEME, assist, compat, displayRuntime, localMapMode, mod,
    session)
  local areaMaps, areaName, guideData, locationEntries, locationEntry = install("runtime/encounters",
    Discovery, addEncounters, compat, displayRuntime, fit, session)
  local areaData = install("runtime/progress",
    Area, Discovery, THEME, areaMaps, areaName, assist,
    checklistPages, compat, displayRuntime, guideData, locationEntries, mod,
    oneShotTrainerStatus, session)
  local drawSprite, hasItemfinder, loadMap, radarSignals = install("runtime/sprites",
    Area, PaletteFX, PokemonSprites, THEME, box, color,
    compat, displayRuntime, mod, render, session)
  local attachBattleArtSprites, battleState, header, pcList, pcSession, screenById, screenState = install("runtime/screen_state",
    HEADER, THEME, WIDTH, assist, box, clockText,
    compat, displayRuntime, fit, glyphList, hasItemfinder, mod,
    pcListKind, radarSignals, render, screenContract, session, text,
    textTouch)
  local dialogueChoice = install("runtime/start_menu",
    RADAR_FRAMES, THEME, assist, battleChoice, button, centered,
    compat, displayRuntime, drawSprite, header, hgssRuntime, pcList,
    pcListKind, render, screenById, session)
  install("runtime/device_apps", THEME, compat, displayRuntime, header, render, screenState, session)
  install("runtime/motion",
    THEME, color, compat, currentBattleUIMode, dialogueChoice, displayRuntime,
    hgssRuntime, pcList, pcListKind, pcSession, render, screenState,
    session)
  local choiceWindow, drawDialogueChoice, drawDim, drawLevelUpStats, drawNaming, drawTitle, trackChoice = install("runtime/dialogue",
    CHOICE_QUIET, EngineFont, HEIGHT, THEME, WIDTH, assist,
    battleState, box, button, centered, color, compat,
    displayRuntime, drawSprite, fit, glyphList, header, hgssRuntime,
    loadMap, mod, outline, render, session, text)
  local canFly, drawMap, flyTargets = install("runtime/region_map",
    PaletteFX, THEME, areaName, box, centered, color,
    compat, displayRuntime, header, loadMap, locationEntries, locationEntry,
    mod, render, session)
  local loadLocalMap = install("runtime/explorer",
    Area, Discovery, RADAR_FRAMES, THEME, areaData, areaMaps,
    areaName, assist, compat, displayRuntime, drawSprite, guideData,
    hasItemfinder, hgssRuntime, localMapGrid, mod, render, screenState,
    session)
  install("runtime/social",
    THEME, areaName, color, compat, displayRuntime, header,
    mod, render, screenState, session)
  local drawFlyPrompt, drawLocalMap = install("runtime/map_views",
    MAP_EXIT, MAP_HIDDEN, MAP_ITEM, THEME, areaData, areaName,
    assist, box, button, centered, compat, displayRuntime,
    drawDim, fit, header, loadLocalMap, localMapGrid, localMapLayout,
    mod, outline, render, session, text)
  local drawTrainer = install("runtime/trainer",
    PaletteFX, THEME, assist, box, color, compactSteps,
    compat, displayRuntime, fit, header, outline, render,
    session, text)
  local drawActionPrompt, drawArea, drawCaughtBall, drawGuide, drawRadar, drawStepsDetail, drawTools = install("runtime/field_views",
    RADAR_FRAMES, RADAR_RED, THEME, areaData, areaName, assist,
    box, button, centered, color, compat, displayRuntime,
    drawDim, drawSprite, fit, glyphList, guideData, hasItemfinder,
    hasUnlockedTool, header, methodLines, outline, radarSignals, render,
    session, text)
  local partyCard, partyData = install("runtime/home",
    THEME, assist, box, compactSteps, compat, displayRuntime,
    drawSprite, expBar, fit, guideData, header, hpBar,
    loadLocalMap, mod, outline, progressRatio, render, screenState,
    session, text)
  install("runtime/modules", THEME, displayRuntime, mod, session)
  mod.exports.modules = displayRuntime.gearModules.exports
  install("runtime/store",
    THEME, areaName, assist, compactSteps, compat, displayRuntime,
    drawSprite, header, loadLocalMap, partyData, render, session)
  install("runtime/daycare",
    THEME, assist, compat, displayRuntime, drawSprite, header, locationEntry,
    mod, render, session)
  install("runtime/calendar",
    THEME, assist, compat, displayRuntime, header, locationEntry, mod, render,
    session)
  install("runtime/calendar_gen3", THEME, assist, displayRuntime, session)
  local drawFieldChoice, drawNormalParty, drawParty, drawPartyAction = install("runtime/party",
    THEME, button, displayRuntime, fit, header, hgssRuntime,
    partyCard, partyData, render, session)
  install("runtime/battle_models",
    THEME, assist, battleState, categorizedBag, caughtWild, clockText,
    compat, customBattleLayout, displayRuntime, drawSprite, hgssRuntime, mod,
    progressRatio, session)
  local chanceLabel, drawBattleRoot, drawMimic, drawMoves, drawSafari, effectLabel = install("runtime/battle_views",
    THEME, assist, battleState, bottomBattleHud, box, button,
    companionMoveGrid, customBattleLayout, displayRuntime, fit, header, hgssRuntime,
    mod, outline, render, session, text)
  install("runtime/dex",
    Discovery, THEME, areaName, assist, compat, displayRuntime,
    drawSprite, guideData, mod, session)
  install("runtime/bag",
    THEME, assist, compat, displayRuntime, header, mod,
    render, screenState, session)
  local drawMoveInfo = install("runtime/move_info",
    THEME, assist, battleState, box, centered, chanceLabel,
    compat, displayRuntime, effectLabel, fit, header, hgssRuntime,
    mod, outline, render, screenContract, session, text)
  local drawBattleItems, drawBattleParty, drawPpItemMoves = install("runtime/battle_menus",
    THEME, assist, button, categorizedBag, caughtWild, chanceLabel,
    choiceWindow, compat, displayRuntime, drawParty, fit, header,
    hgssRuntime, partyCard, render, screenContract, session)
  local drawBattleSummary = install("runtime/battle_summary",
    Discovery, THEME, battleState, bottomOwnsBattleUI, box, button,
    centered, compat, customBattleLayout, displayRuntime, drawSprite, fit,
    hasDisplay, header, hgssRuntime, hpBar, mod, render,
    screenById, session, text)
  local drawBattle, drawBattleLocked, drawPc, drawUnavailableMenu = install("runtime/battle_render",
    Discovery, THEME, assist, battleState, bottomBattleHud, box,
    button, caughtWild, centered, compat, currentBattleUIMode, displayRuntime,
    drawBattleItems, drawBattleParty, drawBattleRoot, drawBattleSummary, drawCaughtBall, drawDim,
    drawMimic, drawMoveInfo, drawMoves, drawPpItemMoves, drawSafari, drawSprite,
    effectLabel, fit, header, hgssRuntime, mod, outline,
    pcList, render, screenContract, session, text)
  install("runtime/companion_render",
    HEIGHT, THEME, WIDTH, assist, battleState, box,
    button, centered, compat, currentBattleUIMode, customBattleLayout, dialogueChoice,
    displayRuntime, drawActionPrompt, drawArea, drawBattle, drawBattleLocked, drawBattleSummary,
    drawDialogueChoice, drawDim, drawFieldChoice, drawFlyPrompt, drawGuide, drawLevelUpStats,
    drawLocalMap, drawMap, drawMoveInfo, drawNaming, drawNormalParty, drawParty,
    drawPartyAction, drawPc, drawPpItemMoves, drawRadar, drawSprite, drawStepsDetail,
    drawTitle, drawTools, drawTrainer, drawUnavailableMenu, fit, header,
    hgssRuntime, mod, outline, pcSession, render, screenById,
    screenContract, screenState, session, text, textPrompt)
  local draw, pumpDisplay, refreshBattle = install("runtime/frame",
    THEME, attachBattleArtSprites, battleChoice, battleState, bottomOnHandheld, compat,
    displayPreference, displayRuntime, hgssRuntime, mod, prepareBattleSnapshot, render,
    screenContract, session)
  local back, holdTextSpeed, press, submit, useTool = install("runtime/commands",
    HEADER, THEME, displayRuntime, hgssRuntime, mod, refreshBattle,
    refreshTools, session)
  install("runtime/party_actions",
    Discovery, THEME, compat, displayRuntime, hgssRuntime, inside,
    mod, refreshTools, screenState, session)
  install("runtime/home_touch",
    THEME, displayRuntime, inside, session)
  install("runtime/app_touch",
    HEADER, THEME, assist, displayRuntime, mod, session)
  local tapFieldChoice, tapLearn = install("runtime/field_touch",
    HEADER, THEME, assist, compat, displayRuntime, inside,
    press, session, useTool)
  local tapBattle = install("runtime/battle_touch",
    HEADER, THEME, assist, back, battleState, bottomBattleHud,
    categorizedBag, choiceWindow, companionMoveGrid, compat, currentBattleUIMode, displayRuntime,
    hgssRuntime, inside, moveSlotAt, press, screenContract, session,
    submit)
  local tapDialogueChoice, tapNaming, tapPc = install("runtime/menu_touch",
    CHOICE_QUIET, HEADER, THEME, choiceReady, choiceWindow, compat,
    displayRuntime, inside, namingCell, pcList, press, session,
    submit, trackChoice)
  local changePage, pollScreenSwap = install("runtime/navigation",
    THEME, areaData, carouselSubpage, dialogueChoice, displayRuntime, guideData,
    mod, pageNames, pageSwipeAllowed, refreshTools, screenState, session)
  local tap = install("runtime/touch",
    HEADER, THEME, areaData, assist, back, canFly,
    carouselSubpage, changePage, compat, currentBattleUIMode, dialogueChoice, displayRuntime,
    flyTargets, guideData, hasItemfinder, hgssRuntime, inside, loadLocalMap,
    mod, partyData, partySlotAt, pcSession, press, screenById,
    screenContract, screenState, session, tapBattle, tapDialogueChoice, tapFieldChoice,
    tapLearn, tapNaming, tapPc, textTouch, useTool)
  local swipe, swipeVertical = install("runtime/gestures",
    THEME, changePage, compat, currentBattleUIMode, dialogueChoice, displayRuntime,
    loadLocalMap, pagedIndex, press, screenContract, session)
  local touchEvent = install("runtime/touch_events",
    HEIGHT, THEME, WIDTH, battleState, compat, currentBattleUIMode,
    dialogueChoice, displayRuntime, hgssRuntime, holdTextSpeed, mod, pageSwipeAllowed,
    pcSession, refreshBattle, screenContract, screenState, session, swipe,
    swipeVertical, tap, textTouch)
  local resetSwapState = install("runtime/display_control",
    Discovery, THEME, battleState, compat, currentBattleUIMode, customBattleLayout,
    dialogueChoice, displayRuntime, fullBottomBattleUI, hasDisplay, hgssRuntime, holdTextSpeed,
    mod, refreshBattle, refreshTheme, reloadSteps, render, screenContract,
    session, touchEvent)
  install("runtime/options_events",
    Area, Discovery, THEME, assist, compat, displayRuntime,
    hgssRuntime, invalidateLocalMap, localMapMode, mod, refreshTheme, reloadSteps,
    resetSwapState, session)
  install("runtime/native_input",
    THEME, assist, back, battleState, bottomOwnsBattleUI, compat,
    customBattleLayout, dialogueChoice, displayRuntime, fullBottomBattleUI, hasDisplay, hgssRuntime,
    mod, screenContract, session)
  install("runtime/hooks",
    HEIGHT, RADAR_FRAMES, THEME, WIDTH, battleState, bottomOnHandheld,
    bottomOwnsBattleUI, companionMoveGrid, compat, customBattleLayout, dialogueChoice, displayRuntime,
    draw, fullBottomBattleUI, hasDisplay, hgssRuntime, holdTextSpeed, inlineDisplay,
    invalidateLocalMap, mod, pcList, pollScreenSwap, pumpDisplay, refreshBattle,
    refreshTheme, refreshTools, render, resetSwapState, screenContract, screenState,
    session, touchEvent, trackChoice)
end
