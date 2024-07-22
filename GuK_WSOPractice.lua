local lcPlayerGroupName = {'player1', 'player2', 'player3'} -- 듣기평가 구역 플레이어 기체의 '그룹' 이름, 원할 시 더 추가해도 ㄱㅊ, 이름 마음대로 수정 ㅇㅋ
local wsoPlayerGroupName = {'player4', 'player5', 'player6'} -- 레이더 연습 구역 플레이어 기체의 '그룹' 이름, 원할 시 더 추가해도 ㄱㅊ, 이름 마음대로 수정 ㅇㅋ

local lcZone = '듣기평가 트리거 구역 이름' -- 원하는 구역에 트리거 존 배치하고 이름 맞춰주기, 크기 상관없음
local lcTemplates = {'Su-27', 'F-16', 'F-1', 'F-4', 'F-5', 'Mig-21', 'Mig-23', 'F-15', 'F-18', 'Mig-29'} -- 듣기평가 구역에 나올 기체 '그룹' 이름, 이름 마음대로 수정 ㅇㅋ
--                                                                                                          미션 에디터에 생성 후 "Late Activation" 체크할 것

local wsoZone = '레이더 연습 구역 이름' -- 원하는 구역에 트리거 존 배치하고 이름 맞춰주기, 크기 상관없음
local wsoTemplates = {'L-39', 'Su-25', 'Su-27w', 'C-130', 'F-15C', 'F-16w'} -- 레이더 연습 구역에 나올 기체 '그룹' 이름, 이름 마음대로 수정 ㅇㅋ
--                                                                           미션 에디터에 생성 후 "Late Activation" 체크할 것

local wsoTimeout = 30 -- 레이더 연습 시간 제한 (초 단위)

-- 적 유닛 템플릿 생성 시 행동 양식
-- 1. 맵 어디다 놓든 상관이 없음.
-- 2. 그룹 이름이랑 유닛 이름 똑같이 하고 위에 lcTemplates랑 wsoTemplates에 있는 이름대로 맞춰주면 됌
-- 3. 모르겠으면 뜨는별 멘션하기

-- 이 아래로 건들면 좆됌 --

local wsoPlayerStatus = {}

local weaponTarget = {}

function spawnEnemyAircraft(zoneName)
    local groupName = ''

    if zoneName == lcZone then
        groupName = lcTemplates[math.random(1, #lcTemplates)]
    else
        groupName = wsoTemplates[math.random(1, #wsoTemplates)]
    end

    return mist.cloneInZone(groupName, zoneName)
end

function shuffleTable(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(1, i)

        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

function tableSize(tbl)
    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

function clearZone(zoneName)
    local u = mist.getUnitsInZones(mist.makeUnitTable({'[red]'}), {zoneName})

    for i = 1, #u do
        u[i]:destroy()
    end
end

function startLC(gN, gID)
    missionCommands.removeItemForGroup(gID, nil)

    local gO = spawnEnemyAircraft(lcZone)

    local eGN = gO["name"]

    local spawnedUnit = Group.getByName(eGN):getUnits()[1]

    -- AI 유닛 플레이어 목표물 강제 지정

    local gC = Group.getByName(eGN):getController()

    local aG = {
        id = 'AttackGroup',
        params = {
            groupId = gID,
        }
    }

    mist.scheduleFunction(Controller.pushTask, {gC, aG}, timer.getTime() + 2)

    -- 목표물 강제 지정 끝

    local answerSheet = {}

    answerSheet[spawnedUnit:getTypeName()] = 2

    while tableSize(answerSheet) ~= 5 do
        local uT = lcTemplates[math.random(1, #lcTemplates)]

        local uO = Group.getByName(uT):getUnits()[1]

        if answerSheet[uO:getTypeName()] ~= 1 and answerSheet[uO:getTypeName()] ~= 2 then
            answerSheet[uO:getTypeName()] = 1
        end
    end

    local keys = {}

    for k in pairs(answerSheet) do
        table.insert(keys, k)
    end

    shuffleTable(keys)

    local function checkAnswer(answer)
        if answerSheet[answer] == 2 then
            clearZone(lcZone)
            spawnedUnit:destroy()
            trigger.action.outTextForGroup(gID, "< 듣기 평가 >\n\n정답입니다. 다시 도전하시려면 라디오 메뉴에서 '듣기 평가 시작' 을 눌러주세요.", 5)
            missionCommands.removeItemForGroup(gID, nil)
            mist.scheduleFunction(missionCommands.addCommandForGroup, {gID, '듣기 평가 시작', nil, startLC, gN, gID}, timer.getTime() + 5)
        else
            trigger.action.outTextForGroup(gID, "< 듣기 평가 >\n\n오답입니다.", 5)
        end
    end

    for _, k in ipairs(keys) do
        missionCommands.addCommandForGroup(gID, k, nil, checkAnswer, k)
    end
end

function startWSO(gN, gID)
    missionCommands.removeItemForGroup(gID, nil)

    trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\nSTT를 걸고, 미사일을 발사한 후, 라디오 메뉴에서 확인 버튼을 눌러주세요.", 5)

    local gO = spawnEnemyAircraft(wsoZone)

    local eGN = gO["name"]

    local spawnedUnit = Group.getByName(eGN):getUnits()[1]

    local pU = Group.getByName(gN):getUnits()[1]

    local function checkAnswer()
        if weaponTarget[pU:getName()] ~= nil then
            if weaponTarget[pU:getName()]:getTarget() ~= nil then
                mist.removeFunction(wsoPlayerStatus[gN])
                wsoPlayerStatus[gN] = nil
                clearZone(wsoZone)
                spawnedUnit:destroy()
                trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n성공. 다시 도전하시려면 라디오 메뉴에서 '레이더 평가 시작' 을 눌러주세요.", 5)
                missionCommands.removeItemForGroup(gID, nil)
                weaponTarget[pU:getName()] = nil
                mist.scheduleFunction(missionCommands.addCommandForGroup, {gID, '레이더 평가 시작', nil, startWSO, gN, gID}, timer.getTime() + 5)
            else
                trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n미사일이 아무것도 물지 않았습니다. 다시 시도해주세요.", 5)
                weaponTarget[pU:getName()] = nil
            end
        else
            trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n발사된 미사일을 찾지 못했습니다. 다시 시도해주세요.", 5)
        end
    end

    missionCommands.addCommandForGroup(gID, "확인", nil, checkAnswer)

    wsoPlayerStatus[gN] = mist.scheduleFunction(resetWSO, {gN, gID, pU, spawnedUnit}, timer.getTime() + wsoTimeout)
end

function resetWSO(gN, gID, pU, sU)
    trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n시간 초과. 다시 도전하시려면 라디오 메뉴에서 '레이더 평가 시작' 을 눌러주세요.", 5)
    clearZone(wsoZone)
    sU:destroy()
    missionCommands.removeItemForGroup(gID, nil)
    weaponTarget[pU:getName()] = nil
    mist.scheduleFunction(missionCommands.addCommandForGroup, {gID, '레이더 평가 시작', nil, startWSO, gN, gID}, timer.getTime() + 5)
end

local eH_missileLaunch = {}

function eH_missileLaunch:onEvent(e)
    if e.id == world.event.S_EVENT_SHOT then
        weaponTarget[e.initiator:getName()] = e.weapon
    end
end

world.addEventHandler(eH_missileLaunch)

for _, gN in pairs(lcPlayerGroupName) do
    if Group.getByName(gN) then
        local gID = Group.getByName(gN):getID()
        missionCommands.addCommandForGroup(gID, '듣기 평가 시작', nil, startLC, gN, gID)
    end
end

for _, gN in pairs(wsoPlayerGroupName) do
    if Group.getByName(gN) then
        local gID = Group.getByName(gN):getID()
        missionCommands.addCommandForGroup(gID, '레이더 연습 시작', nil, startWSO, gN, gID)
    end
end

-- 플레이어 유닛 무적 설정 --

local sI = {
    id = 'SetImmortal',
    params = {
        value = true
    }
}

for _, gN in pairs(lcPlayerGroupName) do
    if Group.getByName(gN) then
        local gC = Group.getController(Group.getByName(gN))

        gC:setCommand(sI)
    end
end

for _, gN in pairs(wsoPlayerGroupName) do
    if Group.getByName(gN) then
        local gC = Group.getController(Group.getByName(gN))

        gC:setCommand(sI)
    end
end