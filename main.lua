push = require 'push'



--Dimensión de Pantalla
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720
--Dimensiones Virtuales
VIRTUAL_WIDTH = 1024
VIRTUAL_HEIGHT = 576

-- main.lua

-- Variables para el escenario
local obstacles = {}  -- Almacena los obstáculos generados
local specialObstacles = {}

local shots = {}      -- Almacena los disparos
local shotSpeed = 300 -- Velocidad de desplazamiento de los disparos
local shotWidth = 10
local shotHeight = 20
local obstacleSpeed = 100 -- Velocidad de desplazamiento de los obstáculos
local obstacleWidth = 30
local obstacleHeight = 100

local obstacleSpawnTimer = 0
local obstacleSpawnInterval = 2 -- Intervalo en segundos entre generación de obstáculos

local shotSound = love.audio.newSource("assets/sounds/shot.mp3", "static")
local deathSound = love.audio.newSource("assets/sounds/death.mp3", "static")
local crashSound = love.audio.newSource("assets/sounds/crash.mp3", "static")
local hitSound = love.audio.newSource("assets/sounds/crash.mp3", "static")
local soundTrack = love.audio.newSource("assets/sounds/main.mp3", "static")
local obstacleImages = { "assets/enemies/helicopter.png", "assets/enemies/ship.png", "assets/enemies/ship1.png" }


local gamePaused = false
local gameState = "playing"
local playerLives = 3
local playerScore = 0
local playerMaxScore = 0
local maxShots = 10
local activeShots = 0

local fuelBarWidth = 200
local fuelBarHeight = 20
local fuelBarMax = 100
local fuelBar = fuelBarMax
local fuelBarDecreaseRate = 5  -- Puedes ajustar la velocidad de disminución
local fuelRefillAmount = 20     -- Puedes ajustar la cantidad de recarga
local fuelSpawnTimer = 0
local fuelSpawnInterval = 10   -- Intervalo en segundos entre generación de botes de combustible




local background = {
    image = love.graphics.newImage("assets/images/background.png"),  -- Reemplaza con la ruta correcta a tu imagen de fondo
    y = 0,
    
}

function love.conf(t)
    t.window.width = 1280  -- Ancho deseado
    t.window.height = 720  -- Alto deseado
    t.window.title = "Alien Wars"
end


function love.load()
    -- Configuración inicial
    player = { x = 600, y = 600, speed = 300, image = love.graphics.newImage("assets/player/ship.png"), scale = 0.1 }
    shotImage = love.graphics.newImage("assets/player/bullet.png")
    shotSound = love.audio.newSource("assets/sounds/shot.mp3", "static")
    deathSound = love.audio.newSource("assets/sounds/death.mp3", "static")
    crashSound = love.audio.newSource("assets/sounds/crash.mp3", "static")
    hitSound = love.audio.newSource("assets/sounds/crash.mp3", "static")
    soundTrack = love.audio.newSource("assets/sounds/main.mp3", "static")

    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })
end

function love.update(dt)
    if not gamePaused then
        -- Actualizar jugador
        soundTrack:setLooping(true)
        soundTrack:play()
        movePlayer(dt)

        -- Generar obstáculos
        generateObstacles(dt)
        generateFuel(dt)

        -- Mover y verificar colisiones con obstáculos
        moveObstacles(dt)
        checkCollisions()

        -- Mover y verificar colisiones con disparos
        moveShots(dt)
        checkShotCollisions()
        fuelBar = fuelBar - fuelBarDecreaseRate * dt

        if fuelBar <= 0 then
            fuelBar = 0
            -- Aquí puedes agregar el código para manejar el agotamiento del combustible
            -- Por ejemplo, detener el juego, reiniciar la posición del jugador, etc.
        end

    end
end

function love.draw()
    -- Dibujar el fondo
    love.graphics.draw(background.image, 0, -background.y, 0, background.scale, background.scale)
    -- Dibujar jugador
    love.graphics.draw(player.image, player.x, player.y, 0, player.scale, player.scale)

    -- Dibujar obstáculos
    for _, obstacle in ipairs(obstacles) do
        love.graphics.draw(obstacle.image, obstacle.x, obstacle.y, 0, obstacle.scale, obstacle.scale)
    end

    -- Dibujar disparos
    for _, shot in ipairs(shots) do
        love.graphics.draw(shot.image, shot.x, shot.y, 0, shot.scale, shot.scale)
    end

    

    if gameState == "playing" then
        -- Dibujar el número de vidas
        local font = love.graphics.newFont("fonts/Kanit/Kanit.ttf", 24) 
        love.graphics.setFont(font)
        love.graphics.print("Vidas: " .. playerLives, 10, 90)
        love.graphics.print("Puntuación: " .. playerScore, 10, 10)
        love.graphics.print("Puntuación máxima: " .. playerMaxScore, 10, 50)
    end
    

    -- Dibujar el mensaje de Game Over
    if gameState == "gameover" then
        local font = love.graphics.newFont("fonts/Kanit/Kanit.ttf", 36) 
        love.graphics.setFont(font)
        love.graphics.printf("Game Over", 0, WINDOW_HEIGHT / 2 - 30, WINDOW_WIDTH - 30, "center")
        love.graphics.printf("Presiona Enter para reiniciar", 0, WINDOW_HEIGHT / 2, WINDOW_WIDTH, "center")
    end
end

function movePlayer(dt)
    if gameState == "gameover" then
        return  -- No actualizar la posición de la nave en el estado "gameover"
    end
    if love.keyboard.isDown("up") and player.y > 0 then
        player.y = player.y - player.speed * dt
    elseif love.keyboard.isDown("down") and player.y < love.graphics.getHeight() - player.image:getHeight() * player.scale then
        player.y = player.y + player.speed * dt
    end

    if love.keyboard.isDown("left") and player.x > 0 then
        player.x = player.x - player.speed * dt
    elseif love.keyboard.isDown("right") and player.x < love.graphics.getWidth() - player.image:getWidth() * player.scale then
        player.x = player.x + player.speed * dt
    end
end

-- Define el límite de obstáculos en pantalla
local maxObstacles = 8  

function generateObstacles(dt)
    if gameState == "gameover" then
        return
    end

    obstacleSpawnTimer = obstacleSpawnTimer + dt

    if obstacleSpawnTimer > obstacleSpawnInterval and #obstacles < maxObstacles then
        -- Genera obstáculos normales
        local obstacleImageIndex = math.random(1, #obstacleImages)
        local obstacle = {
            x = math.random(0, 500),
            y = -obstacleHeight,
            image = love.graphics.newImage(obstacleImages[obstacleImageIndex]),
            scale = 0.1,
            alive = true
        }
        table.insert(obstacles, obstacle)
        obstacleSpawnTimer = 0
    end

end

function generateFuel(dt)
    -- Generar botes de combustible
    fuelSpawnTimer = fuelSpawnTimer + dt

    if fuelSpawnTimer > fuelSpawnInterval then
        local fuel = {
            x = math.random(0, VIRTUAL_WIDTH),
            y = -fuelBarHeight,  -- Para que aparezca justo arriba de la pantalla
            width = fuelBarWidth,
            height = fuelBarHeight,
            image = love.graphics.newImage("assets/fuel.png"),  -- Reemplaza con la ruta correcta
            scale = 0.1,
        }
        table.insert(specialObstacles, fuel)
        fuelSpawnTimer = 0
    end

    -- Mover y verificar colisiones con botes de combustible
    for i, fuel in ipairs(specialObstacles) do
        fuel.y = fuel.y + obstacleSpeed * dt

        -- Verificar colisiones con el jugador
        if checkCollision(player, fuel) then
            -- Recargar la barra de combustible y eliminar el bote de combustible
            fuelBar = math.min(fuelBar + fuelRefillAmount, fuelBarMax)
            table.remove(specialObstacles, i)
        end

        -- Eliminar botes de combustible que salen de la pantalla
        if fuel.y > VIRTUAL_HEIGHT then
            table.remove(specialObstacles, i)
        end
    end
end

function moveObstacles(dt)
    -- Mover obstáculos y reiniciar aquellos que salen de la pantalla o están marcados como no vivos
    if gameState == "gameover" then
        -- Eliminar todos los obstáculos
        obstacles = {}
        return
    end
    for i = #obstacles, 1, -1 do
        local obstacle = obstacles[i]
        if obstacle.alive then
            obstacle.y = obstacle.y + obstacleSpeed * dt
            if obstacle.y > love.graphics.getHeight() then
                obstacle.alive = false
            end
        else
            -- Reiniciar la posición del obstáculo cuando está marcado como no vivo
            obstacle.y = -obstacleHeight
            obstacle.x = math.random(0, love.graphics.getWidth() - obstacleWidth)
            obstacle.alive = true
        end
    end

    
end

function checkCollisions()
    -- Verificar colisiones entre la nave y los obstáculos
    for _, obstacle in ipairs(obstacles) do
        if obstacle.alive and checkCollision(player, obstacle) then
            -- Reducir vidas y reiniciar la posición del jugador
            crashSound:stop()
            crashSound:play()

            playerLives = playerLives - 1
            print("¡Colisión con nave enemiga! Vidas restantes: " .. playerLives)

            -- Verificar si el jugador se quedó sin vidas
            if playerLives <= 0 then
                crashSound:stop()
                deathSound:play()
                gameState = "gameover"
            else
                -- Reiniciar la posición del jugador
                player.x = 600
                player.y = 600
            end
        end
    end
end

function moveShots(dt)
    -- Mover disparos y eliminar aquellos que salen de la pantalla
    for i, shot in ipairs(shots) do
        shot.y = shot.y - shotSpeed * dt
        if shot.y < 0 then
            table.remove(shots, i)
            activeShots = activeShots - 1  -- Disminuir el contador de disparos activos
        end
    end
end

function checkShotCollisions()
    -- Verificar colisiones entre disparos y obstáculos
    for i, shot in ipairs(shots) do
        for j, obstacle in ipairs(obstacles) do
            if obstacle.alive and checkCollision(shot, obstacle) then
                -- Eliminar el disparo y marcar la nave como no viva
                table.remove(shots, i)
                obstacle.alive = false
                hitSound:stop()
                hitSound:play()
                -- Sumar puntos basados en el tipo de obstáculo
                local obstacleValue = 10  -- Valor predeterminado
                
                playerScore = playerScore + obstacleValue
                activeShots = activeShots - 1  -- Disminuir el contador de disparos activos
            end
        end
    end
end

function love.keypressed(key)
    if key == "return" and gameState == "gameover" then
        if playerScore > playerMaxScore then
            playerMaxScore = playerScore  -- Actualizar la puntuación máxima si es necesario
        end
        -- Reiniciar el juego
        playerLives = 3
        playerScore = 0
        gameState = "playing"

        -- Reiniciar la posición del jugador
        player.x = 600
        player.y = 600

        -- Limpiar las listas de obstáculos y disparos
        obstacles = {}
        shots = {}
        
        -- Reiniciar el contador de disparos activos
        activeShots = 0
    elseif key == "space" and gameState == "playing" then
        -- Disparar solo si no hemos alcanzado el límite de disparos
        if activeShots < maxShots then
            shotSound:stop()
            local shot = {
                x = player.x + player.image:getWidth() * player.scale / 4 - shotWidth / 2,
                y = player.y,
                image = shotImage,
                scale = 0.06
            }
            table.insert(shots, shot)
            shotSound:play()
            
            activeShots = activeShots + 1  -- Aumentar el contador de disparos activos
        end
    end
end



function checkCollision(a, b)
    -- Verificar si dos rectángulos (a y b) se superponen
    return a.x < b.x + b.image:getWidth() * b.scale and
        a.x + a.image:getWidth() * a.scale > b.x and
        a.y < b.y + b.image:getHeight() * b.scale and
        a.y + a.image:getHeight() * a.scale > b.y
end
