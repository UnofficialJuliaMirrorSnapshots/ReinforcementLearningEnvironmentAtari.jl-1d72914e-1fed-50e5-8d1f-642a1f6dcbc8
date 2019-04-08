module ReinforcementLearningEnvironmentAtari

using ArcadeLearningEnvironment, GR
import ArcadeLearningEnvironment: getScreen
import ReinforcementLearningBase: AbstractEnv, DiscreteSpace,
       interact!, getstate, reset!, plotenv, actionspace, sample

struct AtariEnv <: AbstractEnv
    ale::Ptr{Nothing}
    screen::Array{UInt8, 1}
    getscreen::Function
    actions::Array{Int32, 1}
    actionspace::DiscreteSpace
    noopmax::Int64
end

actionspace(env::AtariEnv) = env.actionspace

"""
    AtariEnv(name; colorspace = "Grayscale", frame_skip = 4, noopmax = 20,
                   color_averaging = true, repeat_action_probability = 0.)

Returns an AtariEnv that can be used in an RLSetup of the
[ReinforcementLearning](https://github.com/jbrea/ReinforcementLearning.jl)
package. Check the deps/roms folder of the ArcadeLearningEnvironment package to
see all available `name`s.
"""
function AtariEnv(name;
                  colorspace = "Grayscale",
                  frame_skip = 4, noopmax = 20,
                  color_averaging = true,
                  actionset = :minimal,
                  repeat_action_probability = 0.)
    ale = ALE_new()
    setBool(ale, "color_averaging", color_averaging)
    setInt(ale, "frame_skip", Int32(frame_skip))
    setFloat(ale, "repeat_action_probability",
             Float32(repeat_action_probability))
    loadROM(ale, name)
    if colorspace == "Grayscale"
        screen = Array{Cuchar}(undef, 210*160)
        getscreen = getScreenGrayscale
    elseif colorspace == "RGB"
        screen = Array{Cuchar}(undef, 3*210*160)
        getscreen = getScreenRGB
    elseif colorspace == "Raw"
        screen = Array{Cuchar}(undef, 210*160)
        getscreen = getScreen
    end
    actions = actionset == :minimal ? getMinimalActionSet(ale) : getLegalActionSet(ale)
    actionspace = DiscreteSpace(length(actions), 1)
    AtariEnv(ale, screen, getscreen, actions, actionspace, noopmax)
end

function getScreen(p::Ptr, s::Array{Cuchar, 1})
    sraw = getScreen(p)
    for i in 1:length(s)
        s[i] =  sraw[i] .>> 1
    end
end

function interact!(env::AtariEnv, a)
    r = act(env.ale, env.actions[a])
    env.getscreen(env.ale, env.screen)
    (observation=env.screen, reward=r, isdone=game_over(env.ale))
end

function getstate(env::AtariEnv)
    env.getscreen(env.ale, env.screen)
    (observation=env.screen, isdone=game_over(env.ale))
end

function reset!(env::AtariEnv)
    reset_game(env.ale)
    for _ in 1:rand(0:env.noopmax) act(env.ale, Int32(0)) end
    env.getscreen(env.ale, env.screen)
    (observation=env.screen,)
end


imshowgrey(x::Array{UInt8, 2}) = imshowgrey(x[:], size(x))
imshowgrey(x::Array{UInt8, 1}, dims) = imshow(reshape(x, dims), colormap = 2)
imshowcolor(x::Array{UInt8, 3}) = imshowcolor(x[:], size(x))

function imshowcolor(x::Array{UInt8, 1}, dims)
    clearws()
    setviewport(0, dims[1]/dims[2], 0, 1)
    setwindow(0, 1, 0, 1)
    y = (zeros(UInt32, dims...) .+ 0xff) .<< 24
    img = UInt32.(x)
    @simd for i in 1:length(y)
        @inbounds y[i] += img[3*(i-1) + 1] + img[3*(i-1) + 2] << 8 + img[3*i] << 16
    end
    drawimage(0, 1, 0, 1, dims..., y)
    updatews()
end

function plotenv(env::AtariEnv)
    x = zeros(UInt8, 3 * 160 * 210)
    getScreenRGB(env.ale, x)
    imshowcolor(x, (160, 210))
end

export AtariEnv
end # module
