module 'aux.gui.listing'

include 'T'
include 'aux'

local gui = require 'aux.gui'

local ST_COUNT = 0

local ST_ROW_HEIGHT = 15
local ST_ROW_TEXT_SIZE = 14
local ST_HEAD_HEIGHT = 27
local ST_HEAD_SPACE = 2
local DEFAULT_COL_INFO = {{width=1}}

local handlers = {
    OnEnter = function()
        this.row.mouseover = true
        if not this.row.data then return end
        if not this.st.highlightDisabled then
            this.row.highlight:Show()
        end

        local handler = this.st.handlers.OnEnter
        if handler then
            handler(this.st, this.row.data, this)
        end
    end,

    OnLeave = function()
        this.row.mouseover = false
        if not this.row.data then return end
        if this.st.selectionDisabled or not this.st.selected or this.st.selected ~= key(this.st.rowData, this.row.data) then
            this.row.highlight:Hide()
        end

        local handler = this.st.handlers.OnLeave
        if handler then
            handler(this.st, this.row.data, this)
        end
    end,

    OnMouseDown = function()
        if not this.row.data then return end
        this.st:ClearSelection()
        this.st.selected = key(this.st.rowData, this.row.data)
        this.row.highlight:Show()

        local handler = this.st.handlers.OnClick
        if handler then
            handler(this.st, this.row.data, this, arg1)
        end
    end,
}

local methods = {
    RefreshRows = function(st)
        if not st.rowData then return end
        FauxScrollFrame_Update(st.scrollFrame, getn(st.rowData), st.sizes.numRows, ST_ROW_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(st.scrollFrame)
        st.offset = offset

        for i = 1, st.sizes.numRows do
            st.rows[i].data = nil
            if i > getn(st.rowData) then
                st.rows[i]:Hide()
            else
                st.rows[i]:Show()
                local data = st.rowData[i + offset]
                if not data then break end
                st.rows[i].data = data

                if (st.selected == key(st.rowData, data) and not st.selectionDisabled)
                        or (st.highlighted and st.highlighted == key(st.rowData, data))
                        or st.rows[i].mouseover
                then
                    st.rows[i].highlight:Show()
                else
                    st.rows[i].highlight:Hide()
                end

                for j, col in st.rows[i].cols do
                    if st.colInfo[j] then
                        local colData = data.cols[j]
                        if type(colData.value) == 'function' then
	                        col.text:SetText(colData.value(unpack(colData.args)))
                        else
                            col.text:SetText(colData.value)
                        end
                    end
                end
            end
        end
    end,

    SetData = function(st, rowData)
	    for _, row in st.rowData or empty do
		    for _, col in row.cols do release(col) end
		    release(row.cols)
		    release(row)
	    end
        st.rowData = rowData
        st.updateSort = true
        st:RefreshRows()
    end,

    SetSelection = function(st, predicate)
        st:ClearSelection()
        for i, rowDatum in st.rowData do
            if predicate(rowDatum) then
                    st.selected = i
                    st:RefreshRows()
                break
            end
        end
    end,

    GetSelection = function(st)
        return st.selected
    end,

    ClearSelection = function(st)
        st.selected = nil
        st:RefreshRows()
    end,

    DisableSelection = function(st, value)
        st.selectionDisabled = value
    end,

    DisableHighlight = function(st, value)
        st.highlightDisabled = value
    end,

    GetNumRows = function(st)
        return st.sizes.numRows
    end,

    SetHighlighted = function(st, row)
        st.highlighted = row
        st:RefreshRows()
    end,

    Redraw = function(st)
        local width = st:GetWidth() - 14

        if getn(st.colInfo) > 1 or st.colInfo[1].name then
            st.sizes.headHeight = ST_HEAD_HEIGHT
        else
            st.sizes.headHeight = 0
        end
        st.sizes.numRows = max(floor((st:GetParent():GetHeight() - st.sizes.headHeight - ST_HEAD_SPACE) / ST_ROW_HEIGHT), 0)

        st.scrollBar:ClearAllPoints()
        st.scrollBar:SetPoint('BOTTOMRIGHT', st, -1, 1)
        st.scrollBar:SetPoint('TOPRIGHT', st, -1, -st.sizes.headHeight - ST_HEAD_SPACE - 1)

        if st.rows and st.rows[1] then
            st.rows[1]:SetPoint('TOPLEFT', 0, -(st.sizes.headHeight + ST_HEAD_SPACE))
            st.rows[1]:SetPoint('TOPRIGHT', 0, -(st.sizes.headHeight + ST_HEAD_SPACE))
        end

        while getn(st.headCols) < getn(st.colInfo) do
            st:AddColumn()
        end

        for i, col in st.headCols do
            if st.colInfo[i] then
                col:Show()
                col:SetWidth(st.colInfo[i].width * width)
                col:SetHeight(st.sizes.headHeight)
                col.text:SetText(st.colInfo[i].name or '')
                col.text:SetJustifyH(st.colInfo[i].headAlign or 'CENTER')
            else
                col:Hide()
            end
        end

        while getn(st.rows) < st.sizes.numRows do
            st:AddRow()
        end

        for i, row in st.rows do
            if i > st.sizes.numRows then
                row.data = nil
                row:Hide()
            else
                row:Show()
                while getn(row.cols) < getn(st.colInfo) do
                    st:AddRowCol(i)
                end
                for j, col in row.cols do
                    if st.headCols[j] and st.colInfo[j] then
                        col:Show()
                        col:SetWidth(st.colInfo[j].width * width)
                        col.text:SetJustifyH(st.colInfo[j].align or 'LEFT')
                    else
                        col:Hide()
                    end
                end
            end
        end

        st:RefreshRows()
    end,

    AddColumn = function(st)
        local colNum = getn(st.headCols) + 1
        local col = CreateFrame('Frame', st:GetName() .. 'HeadCol' .. colNum, st.contentFrame)
        if colNum == 1 then
            col:SetPoint('TOPLEFT', 0, 0)
        else
            col:SetPoint('TOPLEFT', st.headCols[colNum - 1], 'TOPRIGHT')
        end
        col.st = st
        col.colNum = colNum

	    local text = col:CreateFontString()
	    text:SetAllPoints()
	    text:SetFont(gui.font, 12)
	    text:SetTextColor(color.label.enabled())
        col.text = text

	    local tex = col:CreateTexture()
	    tex:SetAllPoints()
	    tex:SetTexture([[Interface\AddOns\aux-AddOn\WorldStateFinalScore-Highlight]])
	    tex:SetTexCoord(.017, 1, .083, .909)
	    tex:SetAlpha(.5)

        tinsert(st.headCols, col)

        -- add new cells to the rows
        for i, row in st.rows do
            while getn(row.cols) < getn(st.headCols) do
                st:AddRowCol(i)
            end
        end
    end,

    AddRowCol = function(st, rowNum)
        local row = st.rows[rowNum]
        local colNum = getn(row.cols) + 1
        local col = CreateFrame('Frame', nil, row)
        local text = col:CreateFontString()
        col.text = text
        text:SetFont(gui.font, ST_ROW_TEXT_SIZE)
        text:SetJustifyV('CENTER')
        text:SetPoint('TOPLEFT', 1, -1)
        text:SetPoint('BOTTOMRIGHT', -1, 1)
        col:SetHeight(ST_ROW_HEIGHT)
        col:EnableMouse(true)
        for name, func in handlers do
            col:SetScript(name, func)
        end
        col.st = st
        col.row = row

        if colNum == 1 then
            col:SetPoint('TOPLEFT', 0, 0)
        else
            col:SetPoint('TOPLEFT', row.cols[colNum - 1], 'TOPRIGHT')
        end
        tinsert(row.cols, col)
    end,

    AddRow = function(st)
        local row = CreateFrame('Frame', nil, st.contentFrame)
        row:SetHeight(ST_ROW_HEIGHT)
        local rowNum = getn(st.rows) + 1
        if rowNum == 1 then
            row:SetPoint('TOPLEFT', 2, -(st.sizes.headHeight + ST_HEAD_SPACE))
            row:SetPoint('TOPRIGHT', 0, -(st.sizes.headHeight + ST_HEAD_SPACE))
        else
            row:SetPoint('TOPLEFT', 2, -(st.sizes.headHeight + ST_HEAD_SPACE + (rowNum - 1) * ST_ROW_HEIGHT))
            row:SetPoint('TOPRIGHT', 0, -(st.sizes.headHeight + ST_HEAD_SPACE + (rowNum - 1) * ST_ROW_HEIGHT))
        end
        local highlight = row:CreateTexture()
        highlight:SetAllPoints()
        highlight:SetTexture(1, .9, .9, .1)
        highlight:Hide()
        row.highlight = highlight
        row.st = st

        row.cols = T
        st.rows[rowNum] = row
        for i = 1, getn(st.colInfo) do
            st:AddRowCol(rowNum)
        end
    end,

    SetHandler = function(st, event, handler)
        st.handlers[event] = handler
    end,

    SetColInfo = function(st, colInfo)
        colInfo = colInfo or DEFAULT_COL_INFO
        st.colInfo = colInfo
        st:Redraw()
    end,
}

function M.CreateScrollingTable(parent)
    ST_COUNT = ST_COUNT + 1
    local st = CreateFrame('Frame', 'TSMScrollingTable' .. ST_COUNT, parent)
    st:SetAllPoints()

    local contentFrame = CreateFrame('Frame', nil, st)
    contentFrame:SetPoint('TOPLEFT', 0, 0)
    contentFrame:SetPoint('BOTTOMRIGHT', -15, 0)
    st.contentFrame = contentFrame

    local scrollFrame = CreateFrame('ScrollFrame', st:GetName() .. 'ScrollFrame', st, 'FauxScrollFrameTemplate')
    scrollFrame:SetScript('OnVerticalScroll', function()
        FauxScrollFrame_OnVerticalScroll(ST_ROW_HEIGHT, function() st:RefreshRows() end)
    end)
    scrollFrame:SetAllPoints(contentFrame)
    st.scrollFrame = scrollFrame

    local scrollBar = _G[scrollFrame:GetName() .. 'ScrollBar']
    scrollBar:SetWidth(12)
    st.scrollBar = scrollBar
    local thumbTex = scrollBar:GetThumbTexture()
    thumbTex:SetPoint('CENTER', 0, 0)
    thumbTex:SetTexture(color.content.background())
    thumbTex:SetHeight(50)
    thumbTex:SetWidth(12)
    _G[scrollBar:GetName() .. 'ScrollUpButton']:Hide()
    _G[scrollBar:GetName() .. 'ScrollDownButton']:Hide()

    for name, func in methods do
        st[name] = func
    end

    st.isTSMScrollingTable = true
    st.sizes = T
    st.headCols = T
    st.rows = T
    st.handlers = T
    st.colInfo = DEFAULT_COL_INFO

    return st
end