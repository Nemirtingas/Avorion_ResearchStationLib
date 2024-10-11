--[[ The point of this file is to make modding Research Station easier and prevent compatibility issues between mods.
Feel free to contact me if you want to add some extra features like hooks, utility functions e.t.c ]]

--[[ bool, int research(table itemIndices)
Returns:
* true - Successfull research
* false, int errorCode - Error
  Where errorCode:
    1 - itemIndices is nil
    2 - Can't interact with a station (invalid ship or station belongs to nobody or relations aren't good enough)
    3 - Player doesn't have required alliance permissions
    4 - Not enough items (invalid items or amount passed)
    5 - Not enough items (need at least 3 items)
    6 - Items cannot be more than one rarity apart
    7 - Not docked
    8 - Transform returned no result (perhaps invalid item types?)
]]
function ResearchStation.research(itemIndices)
    if not itemIndices then return false, 1 end

    if not CheckFactionInteraction(callingPlayer, ResearchStation.interactionThreshold) then return false, 2 end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return false, 3 end

    -- check if the player has enough of the items
    local items = {}

    for index, amount in pairs(itemIndices) do
        local item = buyer:getInventory():find(index)
        local has = buyer:getInventory():amount(index)

        if not item or has < amount then
            player:sendChatMessage(Entity(), 1, "You don't have enough items!"%_t)
            return false, 4
        end

        for i = 1, amount do
            items[#items+1] = item
        end
    end

    if #items < 3 then
        player:sendChatMessage(Entity(), 1, "You need at least 3 items to do research!"%_t)
        return false, 5
    end

    if GameVersion() < Version("2.0") and not ResearchStation.checkRarities(items) then
        player:sendChatMessage(Entity(), 1, "Your items cannot be more than one rarity apart!"%_t)
        return false, 6
    end

    local station = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to research items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return false, 7
    end

    local result = ResearchStation.transform(items)

    if result then
        for index, amount in pairs(itemIndices) do
            for i = 1, amount do
                buyer:getInventory():take(index)
            end
        end

        local inventory = buyer:getInventory()
        if not inventory:hasSlot(result) then
            buyer:sendChatMessage(station, ChatMessageType.Warning, "Your inventory is full (%1%/%2%). Your researched item was dropped."%_T, inventory.occupiedSlots, inventory.maxSlots)
        end

        inventory:addOrDrop(result)
        invokeClientFunction(player, "receiveResult", result)
        
        if GameVersion() >= Version("2.0") then
            local senderInfo = makeCallbackSenderInfo(station)
            buyer:sendCallback("onItemResearched", senderInfo, ship.id, result)
            ship:sendCallback("onItemResearched", senderInfo, result)
            station:sendCallback("onItemResearched", senderInfo, ship.id, buyer.index, result)
        end
    else
        buyer:sendChatMessage(station, ChatMessageType.Error, "Incapable of transforming these items."%_T)
        return false, 8
    end
    return true
end