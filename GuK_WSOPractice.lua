local lcPlayerGroupName = {'player1', 'player2', 'player3'} -- 듣기평가 구역 플레이어 기체의 '그룹' 이름, 원할 시 더 추가해도 ㄱㅊ, 이름 마음대로 수정 ㅇㅋ
local wsoPlayerGroupName = {'player4', 'player5', 'player6'} -- 레이더 연습 구역 플레이어 기체의 '그룹' 이름, 원할 시 더 추가해도 ㄱㅊ, 이름 마음대로 수정 ㅇㅋ

local lcZone = '듣기평가 트리거 구역 이름'
local lcTemplates = {'Su-27', 'F-16', 'F-1', 'F-4', 'F-5', 'Mig-21', 'Mig-23', 'F-15', 'F-18', 'Mig-29'} -- 듣기평가 구역에 나올 기체 '그룹' 이름, 이름 마음대로 수정 ㅇㅋ
--                                                                                                          미션 에디터에 생성 후 "Late Activation" 체크할 것

local wsoZone = '레이더 연습 구역 이름'
local wsoTemplates = {'L-39', 'Su-25', 'Su-27w', 'C-130', 'F-15C', 'F-16w'} -- 레이더 연습 구역에 나올 기체 '그룹' 이름, 이름 마음대로 수정 ㅇㅋ
--                                                                           미션 에디터에 생성 후 "Late Activation" 체크할 것

local weaponTarget = {} -- 건들면 좆됌..

-- 유닛 생성 시 행동 양식
-- 1. 맵 어디다 놓든 상관이 없음.
-- 2. 그러나 웨이포인트 1개를 구역 중앙이든 어디든 구역 내 랜덤한 위치에서 스폰한 후 이동할 포인트를 하나 찍어줘야함.
-- 3. 모르겠으면 뜨는별 멘션

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

    trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\nSTT를 걸고, 미사일을 발사한 후, 정답을 제출해주세요.", 5)

    local gO = spawnEnemyAircraft(wsoZone)

    local eGN = gO["name"]

    local spawnedUnit = Group.getByName(eGN):getUnits()[1]

    local answerSheet = {}

    answerSheet[spawnedUnit:getTypeName()] = 2

    while tableSize(answerSheet) ~= 5 do
        local uT = wsoTemplates[math.random(1, #wsoTemplates)]

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
        local pU = Group.getByName(gN):getUnits()[1]

        if weaponTarget[pU:getName()] ~= nil then
            if answerSheet[answer] == 2 and weaponTarget[pU:getName()]:getTarget():getTypeName() == answer then
                clearZone(wsoZone)
                trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n정답입니다. 다시 도전하시려면 라디오 메뉴에서 '레이더 평가 시작' 을 눌러주세요.", 5)
                missionCommands.removeItemForGroup(gID, nil)
                weaponTarget[pU:getName()] = nil
                mist.scheduleFunction(missionCommands.addCommandForGroup, {gID, '레이더 평가 시작', nil, startLC, gN, gID}, timer.getTime() + 5)
            else
                trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n오답입니다.", 5)
            end
        else
            trigger.action.outTextForGroup(gID, "< 레이더 평가 >\n\n발사된 미사일을 찾지 못했습니다. 다시 시도해주세요.", 5)
        end
    end

    for _, k in ipairs(keys) do
        missionCommands.addCommandForGroup(gID, k, nil, checkAnswer, k)
    end
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