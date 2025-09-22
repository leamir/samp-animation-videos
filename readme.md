# open.mp Animation recorder
This gamemode records every single samp/open.mp animation - without intervention, using OBS WebSocket API.

# See recorded videos:
I've already recorded the default animations, see them in the [final-videos branch](https://github.com/leamir/samp-animation-videos/tree/final-videos)

# How to use to record your own animations:
1. Enable WebSockets on OBS:
    Go to "Tools" > "WebSocket Server Settings" > Make sure it is enabled and with **no authentication**
2. Get OBS scene ready
   - Center your character on the output, edit output size, disable audio recording.
   - You may need to make GTA Windowed (ALT+Enter).
   - **After configuring, leave OBS on the gta scene, it will auto start/stop recording as needed** 
3. Edit the output folder on the gamemode (line 12) and re-compile.
4. Run omp-server.exe on the same computer where you have OBS open.
    If you changed settings like IP or port on the OBS WebSocket server, you may need to edit the gamemode (line 10) and re-compile
5. Join local server
6. Run '/recordanims'
   - Use left/right arrow to go back/skip ahead on the animations.
   - Press space(sprint key) to stop recording immediately, this will discard video currently being recorded.
8. Wait... It took over 1 hour for it to record everything for me.
9. If you need to re-record anything, you can use '/recordanims [library] (anim name)', where anim name is optional to start from that animation.
   - Re-recordings overwrite on the output folder.
