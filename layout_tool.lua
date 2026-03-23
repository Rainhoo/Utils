--[[
    @author LinRuiHao
    @date 2025-12-25 10:35:04
    @description 参照 cocos creator 3.8.6 版本的layout.ts
]]


--- LayoutTool 能将容器对象的所有子节点进行统一排版。
--- 由于引擎缺乏相关事件支持，不能有效的自动更新布局，所以设计成工具类。
--- 注意
--- 1.不会考虑子节点的缩放和旋转。
--- 2.任何变化都需要手动调用 LayoutTool.runLayout 进行更新布局

--- @class LayoutTool 布局工具
local LayoutTool = {}


--- @enum LayoutToolLayoutType 布局类型
LayoutTool.LayoutType = {
    NONE = 0,       -- 禁用布局
    HORIZONTAL = 1, -- 水平布局
    VERTICAL = 2,   -- 垂直布局
    GRID = 3        -- 网格布局
}

--- @enum LayoutToolVerticalDirection 垂直方向布局方式。
LayoutTool.VerticalDirection = {
    BOTTOM_TO_TOP = 0, -- 从下到上排列。
    TOP_TO_BOTTOM = 1  -- 从上到下排列。
}

--- @enum LayoutToolHorizontalDirection 水平方向布局方式。
LayoutTool.HorizontalDirection = {
    LEFT_TO_RIGHT = 0, -- 从左往右排列
    RIGHT_TO_LEFT = 1  -- 从右往左排列
}

--- @enum LayoutToolResizeMode 缩放模式
LayoutTool.ResizeMode = {
    NONE = 0,      -- 不做任何缩放
    CONTAINER = 1, -- 容器的大小会根据子节点的大小自动缩放
    CHILDREN = 2   -- 子节点的大小会随着容器的大小自动缩放
}

--- @enum LayoutToolAxisDirection 布局轴向，只用于 GRID 布局。
LayoutTool.AxisDirection = {
    HORIZONTAL = 0, -- 进行水平方向布局
    VERTICAL = 1    -- 进行垂直方向布局
}

--- @enum LayoutToolConstraint 布局约束
LayoutTool.Constraint = {
    NONE = 0,      -- 自由排布
    FIXED_ROW = 1, -- 固定行
    FIXED_COL = 2  -- 固定列
}

--- @type UIWidget 容器对象
local _container

--- @type UIWidget[] 可被布局的对象列表。
local _usefulLayoutObj

--- @type LayoutToolLayoutType 布局类型。
local _layoutType

--- @type boolean 方向对齐。在布局类型为 Horizontal 或 Vertical 时按同个方向固定起始位置排列。
local _isAlign

--- @type LayoutToolResizeMode 缩放模式。
local _resizeMode

--- @type LayoutToolVerticalDirection 垂直排列子节点的方向。
local _verticalDirection

--- @type LayoutToolHorizontalDirection 水平排列子节点的方向。
local _horizontalDirection

--- @type LayoutToolAxisDirection 起始轴方向类型。可进行水平和垂直布局排列，只有布局类型为 GRID 的时候才有效。
local _startAxis

--- @type LayoutToolConstraint 容器内布局约束。 只有布局类型为 GRID 的时候才有效。
local _constraint

--- @type number 容器内布局约束使用的限定值。只有布局类型为 GRID 的时候才有效。
local _constraintNum

--- @type boolean 子节点缩放比例是否影响布局。
local _affectedByScale

--- @type number 格子的宽度。只有布局类型为 GRID 的时候才有效。
local _cellWidth

--- @type number 格子的高度。只有布局类型为 GRID 的时候才有效。
local _cellHeight

--- @type number 容器内左边距，只会在一个布局方向上生效。
local _paddingLeft

--- @type number 容器内右边距，只会在一个布局方向上生效。
local _paddingRight

--- @type number 容器内上边距，只会在一个布局方向上生效。
local _paddingTop

--- @type number 容器内下边距，只会在一个布局方向上生效。
local _paddingBottom

--- @type number 子节点之间的水平间距。
local _spacingX

--- @type number 子节点之间的垂直间距。
local _spacingY



--- @interface LayoutToolParam 布局工具参数
--- @field container UIWidget 容器对象
--- @field layoutObjs? UIWidget[] 指定需要布局的对象的列表。默认是找 container 的子节点
--- @field layoutType? LayoutToolLayoutType 布局类型。
--- @field isAlign? boolean 方向对齐。在布局类型为 Horizontal 或 Vertical 时按同个方向固定起始位置排列。
--- @field resizeMode? LayoutToolResizeMode 缩放模式。
--- @field verticalDirection? LayoutToolVerticalDirection 垂直排列子节点的方向。
--- @field horizontalDirection? LayoutToolHorizontalDirection 水平排列子节点的方向。
--- @field startAxis? LayoutToolAxisDirection 起始轴方向类型。可进行水平和垂直布局排列，只有布局类型为 GRID 的时候才有效。
--- @field constraint? LayoutToolConstraint 容器内布局约束。只有布局类型为 GRID 的时候才有效。
--- @field constraintNum? number 容器内布局约束使用的限定值。只有布局类型为 GRID 的时候才有效。
--- @field affectedByScale? boolean 子节点缩放比例是否影响布局。
--- @field cellWidth? number 格子的宽度。只有布局类型为 GRID 的时候才有效。
--- @field cellHeight? number 格子的高度。只有布局类型为 GRID 的时候才有效。
--- @field paddingLeft? number 容器内左边距，只会在一个布局方向上生效。
--- @field paddingRight? number 容器内右边距，只会在一个布局方向上生效。
--- @field paddingTop? number 容器内上边距，只会在一个布局方向上生效。
--- @field paddingBottom? number 容器内下边距，只会在一个布局方向上生效。
--- @field spacingX? number 子节点之间的水平间距。
--- @field spacingY? number 子节点之间的垂直间距。


--- 执行布局
--- @param data LayoutToolParam 布局参数
function LayoutTool.runLayout(data)
    if type(data) ~= "table" then
        logger.error("LayoutTool.runLayout => data 是无效值")
        return
    end
    if not data.container then
        logger.error("LayoutTool.runLayout => data.container 是无效值")
        return
    end

    _container = data.container
    if type(data.layoutObjs) == "table" then
        _usefulLayoutObj = clone(data.layoutObjs)
    else
        _usefulLayoutObj = {}
    end

    _layoutType = type(data.layoutType) == "number" and data.layoutType or LayoutTool.LayoutType.NONE

    if (_layoutType == LayoutTool.LayoutType.HORIZONTAL or _layoutType == LayoutTool.LayoutType.VERTICAL) and type(data.isAlign) == "boolean" then
        _isAlign = data.isAlign
    else
        _isAlign = true
    end

    _resizeMode = (_layoutType ~= LayoutTool.LayoutType.NONE and type(data.resizeMode) == "number")
        and data.resizeMode or LayoutTool.ResizeMode.NONE

    _constraint = (_layoutType ~= LayoutTool.LayoutType.NONE and type(data.constraint) == "number")
        and data.constraint or LayoutTool.Constraint.NONE

    _constraintNum = (_constraint ~= LayoutTool.Constraint.NONE and (type(data.constraintNum) == "number" and data.constraintNum > 0))
        and data.constraintNum or 2

    _verticalDirection = type(data.verticalDirection) == "number"
        and data.verticalDirection or LayoutTool.VerticalDirection.TOP_TO_BOTTOM

    _horizontalDirection = type(data.horizontalDirection) == "number"
        and data.horizontalDirection or LayoutTool.HorizontalDirection.LEFT_TO_RIGHT

    _startAxis = type(data.startAxis) == "number" and data.startAxis or LayoutTool.AxisDirection.HORIZONTAL
    _affectedByScale = type(data.affectedByScale) == "boolean" and data.affectedByScale or false
    _cellWidth = type(data.cellWidth) == "number" and data.cellWidth or 40
    _cellHeight = type(data.cellHeight) == "number" and data.cellHeight or 40
    _paddingLeft = type(data.paddingLeft) == "number" and data.paddingLeft or 0
    _paddingRight = type(data.paddingRight) == "number" and data.paddingRight or 0
    _paddingTop = type(data.paddingTop) == "number" and data.paddingTop or 0
    _paddingBottom = type(data.paddingBottom) == "number" and data.paddingBottom or 0
    _spacingX = type(data.spacingX) == "number" and data.spacingX or 0
    _spacingY = type(data.spacingY) == "number" and data.spacingY or 0

    LayoutTool._doLayout()
end

--- @private
function LayoutTool._doLayout()
    if #_usefulLayoutObj == 0 then
        LayoutTool._checkUsefulObj()
    end

    if _layoutType == LayoutTool.LayoutType.HORIZONTAL then
        local newWidth = LayoutTool._getHorizontalBaseWidth()

        local fnPositionY = function(child)
            local pos --- @type CCPoint
            if _isAlign then
                pos = ccp(0, 0)
            else
                pos = child:getPosition()
            end
            local padding = 0
            if _paddingTop ~= 0 then
                padding = _paddingTop
            elseif _paddingBottom ~= 0 then
                padding = -_paddingBottom
            end
            return pos.y + padding
        end

        LayoutTool._doLayoutHorizontally(newWidth, false, fnPositionY, true)
        _container:setSize(CCSizeMake(newWidth, _container:getSize().height))
    elseif _layoutType == LayoutTool.LayoutType.VERTICAL then
        local newHeight = LayoutTool._getVerticalBaseHeight()

        local fnPositionX = function(child)
            local pos --- @type CCPoint
            if _isAlign then
                pos = ccp(0, 0)
            else
                pos = child:getPosition()
            end
            local padding = 0
            if _paddingLeft ~= 0 then
                padding = _paddingLeft
            elseif _paddingRight ~= 0 then
                padding = -_paddingRight
            end
            return pos.x + padding
        end

        LayoutTool._doLayoutVertically(newHeight, false, fnPositionX, true)
        _container:setSize(CCSizeMake(_container:getSize().width, newHeight))
    elseif _layoutType == LayoutTool.LayoutType.GRID then
        LayoutTool._doLayoutGrid()
    end
end

--- @private
function LayoutTool._checkUsefulObj()
    local children = _container:getChildren()
    local count = children:count()

    for i = 0, count - 1 do
        local child = children:objectAtIndex(i)
        if child:isVisible() then
            table.insert(_usefulLayoutObj, child)
        end
    end
end

--- @private
--- @param baseWidth number
--- @param rowBreak boolean
--- @param fnPositionY fun(child: UIWidget, topOffset: number)
--- @param applyChildren boolean
--- @return number
function LayoutTool._doLayoutHorizontally(baseWidth, rowBreak, fnPositionY, applyChildren)
    local layoutAnchor = _container:getAnchorPoint()
    local limit = LayoutTool._getFixedBreakingNum()

    local sign = 1
    local paddingX = _paddingLeft
    if _horizontalDirection == LayoutTool.HorizontalDirection.RIGHT_TO_LEFT then
        sign = -1
        paddingX = _paddingRight
    end

    local startPos = (_horizontalDirection - layoutAnchor.x) * baseWidth + sign * paddingX
    local nextX = startPos - sign * _spacingX
    local totalHeight = 0
    local rowMaxHeight = 0
    local tempMaxHeight = 0
    local maxHeight = 0
    local isBreak = false
    local activeChildCount = #_usefulLayoutObj
    local newChildWidth = _cellWidth
    local paddingH = LayoutTool._getPaddingH()

    if _layoutType ~= LayoutTool.LayoutType.GRID and _resizeMode == LayoutTool.ResizeMode.CHILDREN then
        newChildWidth = (baseWidth - paddingH - (activeChildCount - 1) * _spacingX) / activeChildCount
    end

    local children = _usefulLayoutObj
    for i = 1, #children do
        local child = children[i]
        local childSize = child:getSize()
        local childAnchor = child:getAnchorPoint()
        local childScaleX = LayoutTool._getUsedScaleValue(child:getScaleX())
        local childScaleY = LayoutTool._getUsedScaleValue(child:getScaleY())

        if _resizeMode == LayoutTool.ResizeMode.CHILDREN then
            local width = newChildWidth / childScaleX
            local height = childSize.height
            if _layoutType == LayoutTool.LayoutType.GRID then
                height = _cellHeight / childScaleY
            end
            child:setSize(CCSizeMake(width, height))
        end

        local anchorX = math.abs(_horizontalDirection - childAnchor.x)
        local childBoundingBoxWidth = childSize.width * childScaleX
        local childBoundingBoxHeight = childSize.height * childScaleY

        if childBoundingBoxHeight > tempMaxHeight then
            maxHeight = math.max(tempMaxHeight, maxHeight)
            rowMaxHeight = tempMaxHeight ~= 0 and tempMaxHeight or childBoundingBoxHeight
            tempMaxHeight = childBoundingBoxHeight
        end

        nextX = nextX + sign * (anchorX * childBoundingBoxWidth + _spacingX)
        local rightBoundaryOfChild = sign * (1 - anchorX) * childBoundingBoxWidth

        if rowBreak then
            if limit > 0 then
                isBreak = ((i - 1) / limit) > 0 and ((i - 1) % limit == 0)
                if isBreak then
                    rowMaxHeight = tempMaxHeight > childBoundingBoxHeight and tempMaxHeight or rowMaxHeight
                end
            elseif childBoundingBoxWidth > baseWidth - paddingH then
                if nextX > startPos + sign * (anchorX * childBoundingBoxWidth) then
                    isBreak = true
                end
            else
                local boundary = (1 - _horizontalDirection - layoutAnchor.x) * baseWidth
                local rowBreakBoundary = nextX + rightBoundaryOfChild
                    + sign * (sign > 0 and _paddingRight or _paddingLeft)
                isBreak = math.abs(rowBreakBoundary) > math.abs(boundary)
            end

            if isBreak then
                nextX = startPos + sign * (anchorX * childBoundingBoxWidth)
                if childBoundingBoxHeight ~= tempMaxHeight then
                    rowMaxHeight = tempMaxHeight
                end
                totalHeight = totalHeight + rowMaxHeight + _spacingY
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
    local containerResizeBoundary = math.max(maxHeight, totalHeight + rowMaxHeight) + LayoutTool._getPaddingV()
    return containerResizeBoundary
end

--- @private
--- @param baseWidth number
--- @param rowBreak boolean
--- @param fnPositionX fun(child: UIWidget, leftOffset: number)
--- @param applyChildren boolean
--- @return number
function LayoutTool._doLayoutVertically(baseHeight, columnBreak, fnPositionX, applyChildren)
    local layoutAnchor = _container:getAnchorPoint()
    local limit = LayoutTool._getFixedBreakingNum()

    local sign = 1
    local paddingY = _paddingBottom
    if _verticalDirection == LayoutTool.VerticalDirection.TOP_TO_BOTTOM then
        sign = -1
        paddingY = _paddingTop
    end

    local startPos = (_verticalDirection - layoutAnchor.y) * baseHeight + sign * paddingY
    local nextY = startPos - sign * _spacingY
    local tempMaxWidth = 0
    local maxWidth = 0
    local colMaxWidth = 0
    local totalWidth = 0
    local isBreak = false
    local activeChildCount = #_usefulLayoutObj
    local newChildHeight = _cellHeight
    local paddingV = LayoutTool._getPaddingV()

    if _layoutType ~= LayoutTool.LayoutType.GRID and _resizeMode == LayoutTool.ResizeMode.CHILDREN then
        newChildHeight = (baseHeight - paddingV - (activeChildCount - 1) * _spacingY) / activeChildCount
    end

    local children = _usefulLayoutObj
    for i = 1, #children do
        local child = children[i]
        local childSize = child:getSize()
        local childAnchor = child:getAnchorPoint()
        local childScaleX = LayoutTool._getUsedScaleValue(child:getScaleX())
        local childScaleY = LayoutTool._getUsedScaleValue(child:getScaleY())

        if _resizeMode == LayoutTool.ResizeMode.CHILDREN then
            local width = childSize.width
            local height = newChildHeight / childScaleY
            if _layoutType == LayoutTool.LayoutType.GRID then
                width = _cellWidth / childScaleX
            end
            child:setSize(CCSizeMake(width, height))
        end

        local anchorY = math.abs(_verticalDirection - childAnchor.y)
        local childBoundingBoxWidth = childSize.width * childScaleX
        local childBoundingBoxHeight = childSize.height * childScaleY

        if childBoundingBoxWidth > tempMaxWidth then
            maxWidth = math.max(tempMaxWidth, maxWidth)
            colMaxWidth = tempMaxWidth ~= 0 and tempMaxWidth or childBoundingBoxWidth
            tempMaxWidth = childBoundingBoxWidth
        end

        nextY = nextY + sign * (anchorY * childBoundingBoxHeight + _spacingY)
        local topBoundaryOfChild = sign * (1 - anchorY) * childBoundingBoxHeight

        if columnBreak then
            if limit > 0 then
                isBreak = ((i - 1) / limit) > 0 and ((i - 1) % limit == 0)
                if isBreak then
                    colMaxWidth = tempMaxWidth > childBoundingBoxHeight and tempMaxWidth or colMaxWidth
                end
            elseif childBoundingBoxHeight > baseHeight - paddingV then
                if nextY > startPos + sign * (anchorY * childBoundingBoxHeight) then
                    isBreak = true
                end
            else
                local boundary = (1 - _verticalDirection - layoutAnchor.y) * baseHeight
                local columnBreakBoundary = nextY + topBoundaryOfChild +
                    sign * (sign > 0 and _paddingTop or _paddingBottom)
                isBreak = math.abs(columnBreakBoundary) > math.abs(boundary)
            end

            if isBreak then
                nextY = startPos + sign * (anchorY * childBoundingBoxHeight)
                if childBoundingBoxWidth ~= tempMaxWidth then
                    colMaxWidth = tempMaxWidth
                end
                totalWidth = totalWidth + colMaxWidth + _spacingX
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
    local containerResizeBoundary = math.max(maxWidth, totalWidth + colMaxWidth) + LayoutTool._getPaddingH()
    return containerResizeBoundary
end

--- @private
--- @param layoutAnchor CCPoint
--- @param layoutSize CCSize
function LayoutTool._doLayoutGridAxisHorizontal(layoutAnchor, layoutSize)
    local baseWidth = layoutSize.width

    local sign = 1
    local bottomBoundaryOfLayout = -layoutAnchor.y * layoutSize.height
    local paddingY = _paddingBottom
    if _verticalDirection == LayoutTool.VerticalDirection.TOP_TO_BOTTOM then
        sign = -1
        bottomBoundaryOfLayout = (1 - layoutAnchor.y) * layoutSize.height
        paddingY = _paddingTop
    end

    local fnPositionY = function(child, topOffset)
        local size = child:getSize()
        local anchor = child:getAnchorPoint()
        local scaleY = child:getScaleY()
        local fixedAnchorY = _verticalDirection == LayoutTool.VerticalDirection.TOP_TO_BOTTOM
            and (1 - anchor.y) or anchor.y

        return bottomBoundaryOfLayout
            + sign * (topOffset + fixedAnchorY * size.height * LayoutTool._getUsedScaleValue(scaleY) + paddingY)
    end

    local newHeight = 0
    if _resizeMode == LayoutTool.ResizeMode.CONTAINER then
        newHeight = LayoutTool._doLayoutHorizontally(baseWidth, true, fnPositionY, false)
        bottomBoundaryOfLayout = -layoutAnchor.y * newHeight

        if _verticalDirection == LayoutTool.VerticalDirection.TOP_TO_BOTTOM then
            sign = -1
            bottomBoundaryOfLayout = (1 - layoutAnchor.y) * newHeight
        end
    end

    LayoutTool._doLayoutHorizontally(baseWidth, true, fnPositionY, true)

    if _resizeMode == LayoutTool.ResizeMode.CONTAINER then
        _container:setSize(CCSizeMake(baseWidth, newHeight))
    end
end

--- @private
--- @param layoutAnchor CCPoint
--- @param layoutSize CCSize
function LayoutTool._doLayoutGridAxisVertical(layoutAnchor, layoutSize)
    local baseHeight = layoutSize.height

    local sign = 1
    local leftBoundaryOfLayout = -layoutAnchor.x * layoutSize.width
    local paddingX = _paddingLeft
    if _horizontalDirection == LayoutTool.HorizontalDirection.RIGHT_TO_LEFT then
        sign = -1
        leftBoundaryOfLayout = (1 - layoutAnchor.x) * layoutSize.width
        paddingX = _paddingRight
    end

    local fnPositionX = function(child, leftOffset)
        local size = child:getSize()
        local anchor = child:getAnchorPoint()
        local scaleX = child:getScaleX()
        local fixedAnchorX = _horizontalDirection == LayoutTool.HorizontalDirection.RIGHT_TO_LEFT
            and (1 - anchor.x) or anchor.x

        return leftBoundaryOfLayout
            + sign * (leftOffset + fixedAnchorX * size.width * LayoutTool._getUsedScaleValue(scaleX) + paddingX)
    end

    local newWidth = 0
    if _resizeMode == LayoutTool.ResizeMode.CONTAINER then
        newWidth = LayoutTool._doLayoutVertically(baseHeight, true, fnPositionX, false)

        leftBoundaryOfLayout = -layoutAnchor.x * newWidth

        if _horizontalDirection == LayoutTool.HorizontalDirection.RIGHT_TO_LEFT then
            sign = -1
            leftBoundaryOfLayout = (1 - layoutAnchor.x) * newWidth
        end
    end

    LayoutTool._doLayoutVertically(baseHeight, true, fnPositionX, true)

    if _resizeMode == LayoutTool.ResizeMode.CONTAINER then
        _container:setSize(CCSizeMake(newWidth, baseHeight))
    end
end

--- @private
function LayoutTool._doLayoutGrid()
    local layoutAnchor = _container:getAnchorPoint()
    local layoutSize = _container:getSize()

    if _startAxis == LayoutTool.AxisDirection.HORIZONTAL then
        LayoutTool._doLayoutGridAxisHorizontal(layoutAnchor, layoutSize)
    elseif _startAxis == LayoutTool.AxisDirection.VERTICAL then
        LayoutTool._doLayoutGridAxisVertical(layoutAnchor, layoutSize)
    end
end

--- @private
--- @param horizontal? boolean
--- @return number
function LayoutTool._getHorizontalBaseWidth(horizontal)
    horizontal = horizontal ~= false
    local children = _usefulLayoutObj
    local baseSize = 0
    local activeChildCount = #children

    if _resizeMode == LayoutTool.ResizeMode.CONTAINER then
        for i = 1, #children do
            local child = children[i]
            local scaleX = child:getScaleX()
            baseSize = baseSize + child:getSize().width * LayoutTool._getUsedScaleValue(scaleX)
        end

        baseSize = baseSize + (activeChildCount - 1) * _spacingX + LayoutTool._getPaddingH()
    else
        baseSize = _container:getSize().width
    end

    return baseSize
end

--- @private
--- @return number
function LayoutTool._getVerticalBaseHeight()
    local children = _usefulLayoutObj
    local baseSize = 0
    local activeChildCount = #children

    if _resizeMode == LayoutTool.ResizeMode.CONTAINER then
        for i = 1, #children do
            local child = children[i]
            local scaleY = child:getScaleY()
            baseSize = baseSize + child:getSize().height * LayoutTool._getUsedScaleValue(scaleY)
        end

        baseSize = baseSize + (activeChildCount - 1) * _spacingY + LayoutTool._getPaddingV()
    else
        baseSize = _container:getSize().height
    end

    return baseSize
end

--- @private
--- @return number
function LayoutTool._getUsedScaleValue(value)
    return _affectedByScale and math.abs(value) or 1
end

--- @private
--- @return number
function LayoutTool._getPaddingH()
    return _paddingLeft + _paddingRight
end

--- @private
--- @return number
function LayoutTool._getPaddingV()
    return _paddingTop + _paddingBottom
end

--- @private
--- @return number
function LayoutTool._getFixedBreakingNum()
    if _layoutType ~= LayoutTool.LayoutType.GRID or _constraint == LayoutTool.Constraint.NONE or _constraintNum <= 0 then
        return 0
    end

    local num = 0
    if _constraint == LayoutTool.Constraint.FIXED_ROW then
        num = math.ceil(#_usefulLayoutObj / _constraintNum)
    else
        num = _constraintNum
    end

    if _startAxis == LayoutTool.AxisDirection.VERTICAL then
        if _constraint == LayoutTool.Constraint.FIXED_COL then
            num = math.ceil(#_usefulLayoutObj / _constraintNum)
        else
            num = _constraintNum
        end
    end

    return num
end

return LayoutTool
