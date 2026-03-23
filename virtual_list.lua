--[[
    @author LinRuiHao
    @date 2025-12-25 10:35:04
    @description
]]

--- @type number 溢出数，防止显示不全
--- @readonly
local Extra = 1

--- @type number 容器内左边距，重新布局时进行正确赋值
local PaddingLeft = 0
--- @type number 容器内右边距，重新布局时进行正确赋值
local PaddingRight = 0
--- @type number 容器内上边距，重新布局时进行正确赋值
local PaddingTop = 0
--- @type number 容器内下边距，重新布局时进行正确赋值
local PaddingBottom = 0


--- @interface VirtualListParam 参数
--- @field direction VirtualList.Direction 滚动方向
--- @field layoutType VirtualList.LayoutType 布局类型
--- @field constraintNum? number 容器内布局约束使用的限定值
--- @field paddingTop? number 容器内上边距
--- @field paddingBottom? number 容器内下边距
--- @field paddingLeft? number 容器内左边距
--- @field paddingRight? number 容器内右边距
--- @field spacingX? number 列表项之间的水平间距
--- @field spacingY? number 列表项之间的垂直间距
--- @field createItemHandler fun():UIWidget 创建列表项回调函数
--- @field updateItemHandler fun(item:UIWidget, index:number):void 更新列表项回调函数
--- @field updateIndexHandler? fun(index:number):void 更新当前索引回调函数
--- @field bounceHeadHandler? fun():void 头部反弹回调函数
--- @field bounceTailHandler? fun():void 尾部反弹回调函数

--- @class VirtualList: UIScrollView 虚拟列表
--- @field private _direction VirtualList.Direction 滚动方向
--- @field private _layoutType VirtualList.LayoutType 布局类型
--- @field private _constraintNum number 容器内布局约束使用的限定值
--- @field private _paddingTop number 容器内上边距
--- @field private _paddingBottom number 容器内下边距
--- @field private _paddingLeft number 容器内左边距
--- @field private _paddingRight number 容器内右边距
--- @field private _spacingX number 列表项之间的水平间距
--- @field private _spacingY number 列表项之间的垂直间距
--- @field private _createItemHandler fun():UIWidget 创建列表项回调函数
--- @field private _updateItemHandler fun(item:UIWidget, index:number):void 更新列表项回调函数
--- @field private _updateIndexHandler fun(index:number):void 更新当前索引回调函数
--- @field private _bounceHeadHandler fun():void 头部反弹回调函数
--- @field private _bounceTailHandler fun():void 尾部反弹回调函数
--- @field private _dataLength number 数据长度
--- @field private _usefulLayoutObj UIWidget[] 在用的布局列表项数组
--- @field private _container UIWidget 布局容器对象
--- @field private _items UIWidget[] 列表项数组
--- @field private _curDataIndex number 当前滚动位置对应的数据索引
--- @field private _minItemSize CCSize 最小列表项尺寸
--- @field private _itemNum number 最大列表项数量
--- @field private _lastContainerPos CCPoint 上一次容器位置
local VirtualList = class("VirtualList", function() return UIScrollView:create() end)

--region 枚举相关


--- @enum VirtualList.Direction 列表滚动方式枚举
VirtualList.Direction = {
    NONE = SCROLLVIEW_DIR_NONE,             -- 无
    HORIZONTAL = SCROLLVIEW_DIR_HORIZONTAL, -- 水平滚动
    VERTICAL = SCROLLVIEW_DIR_VERTICAL,     -- 垂直滚动
}

--- @enum VirtualList.LayoutType 布局类型
VirtualList.LayoutType = {
    NONE = 0,   -- 禁用布局
    LINEAR = 1, -- 线性布局
    GRID = 2,   -- 网格布局
}


--endregion 枚举相关


--- @private
function VirtualList:ctor()
    self._lastContainerPos = ccp(0, 0)
    self._container = self:getInnerContainer()
    self:reset()
    self:_initEvents()
end

--- @public
--- @param param VirtualListParam
--- @return VirtualList
function VirtualList.createVirtualList(param)
    local virtualList = VirtualList.new() --- @type VirtualList
    virtualList:setBounceEnabled(true)
    virtualList:setWidgetZOrder(5)
    virtualList:setDirectionType(param.direction)
    virtualList:setLayoutType(param.layoutType)
    virtualList:setConstraintNum(param.constraintNum)
    virtualList:setPaddingTop(param.paddingTop)
    virtualList:setPaddingBottom(param.paddingBottom)
    virtualList:setPaddingLeft(param.paddingLeft)
    virtualList:setPaddingRight(param.paddingRight)
    virtualList:setSpacingX(param.spacingX)
    virtualList:setSpacingY(param.spacingY)
    virtualList:setCreateItemHandler(param.createItemHandler)
    virtualList:setUpdateItemHandler(param.updateItemHandler)
    virtualList:setUpdateIndexHandler(param.updateIndexHandler)
    virtualList:setBounceHeadHandler(param.bounceHeadHandler)
    virtualList:setBounceTailHandler(param.bounceTailHandler)

    return virtualList
end

--- 载入数据长度
--- @public
--- @param dataLength number 数据长度
function VirtualList:dataLength(dataLength)
    if type(dataLength) ~= "number" or dataLength < 0 then return end
    if self._dataLength == dataLength then
        self:_updateItems()
        return
    end

    if self._itemNum == 0 then -- 首次加载数据
        self._dataLength = dataLength
        self._itemNum = 1
        self:_createItems()
        self:_locateToIndex(self:_getFirstDataIndex())
    else
        self:_onKeepDataLength(dataLength)
    end
end

--- 重置列表
--- @public
function VirtualList:reset()
    self._direction = VirtualList.Direction.NONE
    self._layoutType = VirtualList.LayoutType.NONE
    self._paddingLeft = 0
    self._paddingRight = 0
    self._paddingTop = 0
    self._paddingBottom = 0
    self._spacingX = 0
    self._spacingY = 0
    self._constraintNum = 0
    self._createItemHandler = nil
    self._updateItemHandler = nil
    self._updateIndexHandler = nil
    self._bounceHeadHandler = nil
    self._bounceTailHandler = nil

    self:cleanup()
end

--- 清理数据
--- @public
function VirtualList:cleanup()
    self._usefulLayoutObj = {}
    self._dataLength = 0
    self._itemNum = 0
    self._items = {}
    self._curDataIndex = 0
    self._minItemSize = nil
    self:_setContainerPosition(0, 0)
    self._container:setSize(self:getSize())
    self._container:removeAllChildren()
end

--- 刷新列表
--- @public
function VirtualList:refresh()
    self:_updateItems()
end

--- 跳转到指定索引处
--- @public
--- @param index number 索引值
function VirtualList:gotoIndex(index)
    if type(index) ~= "number" then return end
    if self._curDataIndex == index then return end

    local firstDataIndex = self:_getFirstDataIndex()
    local endDataIndex = self:_getEndDataIndex()
    if index < firstDataIndex or index > endDataIndex then return end

    self:_locateToIndex(index)
end

--region 属性设置相关接口


--- 设置 布局类型
--- @public
--- @param value VirtualList.Direction
function VirtualList:setDirectionType(value)
    if type(value) ~= "number" then return end
    if self._direction == value then return end

    self._direction = value
    self:setDirection(value)
end

--- 获取 布局类型
--- @public
--- @return VirtualList.Direction
function VirtualList:getDirectionType()
    return self._direction
end

--- 设置 布局类型
--- @public
--- @param value VirtualList.LayoutType
function VirtualList:setLayoutType(value)
    if type(value) ~= "number" then return end
    if self._layoutType == value then return end

    self._layoutType = value
end

--- 获取 布局类型
--- @public
--- @return VirtualList.LayoutType
function VirtualList:getLayoutType()
    return self._layoutType
end

--- 设置 容器内左边距
--- @public
--- @param value number
function VirtualList:setPaddingLeft(value)
    if type(value) ~= "number" then return end
    if self._paddingLeft == value then return end

    self._paddingLeft = value
end

--- 获取 容器内左边距
--- @public
--- @return number
function VirtualList:getPaddingLeft()
    return self._paddingLeft
end

--- 设置 容器内右边距
--- @public
--- @param value number
function VirtualList:setPaddingRight(value)
    if type(value) ~= "number" then return end
    if self._paddingRight == value then return end

    self._paddingRight = value
end

--- 获取 容器内右边距
--- @public
--- @return number
function VirtualList:getPaddingRight()
    return self._paddingRight
end

--- 设置 容器内上边距
--- @public
--- @param value number
function VirtualList:setPaddingTop(value)
    if type(value) ~= "number" then return end
    if self._paddingTop == value then return end

    self._paddingTop = value
end

--- 获取 容器内上边距
--- @public
--- @return number
function VirtualList:getPaddingTop()
    return self._paddingTop
end

--- 设置 容器内下边距
--- @public
--- @param value number
function VirtualList:setPaddingBottom(value)
    if type(value) ~= "number" then return end
    if self._paddingBottom == value then return end

    self._paddingBottom = value
end

--- 获取 容器内下边距
--- @public
--- @return number
function VirtualList:getPaddingBottom()
    return self._paddingBottom
end

--- 设置 列表项之间的水平间距
--- @public
--- @param value number
function VirtualList:setSpacingX(value)
    if type(value) ~= "number" then return end
    if self._spacingX == value then return end

    self._spacingX = value
end

--- 获取 列表项之间的水平间距
--- @public
--- @return number
function VirtualList:getSpacingX()
    return self._spacingX
end

--- 设置 列表项之间的垂直间距
--- @public
--- @param value number
function VirtualList:setSpacingY(value)
    if type(value) ~= "number" then return end
    if self._spacingY == value then return end

    self._spacingY = value
end

--- 获取 列表项之间的垂直间距
--- @public
--- @return number
function VirtualList:getSpacingY()
    return self._spacingY
end

--- 设置 容器内布局约束使用的限定值
--- @public
--- @param value number
function VirtualList:setConstraintNum(value)
    if self._layoutType == VirtualList.LayoutType.LINEAR then
        value = 1
    end
    if type(value) ~= "number" then return end
    if self._constraintNum == value then return end


    self._constraintNum = value
end

--- 获取 容器内布局约束使用的限定值
--- @public
--- @return number
function VirtualList:getConstraintNum()
    return self._constraintNum
end

--- 设置 创建列表项回调函数
--- @public
--- @param handler fun():UIWidget
function VirtualList:setCreateItemHandler(handler)
    if type(handler) ~= "function" then return end

    self._createItemHandler = handler
end

--- 设置 更新列表项回调函数
--- @public
--- @param handler fun(item:UIWidget, index:number):void
function VirtualList:setUpdateItemHandler(handler)
    if type(handler) ~= "function" then return end

    self._updateItemHandler = handler
end

--- 设置 更新当前索引回调函数
--- @public
--- @param handler fun(index:number):void
function VirtualList:setUpdateIndexHandler(handler)
    if type(handler) ~= "function" then return end

    self._updateIndexHandler = handler
end

--- 设置 头部反弹回调函数
--- @public
--- @param handler fun():void
function VirtualList:setBounceHeadHandler(handler)
    if type(handler) ~= "function" then return end

    self._bounceHeadHandler = handler
end

--- 设置 尾部反弹回调函数
--- @public
--- @param handler fun():void
function VirtualList:setBounceTailHandler(handler)
    if type(handler) ~= "function" then return end

    self._bounceTailHandler = handler
end

--- 获取 当前数据索引
--- @public
--- @return number
function VirtualList:getCurDataIndex()
    return self._curDataIndex
end

--- 获取 数据长度
--- @public
--- @return number
function VirtualList:getDataLength()
    return self._dataLength
end

--endregion 属性设置相关接口

--- @private
function VirtualList:_createItems()
    local itemNum = #self._items

    while (itemNum < self._itemNum) do
        local item = self._createItemHandler()
        self:addChild(item)
        table.insert(self._items, item)
        if self:_tryUpdateMinItemSize(item:getSize()) then
            self:_tryUpdateItemNum()
        end
        itemNum = itemNum + 1
    end
end

--- @private
--- @param itemSize CCSize
--- @return boolean
function VirtualList:_tryUpdateMinItemSize(itemSize)
    if not self._minItemSize then
        self._minItemSize = CCSizeMake(itemSize.width, itemSize.height)
        return true
    end

    local result = false

    if self._direction == VirtualList.Direction.HORIZONTAL then
        result = self._minItemSize.width > itemSize.width
    elseif self._direction == VirtualList.Direction.VERTICAL then
        result = self._minItemSize.height > itemSize.height
    end

    if result then
        self._minItemSize:setSize(itemSize.width, itemSize.height)
    end

    return result
end

--- @private
--- @return boolean
function VirtualList:_tryUpdateItemNum()
    local result = false
    local num = 0
    local max = 0
    local viewSize = self:getSize()

    if self._direction == VirtualList.Direction.HORIZONTAL then
        num = math.ceil(viewSize.width / (self._minItemSize.width + self._spacingX))
    elseif self._direction == VirtualList.Direction.VERTICAL then
        num = math.ceil(viewSize.height / (self._minItemSize.height + self._spacingY))
    end

    if self._layoutType == VirtualList.LayoutType.LINEAR then
        num = num + Extra
    elseif self._layoutType == VirtualList.LayoutType.GRID then
        num = (num + Extra) * self._constraintNum
    end

    result = self._itemNum ~= num
    self._itemNum = num

    return result
end

--- @private
function VirtualList:_initEvents()
    self:addEventListener(function()
        -- if self._itemNum > 0 then
        --     logger.info(string.format(
        --         "VirtualList:_onSVEventScrolling1 => \n index:[%s,%s] itemNum:%s \n boundary[top%s,bottom%s,left%s,right%s] viewSize[%s,%s] containerSize[%s,%s] itemSize[%s,%s] \n position[%s,%s] _lastContainerPos[%s,%s]",
        --         self._curDataIndex, self._dataLength, self._itemNum,
        --         self:_getTopBoundary(), self:_getBottomBoundary(), self:_getLeftBoundary(), self:_getRightBoundary(),
        --         self:getSize().width, self:getSize().height, self._container:getSize().width,
        --         self._container:getSize().height,
        --         self._items[1]:getSize().width, self._items[1]:getSize().height,
        --         self._container:getPosition().x, self._container:getPosition().y,
        --         self._lastContainerPos.x, self._lastContainerPos.y
        --     ))
        -- end

        self:_onSVEventScrolling()

        -- if self._itemNum > 0 then
        --     logger.info(string.format(
        --         "VirtualList:_onSVEventScrolling2 => \n index:[%s,%s] itemNum:%s \n boundary[top%s,bottom%s,left%s,right%s] viewSize[%s,%s] containerSize[%s,%s] itemSize[%s,%s] \n position[%s,%s] _lastContainerPos[%s,%s]",
        --         self._curDataIndex, self._dataLength, self._itemNum,
        --         self:_getTopBoundary(), self:_getBottomBoundary(), self:_getLeftBoundary(), self:_getRightBoundary(),
        --         self:getSize().width, self:getSize().height, self._container:getSize().width,
        --         self._container:getSize().height,
        --         self._items[1]:getSize().width, self._items[1]:getSize().height,
        --         self._container:getPosition().x, self._container:getPosition().y,
        --         self._lastContainerPos.x, self._lastContainerPos.y
        --     ))
        -- end
    end, SCROLLVIEW_EVENT_SCROLLING)

    self:addEventListener(function()
        self:_onSVEventBounceTop()
    end, SCROLLVIEW_EVENT_BOUNCE_TOP)

    self:addEventListener(function()
        self:_onSVEventBounceBottom()
    end, SCROLLVIEW_EVENT_BOUNCE_BOTTOM)

    self:addEventListener(function()
        self:_onSVEventBounceLeft()
    end, SCROLLVIEW_EVENT_BOUNCE_LEFT)

    self:addEventListener(function()
        self:_onSVEventBounceRight()
    end, SCROLLVIEW_EVENT_BOUNCE_RIGHT)
end

--- @private
--- @return number
function VirtualList:_getFirstItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local endDataIndex = self:_getEndDataIndex()
    local index = (math.ceil(self._curDataIndex / self._constraintNum) - 1) * self._constraintNum + 1
    local max = math.ceil(endDataIndex / self._constraintNum) * self._constraintNum - self._itemNum + 1
    max = math.max(max, firstDataIndex)
    index = math.min(index, max)

    return index
end

--- @private
--- @return number
function VirtualList:_getEndItemIndex()
    local firstItemIndex = self:_getFirstItemIndex()
    local endDataIndex = self:_getEndDataIndex()
    return math.min(firstItemIndex + self._itemNum - 1, endDataIndex)
end

--- @private
--- @return number
function VirtualList:_getFirstDataIndex()
    local index = 0
    if self._dataLength > 0 then
        index = 1
    end
    return index
end

--- @private
--- @return number
function VirtualList:_getEndDataIndex()
    return self._dataLength
end

--- @private
--- @param dataLength number
function VirtualList:_onKeepDataLength(dataLength)
    local fnGetKeepOffset = function(index)
        local position = self._container:getPosition()
        local offset = 0
        if self._direction == VirtualList.Direction.VERTICAL then
            local headBoundary = self:_getTopBoundary()
            local start = self:_getStartPointVertical(index)
            offset = math.abs(position.y - headBoundary) - start
        elseif self._direction == VirtualList.Direction.HORIZONTAL then
            local headBoundary = self:_getLeftBoundary()
            local start = self:_getStartPointHorizontal(index)
            offset = math.abs(position.x - headBoundary) - start
        end
        return offset
    end

    local fnSetKeepPosition = function(offset)
        local position = self._container:getPosition()
        if self._direction == VirtualList.Direction.VERTICAL then
            local start = self:_getStartPointVertical()
            local headBoundary = self:_getTopBoundary()
            local pos = headBoundary + start + offset
            self:_setContainerPosition(position.x, pos)
        elseif self._direction == VirtualList.Direction.HORIZONTAL then
            local start = self:_getStartPointHorizontal()
            local headBoundary = self:_getLeftBoundary()
            local pos = headBoundary - start - offset
            self:_setContainerPosition(pos, position.y)
        end
    end

    local fnDoKeep = function(num)
        local itemIndex = self:_getFirstItemIndexInView()
        local offset = fnGetKeepOffset(itemIndex)

        self._dataLength = num
        self:_setCurDataIndex(itemIndex)
        self:_updateItems()

        fnSetKeepPosition(offset)
    end

    if dataLength < self._dataLength then
        if self._curDataIndex >= dataLength then
            self._dataLength = dataLength
            self:_locateToIndex(dataLength, true)
        else
            fnDoKeep(dataLength)
        end
    else
        if self._dataLength == 0 then
            self._dataLength = dataLength
            self:_locateToIndex(self:_getFirstDataIndex(), true)
        else
            local endItemIndex = self:_getEndItemIndex()
            local endDataIndex = self:_getEndDataIndex()
            if endItemIndex < endDataIndex then
                self._dataLength = dataLength
            else
                fnDoKeep(dataLength)
            end
        end
    end
end

--- @private
--- @param index number
--- @param forceUpdate? boolean
function VirtualList:_locateToIndex(index, forceUpdate)
    if type(index) ~= "number" then return end
    if type(forceUpdate) ~= "boolean" then
        forceUpdate = false
    end

    local oldFirstItemIndex = self:_getFirstItemIndex()

    self:_setCurDataIndex(index)

    local firstItemIndex = self:_getFirstItemIndex()

    if forceUpdate then
        self:_updateItems()
    elseif oldFirstItemIndex ~= firstItemIndex then
        self:_updateItems()
    end

    local containerPos = self._container:getPosition()
    if self._direction == VirtualList.Direction.VERTICAL then
        local headBoundary = self:_getTopBoundary()
        local tailBoundary = self:_getBottomBoundary()
        local offset = self:_getStartPointVertical()
        local pos = headBoundary + offset

        if pos >= tailBoundary then
            pos = tailBoundary
        end
        self:_setContainerPosition(containerPos.x, pos)
    elseif self._direction == VirtualList.Direction.HORIZONTAL then
        local headBoundary = self:_getLeftBoundary()
        local tailBoundary = self:_getRightBoundary()
        local offset = self:_getStartPointHorizontal()
        local pos = headBoundary - offset

        if pos < tailBoundary then
            pos = tailBoundary
        end
        self:_setContainerPosition(pos, containerPos.y)
    end
end

--- @private
--- @param value number
function VirtualList:_setCurDataIndex(value)
    if self._curDataIndex == value then return end
    self._curDataIndex = value
    if type(self._updateIndexHandler) == "function" then
        self._updateIndexHandler(self._curDataIndex)
    end
end

--- @private
--- @param index number
--- @return number
function VirtualList:_convertToStepIndex(index)
    return (math.ceil(index / self._constraintNum) - 1) * self._constraintNum + 1
end

--- @private
--- @param index number
--- @param isNext boolean
--- @return number
function VirtualList:_doStepOfDataIndex(index, isNext)
    if isNext then
        local endDataIndex = self:_getEndDataIndex()
        index = index + self._constraintNum
        index = math.min(index, endDataIndex)
    else
        local firstDataIndex = self:_getFirstDataIndex()
        index = index - self._constraintNum
        index = math.max(index, firstDataIndex)
    end
    return index
end

--- @private
function VirtualList:_getFirstItemIndexInView()
    local index = self:_convertToStepIndex(self._curDataIndex)
    if self._direction == VirtualList.Direction.VERTICAL then
        local headBoundary = self:_getTopBoundary()
        local tailBoundary = self:_getBottomBoundary()

        while true do
            local startPoint = self:_getStartPointVertical(index)
            if headBoundary + startPoint <= tailBoundary then
                break
            end
            index = self:_doStepOfDataIndex(index, false)
        end
    elseif self._direction == VirtualList.Direction.HORIZONTAL then
        local headBoundary = self:_getLeftBoundary()
        local tailBoundary = self:_getRightBoundary()

        while true do
            local startPoint = self:_getStartPointHorizontal(index)
            if headBoundary - startPoint >= tailBoundary then
                break
            end
            index = self:_doStepOfDataIndex(index, false)
        end
    end
    return index
end

--- @private
--- @param index? number
--- @return number
function VirtualList:_getStartPointVertical(index)
    if type(index) ~= "number" then
        index = self._curDataIndex
    end
    local firstItemIndex = self:_getFirstItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local delta = self._constraintNum
    local curIdx = firstItemIndex
    local endIdx = (math.ceil(index / delta) - 1) * delta
    local pos = 0

    for i = 1, self._itemNum, delta do
        if curIdx > endIdx then break end
        local size = self._items[i]:getSize()
        local spacing = self._spacingY
        if curIdx == firstDataIndex then
            spacing = self._paddingTop
        end

        pos = pos + size.height + spacing
        curIdx = curIdx + delta
    end

    return pos
end

--- @private
--- @param index? number
--- @return number
function VirtualList:_getStartPointHorizontal(index)
    if type(index) ~= "number" then
        index = self._curDataIndex
    end
    local firstItemIndex = self:_getFirstItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local delta = self._constraintNum
    local curIdx = firstItemIndex
    local endIdx = (math.ceil(index / delta) - 1) * delta
    local pos = 0

    for i = 1, self._itemNum, delta do
        if curIdx > endIdx then break end
        local size = self._items[i]:getSize()
        local spacing = self._spacingX
        if curIdx == firstDataIndex then
            spacing = self._paddingLeft
        end

        pos = pos + size.width + spacing
        curIdx = curIdx + delta
    end

    return pos
end

--- @private
--- @param index? number
--- @return number
function VirtualList:_getEndPointVertical(index)
    if type(index) ~= "number" then
        index = self._curDataIndex
    end
    local firstItemIndex = self:_getFirstItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local delta = self._constraintNum
    local curIdx = firstItemIndex
    local endIdx = (math.ceil(index / delta) - 1) * delta + delta
    local pos = 0

    for i = 1, self._itemNum, delta do
        if curIdx > endIdx then break end
        local size = self._items[i]:getSize()
        local spacing = self._spacingY
        if curIdx == firstDataIndex then
            spacing = self._paddingTop
        end

        pos = pos + size.height + spacing
        curIdx = curIdx + delta
    end

    return pos
end

--- @private
--- @param index? number
--- @return number
function VirtualList:_getEndPointHorizontal(index)
    if type(index) ~= "number" then
        index = self._curDataIndex
    end

    local firstItemIndex = self:_getFirstItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local delta = self._constraintNum
    local curIdx = firstItemIndex
    local endIdx = (math.ceil(index / delta) - 1) * delta + delta
    local pos = 0

    for i = 1, self._itemNum, delta do
        if curIdx > endIdx then break end
        local size = self._items[i]:getSize()
        local spacing = self._spacingX
        if curIdx == firstDataIndex then
            spacing = self._paddingLeft
        end

        pos = pos + size.width + spacing
        curIdx = curIdx + delta
    end

    return pos
end

--- @private
--- @return number
function VirtualList:_getTopBoundary()
    local containerSize = self._container:getSize()
    local containerAnchor = self._container:getAnchorPoint()
    local viewSize = self:getSize()
    local viewAnchor = self:getAnchorPoint()

    return (1 - viewAnchor.y) * viewSize.height - (1 - containerAnchor.y) * containerSize.height
end

--- @private
--- @return number
function VirtualList:_getBottomBoundary()
    local containerSize = self._container:getSize()
    local containerAnchor = self._container:getAnchorPoint()
    local viewSize = self:getSize()
    local viewAnchor = self:getAnchorPoint()

    return (0 - viewAnchor.y) * viewSize.height + (0 - containerAnchor.y) * containerSize.height
end

--- @private
--- @return number
function VirtualList:_getLeftBoundary()
    local containerSize = self._container:getSize()
    local containerAnchor = self._container:getAnchorPoint()
    local viewSize = self:getSize()
    local viewAnchor = self:getAnchorPoint()

    return (0 - viewAnchor.x) * viewSize.width + (0 - containerAnchor.x) * containerSize.width
end

--- @private
--- @return number
function VirtualList:_getRightBoundary()
    local containerSize = self._container:getSize()
    local containerAnchor = self._container:getAnchorPoint()
    local viewSize = self:getSize()
    local viewAnchor = self:getAnchorPoint()

    return (1 - viewAnchor.x) * viewSize.width - (1 - containerAnchor.x) * containerSize.width
end

--- @private
--- @param x number
--- @param y number
function VirtualList:_setContainerPosition(x, y)
    self._container:setPosition(ccp(x, y))
    self._lastContainerPos:setPoint(x, y)
end

--- @private
--- @param isNext boolean
function VirtualList:_onScrollingIndex(isNext)
    local index = self:_convertToStepIndex(self._curDataIndex)
    index = self:_doStepOfDataIndex(index, isNext)
    self:_setCurDataIndex(index)
end

--- @private
--- @param isNext boolean
function VirtualList:_onScrollingContainerPosition(isNext)
    local position = self._container:getPosition()

    if self._direction == VirtualList.Direction.VERTICAL then
        local pos = self:_getTopBoundary()
        if not isNext then
            local offset = self:_getEndPointVertical()
            pos = pos + offset
        end
        self:_setContainerPosition(position.x, pos)
    elseif self._direction == VirtualList.Direction.HORIZONTAL then
        local pos = self:_getLeftBoundary()
        if not isNext then
            local offset = self:_getEndPointHorizontal()
            pos = pos - offset
        end
        self:_setContainerPosition(pos, position.y)
    end
end

--- @private
function VirtualList:_updateItems()
    local firstDataIndex = self:_getFirstDataIndex()
    local endDataIndex = self:_getEndDataIndex()
    local index = self:_getFirstItemIndex()
    local changeMinSize = false

    for _, item in ipairs(self._items) do
        if index > 0 and index >= firstDataIndex and index <= endDataIndex then
            item:setVisible(true)
            self._updateItemHandler(item, index)
            if self:_tryUpdateMinItemSize(item:getSize()) then
                changeMinSize = true
            end
        else
            item:setVisible(false)
        end
        index = index + 1
    end
    if changeMinSize then
        if self:_tryUpdateItemNum() then
            self:_createItems()
            self:_updateItems()
            return
        end
    end

    self:_relayout()
end

--- @private
function VirtualList:_relayout()
    local firstItemIndex = self:_getFirstItemIndex()
    local endItemIndex = self:_getEndItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local endDataIndex = self:_getEndDataIndex()

    PaddingTop = self._paddingTop
    PaddingBottom = self._paddingBottom
    PaddingLeft = self._paddingLeft
    PaddingRight = self._paddingRight

    if self._dataLength > self._itemNum then
        if self._direction == VirtualList.Direction.VERTICAL then
            if self._layoutType == VirtualList.LayoutType.LINEAR or self._layoutType == VirtualList.LayoutType.GRID then
                PaddingTop = self._spacingY
                PaddingBottom = 0
                if firstItemIndex == firstDataIndex then
                    PaddingTop = self._paddingTop
                elseif endItemIndex == endDataIndex then
                    PaddingBottom = self._paddingBottom
                end
            end
        elseif self._direction == VirtualList.Direction.HORIZONTAL then
            if self._layoutType == VirtualList.LayoutType.LINEAR or self._layoutType == VirtualList.LayoutType.GRID then
                PaddingLeft = self._spacingX
                PaddingRight = 0
                if firstItemIndex == firstDataIndex then
                    PaddingLeft = self._paddingLeft
                elseif endItemIndex == endDataIndex then
                    PaddingRight = self._paddingRight
                end
            end
        end
    end

    self:_doLayout()
end

--- @private
function VirtualList:_onSVEventScrolling()
    if not (self._dataLength > 0 and self._itemNum > 0) then return end
    local position = self._container:getPosition()
    if self._lastContainerPos.x == position.x and self._lastContainerPos.y == position.y then return end

    local firstItemIndex = self:_getFirstItemIndex()
    local endItemIndex = self:_getEndItemIndex()
    local firstDataIndex = self:_getFirstDataIndex()
    local endDataIndex = self:_getEndDataIndex()
    local isChange = false
    local isNext = nil

    if self._direction == VirtualList.Direction.VERTICAL then
        local headBoundary = self:_getTopBoundary()
        local tailBoundary = self:_getBottomBoundary()
        local threshold = 0
        if self._lastContainerPos.y < position.y then -- 向上滚动
            if not (endItemIndex == endDataIndex and position.y >= tailBoundary) then
                local offset = self:_getEndPointVertical()
                threshold = headBoundary + offset
                if position.y >= threshold then
                    isNext = true
                    if self._curDataIndex == firstItemIndex and endItemIndex ~= endDataIndex then
                        isChange = true
                    end
                end
            end
        else -- 向下滚动
            if not (firstItemIndex == firstDataIndex and position.y <= headBoundary) then
                local offset = self:_getStartPointVertical()
                threshold = headBoundary + offset
                if position.y <= threshold then
                    isNext = false
                    if self._curDataIndex - self._constraintNum < firstItemIndex then
                        isChange = true
                    end
                end
            end
        end
    elseif self._direction == VirtualList.Direction.HORIZONTAL then
        local headBoundary = self:_getLeftBoundary()
        local tailBoundary = self:_getRightBoundary()
        local threshold = 0
        if self._lastContainerPos.x > position.x then -- 向左滚动
            if not (endItemIndex == endDataIndex and position.x <= tailBoundary) then
                local offset = self:_getEndPointHorizontal()
                threshold = headBoundary - offset
                if position.x <= threshold then
                    isNext = true
                    if self._curDataIndex == firstItemIndex and endItemIndex ~= endDataIndex then
                        isChange = true
                    end
                end
            end
        else -- 向右滚动
            if not (firstItemIndex == firstDataIndex and position.x >= headBoundary) then
                local offset = self:_getStartPointHorizontal()
                threshold = headBoundary - offset
                if position.x >= threshold then
                    isNext = false
                    if self._curDataIndex - self._constraintNum < firstItemIndex then
                        isChange = true
                    end
                end
            end
        end
    end

    self._lastContainerPos:setPoint(position.x, position.y)

    if isNext ~= nil then
        self:_onScrollingIndex(isNext)
    end
    if isChange then
        self:_updateItems()
        self:_onScrollingContainerPosition(isNext)
    end
end

--- @private
function VirtualList:_onSVEventBounceTop()
    if self._direction ~= VirtualList.Direction.VERTICAL then return end

    if type(self._bounceHeadHandler) == "function" then
        self._bounceHeadHandler()
    end
end

--- @private
function VirtualList:_onSVEventBounceBottom()
    if self._direction ~= VirtualList.Direction.VERTICAL then return end

    if type(self._bounceTailHandler) == "function" then
        self._bounceTailHandler()
    end
end

--- @private
function VirtualList:_onSVEventBounceLeft()
    if self._direction ~= VirtualList.Direction.HORIZONTAL then return end

    if type(self._bounceHeadHandler) == "function" then
        self._bounceHeadHandler()
    end
end

--- @private
function VirtualList:_onSVEventBounceRight()
    if self._direction ~= VirtualList.Direction.HORIZONTAL then return end

    if type(self._bounceTailHandler) == "function" then
        self._bounceTailHandler()
    end
end

--region 布局逻辑

--- @private
function VirtualList:_doLayout()
    self:_checkUsefulObj()
    if self._layoutType == VirtualList.LayoutType.LINEAR then
        self:_doLayoutLinear()
    elseif self._layoutType == VirtualList.LayoutType.GRID then
        self:_doLayoutGrid()
    end
end

--- @private
function VirtualList:_checkUsefulObj()
    self._usefulLayoutObj = {}
    for k, v in ipairs(self._items) do
        if v:isVisible() then
            table.insert(self._usefulLayoutObj, v)
        end
    end
end

--- @private
function VirtualList:_doLayoutLinear()
    if self._direction == VirtualList.Direction.HORIZONTAL then
        local fnPositionY = function(child)
            local padding = 0
            if PaddingTop ~= 0 then
                padding = PaddingTop
            elseif PaddingBottom ~= 0 then
                padding = -PaddingBottom
            end
            return padding
        end
        local newWidth = self:_getHorizontalBaseWidth()

        -- 由于 UIScrollView 的逻辑限制，当内容尺寸小于 UIScrollView 的尺寸时，会导致排版与预期不符，并且点击事件还会导致位置摇摆，因此做如是处理以解决问题
        newWidth = math.max(newWidth, self:getSize().width)

        self:_doLayoutHorizontally(newWidth, false, fnPositionY, true)
        self._container:setSize(CCSizeMake(newWidth, self._container:getSize().height))
    elseif self._direction == VirtualList.Direction.VERTICAL then
        local fnPositionX = function(child)
            local padding = 0
            if PaddingLeft ~= 0 then
                padding = PaddingLeft
            elseif PaddingRight ~= 0 then
                padding = -PaddingRight
            end
            return padding
        end
        local newHeight = self:_getVerticalBaseHeight()

        -- 由于 UIScrollView 的逻辑限制，当内容尺寸小于 UIScrollView 的尺寸时，会导致排版与预期不符，并且点击事件还会导致位置摇摆，因此做如是处理以解决问题
        newHeight = math.max(newHeight, self:getSize().height)

        self:_doLayoutVertically(newHeight, false, fnPositionX, true)
        self._container:setSize(CCSizeMake(self._container:getSize().width, newHeight))
    end
end

--- @private
--- @param baseWidth number
--- @param rowBreak boolean
--- @param fnPositionY fun(child: UIWidget, topOffset: number)
--- @param applyChildren boolean
--- @return number
function VirtualList:_doLayoutHorizontally(baseWidth, rowBreak, fnPositionY, applyChildren)
    local layoutAnchor = self._container:getAnchorPoint()
    local limit = self:_getFixedBreakingNum()
    local startPos = -layoutAnchor.x * baseWidth + PaddingLeft
    local nextX = startPos - self._spacingX
    local totalHeight = 0
    local rowMaxHeight = 0
    local tempMaxHeight = 0
    local maxHeight = 0
    local isBreak = false
    local paddingH = self:_getPaddingH()

    local children = self._usefulLayoutObj
    for i = 1, #children do
        local child = children[i]
        local childSize = child:getSize()
        local childAnchor = child:getAnchorPoint()

        local anchorX = math.abs(0 - childAnchor.x)
        local childBoundingBoxWidth = childSize.width
        local childBoundingBoxHeight = childSize.height

        if childBoundingBoxHeight > tempMaxHeight then
            maxHeight = math.max(tempMaxHeight, maxHeight)
            rowMaxHeight = tempMaxHeight ~= 0 and tempMaxHeight or childBoundingBoxHeight
            tempMaxHeight = childBoundingBoxHeight
        end

        nextX = nextX + (anchorX * childBoundingBoxWidth + self._spacingX)
        local rightBoundaryOfChild = (1 - anchorX) * childBoundingBoxWidth

        if rowBreak then
            if limit > 0 then
                isBreak = ((i - 1) / limit) > 0 and ((i - 1) % limit == 0)
                if isBreak then
                    rowMaxHeight = tempMaxHeight > childBoundingBoxHeight and tempMaxHeight or rowMaxHeight
                end
            elseif childBoundingBoxWidth > baseWidth - paddingH then
                if nextX > startPos + anchorX * childBoundingBoxWidth then
                    isBreak = true
                end
            else
                local boundary = (1 - layoutAnchor.x) * baseWidth
                local rowBreakBoundary = nextX + rightBoundaryOfChild + PaddingRight
                isBreak = math.abs(rowBreakBoundary) > math.abs(boundary)
            end

            if isBreak then
                nextX = startPos + anchorX * childBoundingBoxWidth
                if childBoundingBoxHeight ~= tempMaxHeight then
                    rowMaxHeight = tempMaxHeight
                end
                totalHeight = totalHeight + rowMaxHeight + self._spacingY
                rowMaxHeight = tempMaxHeight
                tempMaxHeight = childBoundingBoxHeight
            end
        end

        local finalPositionY = fnPositionY(child, totalHeight)
        if applyChildren then
            child:setPosition(ccp(nextX, finalPositionY))
        end

        nextX = nextX + rightBoundaryOfChild
    end

    rowMaxHeight = math.max(rowMaxHeight, tempMaxHeight)
    local containerResizeBoundary = math.max(maxHeight, totalHeight + rowMaxHeight) + self:_getPaddingV()
    return containerResizeBoundary
end

--- @private
--- @param baseWidth number
--- @param rowBreak boolean
--- @param fnPositionX fun(child: UIWidget, leftOffset: number)
--- @param applyChildren boolean
--- @return number
function VirtualList:_doLayoutVertically(baseHeight, columnBreak, fnPositionX, applyChildren)
    local layoutAnchor = self._container:getAnchorPoint()
    local limit = self:_getFixedBreakingNum()

    local startPos = (1 - layoutAnchor.y) * baseHeight - PaddingTop
    local nextY = startPos + self._spacingY
    local tempMaxWidth = 0
    local maxWidth = 0
    local colMaxWidth = 0
    local totalWidth = 0
    local isBreak = false
    local paddingV = self:_getPaddingV()

    local children = self._usefulLayoutObj
    for i = 1, #children do
        local child = children[i]
        local childSize = child:getSize()
        local childAnchor = child:getAnchorPoint()

        local anchorY = math.abs(1 - childAnchor.y)
        local childBoundingBoxWidth = childSize.width
        local childBoundingBoxHeight = childSize.height

        if childBoundingBoxWidth > tempMaxWidth then
            maxWidth = math.max(tempMaxWidth, maxWidth)
            colMaxWidth = tempMaxWidth ~= 0 and tempMaxWidth or childBoundingBoxWidth
            tempMaxWidth = childBoundingBoxWidth
        end

        nextY = nextY - (anchorY * childBoundingBoxHeight + self._spacingY)
        local topBoundaryOfChild = -(1 - anchorY) * childBoundingBoxHeight

        if columnBreak then
            if limit > 0 then
                isBreak = ((i - 1) / limit) > 0 and ((i - 1) % limit == 0)
                if isBreak then
                    colMaxWidth = tempMaxWidth > childBoundingBoxHeight and tempMaxWidth or colMaxWidth
                end
            elseif childBoundingBoxHeight > baseHeight - paddingV then
                if nextY > startPos - anchorY * childBoundingBoxHeight then
                    isBreak = true
                end
            else
                local boundary = (1 - 1 - layoutAnchor.y) * baseHeight
                local columnBreakBoundary = nextY + topBoundaryOfChild - PaddingBottom
                isBreak = math.abs(columnBreakBoundary) > math.abs(boundary)
            end

            if isBreak then
                nextY = startPos - anchorY * childBoundingBoxHeight
                if childBoundingBoxWidth ~= tempMaxWidth then
                    colMaxWidth = tempMaxWidth
                end
                totalWidth = totalWidth + colMaxWidth + self._spacingX
                colMaxWidth = tempMaxWidth
                tempMaxWidth = childBoundingBoxWidth
            end
        end

        local finalPositionX = fnPositionX(child, totalWidth)
        if applyChildren then
            child:setPosition(ccp(finalPositionX, nextY))
        end

        nextY = nextY + topBoundaryOfChild
    end

    colMaxWidth = math.max(colMaxWidth, tempMaxWidth)
    local containerResizeBoundary = math.max(maxWidth, totalWidth + colMaxWidth) + self:_getPaddingH()
    return containerResizeBoundary
end

--- @private
--- @param layoutAnchor CCPoint
--- @param layoutSize CCSize
function VirtualList:_doLayoutGridAxisHorizontal(layoutAnchor, layoutSize)
    local baseWidth = layoutSize.width
    local bottomBoundaryOfLayout = (1 - layoutAnchor.y) * layoutSize.height

    local fnPositionY = function(child, topOffset)
        local size = child:getSize()
        local anchor = child:getAnchorPoint()

        return bottomBoundaryOfLayout - (topOffset + (1 - anchor.y) * size.height + PaddingTop)
    end

    local newHeight = self:_doLayoutHorizontally(baseWidth, true, fnPositionY, false)

    -- 由于 UIScrollView 的逻辑限制，当内容尺寸小于 UIScrollView 的尺寸时，会导致排版与预期不符，并且点击事件还会导致位置摇摆，因此做如是处理以解决问题
    newHeight = math.max(newHeight, self:getSize().height)

    bottomBoundaryOfLayout = (1 - layoutAnchor.y) * newHeight

    self:_doLayoutHorizontally(baseWidth, true, fnPositionY, true)
    self._container:setSize(CCSizeMake(baseWidth, newHeight))
end

--- @private
--- @param layoutAnchor CCPoint
--- @param layoutSize CCSize
function VirtualList:_doLayoutGridAxisVertical(layoutAnchor, layoutSize)
    local baseHeight = layoutSize.height
    local leftBoundaryOfLayout = -layoutAnchor.x * layoutSize.width

    local fnPositionX = function(child, leftOffset)
        local size = child:getSize()
        local anchor = child:getAnchorPoint()

        return leftBoundaryOfLayout + (leftOffset + anchor.x * size.width + PaddingLeft)
    end

    local newWidth = self:_doLayoutVertically(baseHeight, true, fnPositionX, false)

    -- 由于 UIScrollView 的逻辑限制，当内容尺寸小于 UIScrollView 的尺寸时，会导致排版与预期不符，并且点击事件还会导致位置摇摆，因此做如是处理以解决问题
    newWidth = math.max(newWidth, self:getSize().width)

    leftBoundaryOfLayout = -layoutAnchor.x * newWidth

    self:_doLayoutVertically(baseHeight, true, fnPositionX, true)
    self._container:setSize(CCSizeMake(newWidth, baseHeight))
end

--- @private
function VirtualList:_doLayoutGrid()
    local layoutAnchor = self._container:getAnchorPoint()
    local layoutSize = self._container:getSize()

    if self._direction == VirtualList.Direction.VERTICAL then
        self:_doLayoutGridAxisHorizontal(layoutAnchor, layoutSize)
    elseif self._direction == VirtualList.Direction.HORIZONTAL then
        self:_doLayoutGridAxisVertical(layoutAnchor, layoutSize)
    end
end

--- @private
--- @param horizontal? boolean
--- @return number
function VirtualList:_getHorizontalBaseWidth(horizontal)
    horizontal = horizontal ~= false
    local children = self._usefulLayoutObj
    local baseSize = 0
    local activeChildCount = #children

    for i = 1, #children do
        local child = children[i]
        baseSize = baseSize + child:getSize().width
    end

    baseSize = baseSize + (activeChildCount - 1) * self._spacingX + self:_getPaddingH()

    return baseSize
end

--- @private
--- @return number
function VirtualList:_getVerticalBaseHeight()
    local children = self._usefulLayoutObj
    local baseSize = 0
    local activeChildCount = #children

    for i = 1, #children do
        local child = children[i]
        baseSize = baseSize + child:getSize().height
    end

    baseSize = baseSize + (activeChildCount - 1) * self._spacingY + self:_getPaddingV()

    return baseSize
end

--- @private
--- @return number
function VirtualList:_getPaddingH()
    return PaddingLeft + PaddingRight
end

--- @private
--- @return number
function VirtualList:_getPaddingV()
    return PaddingTop + PaddingBottom
end

--- @private
--- @return number
function VirtualList:_getFixedBreakingNum()
    local num = 0

    if self._layoutType == VirtualList.LayoutType.GRID then
        if self._constraintNum > 0 then
            num = self._constraintNum
        end
    end

    return num
end

--endregion 布局逻辑

return VirtualList
