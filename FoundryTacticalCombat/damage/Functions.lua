 
--[[----------------------------------------------------------
    DAMAGE MANAGEMENT COMPONENT
  ]]----------------------------------------------------------
  
FTC.Damage  = {}
function FTC.Damage:Initialize()

    -- Set up initial timestamps
    FTC.Damage.lastIn   = 0
    FTC.Damage.lastOut  = 0
end

--[[----------------------------------------------------------
    EVENT HANDLERS
 ]]-----------------------------------------------------------
    
    --[[ 
     * Validate and Process New Damages
     * --------------------------------
     * Called by FTC:OnCombatEvent()
     * --------------------------------
     ]]--
    function FTC.Damage:New( result , abilityName , abilityGraphic , abilityActionSlotType , sourceName , sourceType , targetName , targetType , hitValue , powerType , damageType )

        -- Determine context
        local damageOut = false
        if ( sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET ) then damageOut = true
        elseif ( sourceType == COMBAT_UNIT_TYPE_NONE and ( targetName == FTC.Player.name ) ) then damageOut = false
        else return end

        -- Reflag self-targetted as incoming
        if ( damageOut and ( targetName == FTC.Player.name ) ) then damageOut = false end

        -- Ignore certain results
        if ( FTC.Damage:Filter( result ) ) then return end

        -- Compute some flags
        local isCrit    = result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_DOT_TICK_CRITICAL or result == ACTION_RESULT_HOT_TICK_CRITICAL
        local isHeal    = result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL

        -- Get the icon
        local icon = FTC.UI.Textures[abilityName] or '/esoui/art/icons/icon_missing.dds'
        if ( abilityName == "" and ( not damageOut ) and isHeal ) then icon = '/esoui/art/icons/ability_healer_017.dds'
        elseif ( abilityName == "" and not damageOut ) then icon = '/esoui/art/icons/death_recap_ranged_heavy.dds' end

        -- Setup the damage object
        local damage    = {
            ["out"]     = damageOut,
            ["result"]  = result,
            ["target"]  = targetName,
            ["source"]  = sourceName,
            ["ability"] = abilityName,
            ["type"]    = damageType,
            ["value"]   = hitValue,
            ["power"]   = powerType,
            ["ms"]      = GetGameTimeMilliseconds(),
            ["crit"]    = isCrit,
            ["heal"]    = isHeal,
            ["icon"]    = icon,
            ["mult"]    = 1, 
            ["weapon"]  = FTC.Damage:IsWeaponAttack(abilityName),
        }

        -- ACTION_RESULT_DODGED
        -- ACTION_RESULT_MISS
        -- ACTION_RESULT_IMMUNE
        -- ACTION_RESULT_INTERRUPT
        -- ACTION_RESULT_BLOCKED
        -- ACTION_RESULT_OFFBALANCE
        -- ACTION_RESULT_STUNNED
        -- ACTION_RESULT_POWER_DRAIN
        -- ACTION_RESULT_POWER_ENERGIZE

        -- Damage Dealt
        if ( hitValue > 0 and ( result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL ) ) then 
                
            -- Flag timestamps
            if ( damageOut ) then FTC.Damage.lastOut = GetGameTimeMilliseconds()
            else FTC.Damage.lastIn  = GetGameTimeMilliseconds() end

            -- Log and SCT
            if ( FTC.init.Log ) then FTC.Log:CombatEvent(damage) end
            if ( FTC.init.SCT ) then FTC.SCT:Damage(damage) end

            -- Modify Buffs on Damage
            if ( FTC.init.Buffs and damageOut ) then FTC.Buffs:Damage(damage) end

        -- Falling damage
        elseif ( result == ACTION_RESULT_FALL_DAMAGE ) then
            damage.ability  = GetString(FTC_Falling)
            damage.icon     = '/esoui/art/icons/death_recap_fall_damage.dds'

            -- Log and SCT
            if ( FTC.init.Log ) then FTC.Log:CombatEvent(damage) end
            if ( FTC.init.SCT ) then FTC.SCT:Damage(damage) end

        -- Shielded Damage
        elseif ( result == ACTION_RESULT_DAMAGE_SHIELDED ) then

            -- Log and SCT
            if ( FTC.init.Log ) then FTC.Log:CombatEvent(damage) end
            if ( FTC.init.SCT ) then FTC.SCT:Damage(damage) end

            -- Modify Buffs on Damage
            if ( FTC.init.Buffs and damageOut ) then FTC.Buffs:Damage(damage) end

        -- Misses and  Dodges
        elseif ( result == ACTION_RESULT_DODGED or result == ACTION_RESULT_MISS ) then

            -- Log and SCT
            if ( FTC.init.Log ) then FTC.Log:CombatEvent(damage) end
            if ( FTC.init.SCT ) then FTC.SCT:Damage(damage) end

        -- Healing Dealt
        elseif ( hitValue > 0 and ( result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL ) ) then 

            -- Log and SCT
            if ( FTC.init.Log ) then FTC.Log:CombatEvent(damage) end
            if ( FTC.init.SCT ) then FTC.SCT:Damage(damage) end

            -- Modify Buffs on Damage
            if ( FTC.init.Buffs and damageOut ) then FTC.Buffs:Damage(damage) end

        -- Target Death
        elseif ( result == ACTION_RESULD_DIED or result == ACTION_RESULT_DIED_XP ) then

            -- Wipe Buffs
            if ( FTC.init.Buffs ) then FTC.Buffs:WipeBuffs(targetName) end

            -- Log and SCT
            if ( FTC.init.Log ) then FTC.Log:CombatEvent(damage) end


        -- DEBUG NEW EVENTS
        elseif ( hitValue > 0 ) then

            -- Prompt other unrecognized
            local direction = damageIn and "Incoming" or "Outgoing"
            -- FTC.Log:Print( direction .. " result " .. result .. " not recognized! Target: " .. targetName .. " Value: " .. hitValue , {1,1,0} )

        end
    end


--[[----------------------------------------------------------
    HELPER FUNCTIONS
 ]]-----------------------------------------------------------
    
    --[[ 
     * Filter Out Unwanted Combat Events
     * --------------------------------
     * Called by FTC.Damage:New()
     * --------------------------------
     ]]--
    function FTC.Damage:Filter( result )

        -- Keep a list of ignored actions
        local results = {
            ACTION_RESULT_QUEUED,
        }

        -- Check actions
        for i = 1 , #results do
            if ( result == results[i] ) then return true end
        end
    end

    --[[ 
     * Track Whether a Damage Source is a Weapon ATtack
     * --------------------------------
     * Called by FTC.Damage:New()
     * --------------------------------
     ]]--
    function FTC.Damage:IsWeaponAttack( abilityName )

        local attacks = {
            4858,      -- Bash
            7880,      -- Light Attack
            7095,      -- Heavy Attack
            16420,     -- Heavy Attack (Dual Wield)
            16691,     -- Heavy Attack (Bow)
            32480,     -- Heavy Attack Werewolf
        }

        -- Compare each shield ability with the current buffs for purging
        for i = 1 , #attacks do
            local name = GetAbilityName(attacks[i])
            if ( abilityName == name ) then return true end 
        end

    end


