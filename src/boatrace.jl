#= monte carlo simulation of boats ⛵ =#

using Random
using Plots
using Statistics

testfig = plot(rand(5)) # inital plot to speedup next function call

#= randomness seeding =#
seedling = 1234
if seedling > 0
    Random.seed!(seedling)
end

#= constants =#
const windDistMagellan = 192
const windDistWrangler = 144
const solarDistWrangler = 120
const finishLine = 10000
const windyProb = [true, true, false, true] # 75% days windy
const sunnyProb = [true, false, true, true, true, true, false, false, true, true] # 70% sunny

#= data types =#
struct Weather
    windy::Bool
    sunny::Bool
end

abstract type Boat end

mutable struct Magellan <: Boat
    distance::Vector{Int16}
    arrived::Bool
end

mutable struct Wrangler <: Boat
    distance::Vector{Int16}
    arrived::Bool
end

#= time step simulation update functions (multiple dispatch) =#
function updateBoat(boat::Magellan)
    weather = generateWeather() # defined below; rng single boat weather generation
    if boat.arrived; return 0 end
    if weather.windy
        newDist = boat.distance[end] + windDistMagellan
        if newDist >= finishLine
            boat.arrived = true
        end
        push!(boat.distance, newDist)
    else
        push!(boat.distance, boat.distance[end])
    end
    return 1
end

function updateBoat(boat::Magellan, weather::Weather)
    if boat.arrived; return 0 end
    if weather.windy
        newDist = boat.distance[end] + windDistMagellan
        if newDist >= finishLine
            boat.arrived = true
        end
        push!(boat.distance, newDist)
    else
        push!(boat.distance, boat.distance[end])
    end
    return 1
end

function updateBoat(boat::Wrangler)
    if boat.arrived; return 0 end
    if weather.windy
        newDist = boat.distance[end] + windDistWrangler
        if newDist >= finishLine
            boat.arrived = true
        end
        push!(boat.distance, newDist)
    elseif weather.sunny && !weather.windy
        newDist = boat.distance[end] + solarDistWrangler
        if newDist >= finishLine
            boat.arrived = true
        end
        push!(boat.distance, newDist)
    else
        push!(boat.distance, boat.distance[end])
    end
    return 1
end

function updateBoat(boat::Wrangler, weather::Weather)
    weather = generateWeather() # local boat-specfic weather generation
    if boat.arrived; return 0 end
    if weather.windy
        newDist = boat.distance[end] + windDistWrangler
        if newDist >= finishLine
            boat.arrived = true
        end
        push!(boat.distance, newDist)
    elseif weather.sunny && !weather.windy
        newDist = boat.distance[end] + solarDistWrangler
        if newDist >= finishLine
            boat.arrived = true
        end
        push!(boat.distance, newDist)
    else
        push!(boat.distance, boat.distance[end])
    end
    return 1
end

#= weather rng generator =#
function generateWeather()
    return Weather(
        rand(windyProb),
        rand(sunnyProb)
    )
end

#= end condition checker =#
function allArrived(boats::Vector{<:Boat})
    isAllArrived = true
    for boat in boats
        if !boat.arrived
            isAllArrived = false
        end
    end
    return isAllArrived
end

function isAllArrived(groupOne::Vector{<:Boat}, groupTwo::Vector{<:Boat})
    if allArrived(groupOne) && allArrived(groupTwo)
        return true
    else
        return false
    end
end

#= n boat generator =#
function generateBoats(n::Int, type)
    boats = type[]
    for i in 1:n
        push!(boats, type(Int16[0,], false))
    end
    return boats
end

#= simulation running utils =#
function updateAllBoats!(boats::Vector{<:Boat})
    for boat in boats
        updateBoat(boat)
    end
    return boats
end

function updateAllBoats!(boats::Vector{<:Boat}, weathers::Vector{Weather})
    @assert length(boats) == length(weathers)
    for i in 1:length(boats)
        updateBoat(boats[i], weathers[i])
    end
    return boats
end

function simulate(n::Int)
    magellanBoats = generateBoats(n, Magellan)
    wranglerBoats = generateBoats(n, Wrangler)
    while !isAllArrived(magellanBoats, wranglerBoats)
        updateAllBoats!(magellanBoats)
        updateAllBoats!(wranglerBoats)
    end
    return (magellanBoats, wranglerBoats)
end

function parallelSimulate(n::Int)
    magBoats = generateBoats(n, Magellan)
    wrgBoats = generateBoats(n, Wrangler)
    while !isAllArrived(magBoats, wrgBoats)
        weatherPattern = [generateWeather() for i in 1:n]
        updateAllBoats!(magBoats, weatherPattern)
        updateAllBoats!(wrgBoats, weatherPattern)
    end
    return (magBoats, wrgBoats)
end

# N = 1000000
# (magellanSim, wranglerSim) = simulate(N) # simulation seems to work!
# now all that remains is to extract the number of iterations needed to achieve the
# boat.arrived = true, state.

# magellanDaysTaken = [length(magellanSim[i].distance) for i in 1:N]
# wranglerDaysTaken = [length(wranglerSim[i].distance) for i in 1:N]
# (mean(magellanDaysTaken), mean(wranglerDaysTaken))

function collectSample(groupOne, groupTwo, n)
    return (
        Random.rand(groupOne, n),
        Random.rand(groupOne, n)
    )
end

function getDist(boat, index)
    if index > length(boat.distance)
        return boat.distance[end]
    else
        return boat.distance[index]
    end
end

#= ploting and visualization =#
function plotSim(N, scaleSample)
    # not realistic to plot all N, random sample N/10 examples from each pop.
    (magellanSim, wranglerSim) = simulate(N)
    numSample = div(N, scaleSample)
    (magSamples, wrgSamples) = collectSample(magellanSim, wranglerSim, numSample)
    # i know most timesteps to complete ~100
    magMeanDists = [mean([getDist(boat, i) for boat in magSamples]) for i in 1:100]
    wrgMeanDists = [mean([getDist(boat, i) for boat in wrgSamples]) for i in 1:100]
    fig = plot(1:100, magMeanDists;
               lw=3,linecolor=:red,leg=true,label="Magellan avg.",
               title="Distance covered for Magellan and Wrangler propulsion systems,"
               ,ylabel="Distance travelled (km)", xlabel="Days")
    plot!(fig, 1:100, wrgMeanDists; lw=3, linecolor=:blue, leg=true, lebel="Wrangler avg.")
    for trace in magSamples
        plot!(fig, trace.distance; lw=0.1, linecolor=:pink, leg=false)
    end
    for trace in wrgSamples
        plot!(fig, trace.distance; lw=0.1, linecolor=:green, leg=false)
    end
    savefig(fig, "test.png")
end
