-- main.lua: Interactive Menger Sponge Renderer with Mode Toggle

-- Quaternion helper functions
local function quat_multiply(q1, q2)
    local res = {}
    res.w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
    res.x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y
    res.y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x
    res.z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
    return res
end

local function quat_normalize(q)
    local len = math.sqrt(q.x^2 + q.y^2 + q.z^2 + q.w^2)
    if len > 0 then
        q.x = q.x / len
        q.y = q.y / len
        q.z = q.z / len
        q.w = q.w / len
    end
    return q
end

local function quat_from_axis_angle(axis, angle)
    local half_angle = angle * 0.5
    local s = math.sin(half_angle)
    return {
        x = axis.x * s,
        y = axis.y * s,
        z = axis.z * s,
        w = math.cos(half_angle)
    }
end

function love.load()
    mengerShader = love.graphics.newShader("shader.glsl")
    
    time = 0
    
    -- Mode state
    autoRotate = true -- Default: start in auto-rotate mode

    -- Interaction state
    isDragging = false
    lastMouse = {x = 0, y = 0}
    
    -- Physics simulation
    -- Quaternion rotation, initialized to identity
    rotation = {x = 0, y = 0, z = 0, w = 1}
    -- Inertial rotation, also a quaternion
    velocity = {x = 0, y = 0, z = 0, w = 1}

    -- Parameters
    sensitivity = 0.005
    damping = 0.97
    cameraDistance = 4.0
end

function love.wheelmoved(x, y)
    -- y > 0 scroll up (zoom in), y < 0 scroll down (zoom out)
    cameraDistance = cameraDistance - y * 0.2
    -- Clamp zoom range
    cameraDistance = math.max(1.5, math.min(cameraDistance, 20.0))
end

function love.keypressed(key)
    if key == "m" then
        autoRotate = not autoRotate
        -- Reset inertia when switching mode
        velocity = {x = 0, y = 0, z = 0, w = 1}
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Grabbing always switches to manual mode
        if autoRotate then
            autoRotate = false
        end

        isDragging = true
        lastMouse = {x = x, y = y}
        velocity = {x = 0, y = 0, z = 0, w = 1}
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        isDragging = false
    end
end

function love.update(dt)
    time = time + dt

    if autoRotate then
        -- --- Auto-rotate logic ---
        local rotY = quat_from_axis_angle({x = 0, y = 1, z = 0}, dt * 0.3)
        local rotX = quat_from_axis_angle({x = 1, y = 0, z = 0}, dt * 0.2)
        rotation = quat_multiply(rotY, rotation)
        rotation = quat_multiply(rotX, rotation)
        rotation = quat_normalize(rotation)
    else
        -- --- Manual mode logic (drag + inertia) ---
        if isDragging then
            -- Dragging
            local mx, my = love.mouse.getPosition()
            local dx = mx - lastMouse.x
            local dy = my - lastMouse.y
            
            if dx ~= 0 or dy ~= 0 then
                local rotY = quat_from_axis_angle({x = 0, y = 1, z = 0}, dx * sensitivity)
                local rotX = quat_from_axis_angle({x = 1, y = 0, z = 0}, dy * sensitivity)
                
                local deltaRotation = quat_multiply(rotY, rotX)
                
                rotation = quat_multiply(deltaRotation, rotation)
                rotation = quat_normalize(rotation)
                
                -- Update velocity for inertia
                velocity = deltaRotation
            end
            
            lastMouse = {x = mx, y = my}
        else
            -- Inertia
            rotation = quat_multiply(velocity, rotation)
            rotation = quat_normalize(rotation)

            -- Damping
            velocity = quat_normalize({
                x = velocity.x * damping,
                y = velocity.y * damping,
                z = velocity.z * damping,
                w = 1.0 -- Slowly interpolate toward identity quaternion
            })

            -- Stop if rotation is very small
            if velocity.w > 0.9999 then
                velocity = {x = 0, y = 0, z = 0, w = 1}
            end
        end
    end
end

function love.draw()
    love.graphics.setShader(mengerShader)
    
    mengerShader:send("rotationQuat", {rotation.x, rotation.y, rotation.z, rotation.w})
    mengerShader:send("time", time)
    mengerShader:send("cameraDistance", cameraDistance)
    
    local width, height = love.graphics.getDimensions()
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    love.graphics.setShader()

    -- Display current mode hint on screen
    love.graphics.setColor(1, 1, 1, 0.8)
    local modeText = "Mode: " .. (autoRotate and "Automatic" or "Manual") .. " (Press 'M' to switch)"
    love.graphics.print(modeText, 10, 10)
end
