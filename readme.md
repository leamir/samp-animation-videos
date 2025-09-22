# Open.MP Animation recorder
This gamemode records every single samp/open.mp animation - without intervention, using OBS WebSocket API.

# How to use:
1. Enable WebSockets on OBS:
    Go to "Tools" > "WebSocket Server Settings" > Make sure it is enabled and with **no authentication**
2. Edit the output folder on the gamemode (line 12) and re-compile.
3. Run omp-server.exe on the same computer where you have OBS open.
    If you changed settings like IP or port on the OBS WebSocket server, you may need to edit the gamemode (line 10) and re-compile
4. Join local server
5. Run '/recordanims'
6. Wait... It took over 1 hour for it to record everything for me.