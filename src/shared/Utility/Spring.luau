-- Module: spring
-- Description: A simple spring physics simulation for smooth motion

local Spring = {}
Spring.__index = Spring

-- Constructor
function Spring.new(target, position, velocity, dampingRatio, angularFrequency)
    local self = setmetatable({}, Spring)
    
    self.target = target 
    self.position = position 
    self.velocity = velocity 
    self.dampingRatio = dampingRatio -- Damping
    self.angularFrequency = angularFrequency -- Stiffness
    
    return self
end

-- Update the spring simulation
function Spring:step(dt)
    if not dt or dt <= 0 then return end
    
    -- Calculate spring force
    local displacement = self.position - self.target
    local springForce = -displacement * (self.angularFrequency^2)
    
    -- Calculate damping force
    local dampingForce = -self.velocity * (2 * self.dampingRatio * self.angularFrequency)
    
    -- Calculate acceleration
    local acceleration = springForce + dampingForce
    
    -- Update velocity and position
    self.velocity = self.velocity + acceleration * dt
    self.position = self.position + self.velocity * dt
    
    return self.position
end

-- Shorthand for creating and updating a spring in one call
function Spring.oneShot(position, target, dampingRatio, angularFrequency, dt)
    local spring = Spring.new(target, position, nil, dampingRatio, angularFrequency)
    return spring:step(dt)
end

-- Reset the spring to specific values
function Spring:reset(position, velocity)
    self.position = position or self.target
    self.velocity = velocity or 0
end

-- Set the target position
function Spring:setTarget(target)
    self.target = target
end

return Spring