import gym

env = gym.make('BreakoutDeterministic-v4') #BreakoutDeterministic-v4, BreakoutNoFrameskip-v4, PongNoFrameskip-v4
obs = env.reset()
 
import time
st = time.time()

reward, env_done, i, total_r = 0.0, False, 0, 0.0
for _ in range(1000):
    #env.render()
    obs, reward, env_done, info = env.step(env.action_space.sample())
    total_r += reward
    if env_done:
        obs = env.reset()

print('headless fps, total_r', 1000.0/(time.time()-st), total_r)

env.close()