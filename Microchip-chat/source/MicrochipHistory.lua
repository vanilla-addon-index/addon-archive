-- Microchip-chat 0.8.7: independent, ring-buffered per-channel history.
-- Original arrays and SavedVariables are migrated without discarding history.
-- Vanilla WoW 1.12 / Lua 5.0 compatible.
MCHistory = {}

local cachedChat, cachedCombat
local function invalidate()
    cachedChat=nil
    cachedCombat=nil
end

function MCHistory.Key(record)
    if not record or record.legacy then return "LEGACY" end
    if record.kind=="CHANNEL" then return record.channel or "CHANNEL" end
    return record.kind or "LEGACY"
end

function MCHistory.Limit(store, defaultLimit, key)
    local limits=store.historyLimits or {}
    local value=limits[key]
    if not value and string.sub(key or "",1,8)=="CHANNEL:" then
        value=limits.CHANNEL
    end
    return tonumber(value) or tonumber(defaultLimit) or 1000
end

-- historyHeads[key] is the physical position of the oldest entry. The
-- array itself remains densely indexed for SavedVariables serialization.
-- Rotation at capacity only overwrites one slot, avoiding table.remove(1).
local function getRecord(bucket, head, index)
    local n=table.getn(bucket)
    if n==0 then return nil end
    local physical=math.mod((head or 1)+index-2,n)+1
    return bucket[physical]
end

function MCHistory.Get(store, key, index)
    local bucket=store.historyByChannel and store.historyByChannel[key]
    if not bucket then return nil end
    return getRecord(bucket,(store.historyHeads or {})[key] or 1,index)
end

local function normalize(store, defaultLimit, key, bucket)
    local n=table.getn(bucket)
    local limit=MCHistory.Limit(store,defaultLimit,key)
    local head=store.historyHeads[key] or 1
    if n<=limit and (head==1 or n==limit) then return end
    local first=math.max(1,n-limit+1)
    local clean={}
    local i
    for i=first,n do
        table.insert(clean,getRecord(bucket,head,i))
    end
    store.historyByChannel[key]=clean
    store.historyHeads[key]=1
end

function MCHistory.Trim(store, defaultLimit)
    if type(store.historyByChannel)~="table" then return end
    if type(store.historyHeads)~="table" then store.historyHeads={} end
    local key,bucket
    for key,bucket in pairs(store.historyByChannel) do
        if type(bucket)=="table" then
            normalize(store,defaultLimit,key,bucket)
        else
            store.historyByChannel[key]=nil
            store.historyHeads[key]=nil
        end
    end
    invalidate()
end

local function migrateArray(store, records)
    if type(records)~="table" then return end
    local i,record,key,bucket
    for i=1,table.getn(records) do
        record=records[i]
        if type(record)=="table" then
            key=MCHistory.Key(record)
            bucket=store.historyByChannel[key]
            if not bucket then
                bucket={}
                store.historyByChannel[key]=bucket
            end
            table.insert(bucket,record)
        end
    end
end

function MCHistory.Initialize(store,defaultLimit)
    if type(store.historyByChannel)~="table" then store.historyByChannel={} end
    if type(store.historyLimits)~="table" then store.historyLimits={} end
    if type(store.historyHeads)~="table" then store.historyHeads={} end
    local key,value
    for key,value in pairs(store.historyLimits) do
        if type(key)~="string" or type(value)~="number" or value<50 or value>5000 then
            store.historyLimits[key]=nil
        else
            store.historyLimits[key]=math.floor(value)
        end
    end
    if not store.historyMigrated085 then
        migrateArray(store,store.entries)
        migrateArray(store,store.combatEntries)
        store.entries=nil
        store.combatEntries=nil
        store.historyMigrated085=true
    end
    -- The oldest pre-sequence legacy records may not have sequence values.
    -- Give them stable, unique negative IDs so cursor paging works for them.
    local missing=0
    local bucket,i,record
    for key,bucket in pairs(store.historyByChannel) do
        if type(bucket)=="table" then
            for i=1,table.getn(bucket) do
                record=bucket[i]
                if type(record)=="table" and type(record.sequence)~="number" then
                    missing=missing+1
                    record.sequence=-100000000+missing
                end
            end
        end
    end
    MCHistory.Trim(store,defaultLimit)
end

function MCHistory.Add(store, defaultLimit, record)
    local key=MCHistory.Key(record)
    local bucket=store.historyByChannel[key]
    if not bucket then
        bucket={}
        store.historyByChannel[key]=bucket
    end
    if not store.historyHeads then store.historyHeads={} end
    local limit=MCHistory.Limit(store,defaultLimit,key)
    local n=table.getn(bucket)
    local head=store.historyHeads[key] or 1
    if n<limit then
        -- A changed limit can leave a rotated, partly-filled bucket.
        -- Normalize it once before appending, not on every incoming message.
        if head~=1 then
            normalize(store,defaultLimit,key,bucket)
            bucket=store.historyByChannel[key]
        end
        table.insert(bucket,record)
    else
        bucket[head]=record
        store.historyHeads[key]=math.mod(head,limit)+1
    end
    invalidate()
end

function MCHistory.SetLimit(store,defaultLimit,key,value)
    if type(key)~="string" or type(value)~="number" then return end
    store.historyLimits[key]=math.floor(value)
    MCHistory.Trim(store,defaultLimit)
end

function MCHistory.ResetLimit(store,defaultLimit,key)
    if type(key)~="string" then return end
    store.historyLimits[key]=nil
    MCHistory.Trim(store,defaultLimit)
end

-- Clear every retained channel (including Combat Log and legacy imports).
-- Preserve limits, channel settings, tabs, and sequence counter.
function MCHistory.Clear(store)
    store.historyByChannel={}
    store.historyHeads={}
    -- Never re-import pre-v0.8.5 arrays after a clear or a relog.
    store.entries=nil
    store.combatEntries=nil
    store.historyMigrated085=true
    invalidate()
end

function MCHistory.Count(store,key)
    local count=0
    local name,bucket
    for name,bucket in pairs(store.historyByChannel or {}) do
        if key==nil or name==key or (key=="CHANNEL" and string.sub(name,1,8)=="CHANNEL:") then
            count=count+table.getn(bucket)
        end
    end
    return count
end

-- Compatibility method for callers requiring a merged list. History UI no
-- longer uses this; it fetches small windows via MCHistory.Window instead.
function MCHistory.Records(store,combat)
    local cached=combat and cachedCombat or cachedChat
    if cached then return cached end
    local list={}
    local key,bucket,i,head
    for key,bucket in pairs(store.historyByChannel or {}) do
        if (key=="COMBAT")==combat then
            head=(store.historyHeads or {})[key] or 1
            for i=1,table.getn(bucket) do
                table.insert(list,getRecord(bucket,head,i))
            end
        end
    end
    table.sort(list,function(a,b) return (a.sequence or 0)<(b.sequence or 0) end)
    if combat then cachedCombat=list else cachedChat=list end
    return list
end

-- Fetch at most (limit + 1) matching records without merging/sorting the
-- entire saved history. Each channel bucket is sequence-ordered; use binary
-- search to find the starting cursor, then a small k-way merge.
-- direction: "older" (latest first) or "newer" (earliest first).
-- pivot: exclusive message sequence boundary; nil means newest/oldest.
-- acceptBucket(key) skips disabled channels before any record work.
-- acceptRecord(record) applies tab filters and Combat Log mini-tab selection.
-- Returns a chronological page plus whether more matches exist in direction.
function MCHistory.Window(store, direction, pivot, limit, acceptBucket, acceptRecord)
    local cursors={}
    local key,bucket,n,head,lo,hi,mid,idx,record,sequence
    local older=direction=="older"
    for key,bucket in pairs(store.historyByChannel or {}) do
        if type(bucket)=="table" and table.getn(bucket)>0 and
           (not acceptBucket or acceptBucket(key)) then
            n=table.getn(bucket)
            head=(store.historyHeads or {})[key] or 1
            if pivot==nil then
                idx=older and n or 1
            else
                lo=1;hi=n
                if older then
                    idx=0
                    while lo<=hi do
                        mid=math.floor((lo+hi)/2)
                        record=getRecord(bucket,head,mid)
                        sequence=record and record.sequence or 0
                        if sequence<pivot then idx=mid;lo=mid+1
                        else hi=mid-1 end
                    end
                else
                    idx=n+1
                    while lo<=hi do
                        mid=math.floor((lo+hi)/2)
                        record=getRecord(bucket,head,mid)
                        sequence=record and record.sequence or 0
                        if sequence>pivot then idx=mid;hi=mid-1
                        else lo=mid+1 end
                    end
                end
            end
            if idx>=1 and idx<=n then
                table.insert(cursors,{bucket=bucket,head=head,index=idx,count=n})
            end
        end
    end
    local gathered={}
    local hasMore=false
    local i,c,best,bestSeq,candidate,cseq
    while true do
        best=nil;bestSeq=nil
        for i=1,table.getn(cursors) do
            c=cursors[i]
            if c.index>=1 and c.index<=c.count then
                candidate=getRecord(c.bucket,c.head,c.index)
                cseq=candidate and candidate.sequence or 0
                if bestSeq==nil or (older and cseq>bestSeq) or (not older and cseq<bestSeq) then
                    best=i;bestSeq=cseq
                end
            end
        end
        if not best then break end
        c=cursors[best]
        candidate=getRecord(c.bucket,c.head,c.index)
        if older then c.index=c.index-1 else c.index=c.index+1 end
        if not acceptRecord or acceptRecord(candidate) then
            if table.getn(gathered)>=limit then hasMore=true;break end
            table.insert(gathered,candidate)
        end
    end
    if older then
        local chronological={}
        for i=table.getn(gathered),1,-1 do table.insert(chronological,gathered[i]) end
        return chronological,hasMore
    end
    return gathered,hasMore
end
